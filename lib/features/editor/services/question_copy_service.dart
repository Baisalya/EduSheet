import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_label.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:uuid/uuid.dart';

/// Creates an independent reusable copy of an EduSheet question.
///
/// A question is more than its visible text: option IDs, inline math IDs,
/// geometry diagram/object IDs, attachments and nested questions are all
/// persistent identities. Reusing only [Question.copyWith] would make two
/// papers share those identities. This service is the one canonical copy
/// boundary used by duplication and Question Bank import/export workflows.
class QuestionCopyService {
  final String Function() _nextId;
  final GeometryDiagram? Function(String id)? _geometryResolver;

  QuestionCopyService({
    String Function()? idFactory,
    GeometryDiagram? Function(String id)? geometryResolver,
  }) : _nextId = idFactory ?? (() => const Uuid().v4()),
       _geometryResolver = geometryResolver;

  Question copyQuestion(Question source, {DateTime? copiedAt}) {
    final now = copiedAt ?? DateTime.now();
    final mathBySourceKey = <String, MathExpression>{};
    final clonedMath = <MathExpression>[];

    for (final expression in source.mathExpressions) {
      final cloned = _copyMathExpression(expression);
      mathBySourceKey[_mathSourceKey(expression)] = cloned;
      clonedMath.add(cloned);
    }

    final clonedText = _copyRichText(
      source.text,
      mathBySourceKey: mathBySourceKey,
      clonedMath: clonedMath,
    );

    final optionIds = <String, String>{};
    final clonedOptions = source.options.map((option) {
      final newId = _nextId();
      optionIds[option.id] = newId;
      return QuestionOption(
        id: newId,
        text: option.text,
        isCorrect: option.isCorrect,
      );
    }).toList();

    final attachmentIds = <String, String>{};
    final clonedAttachments = source.attachments.map((attachment) {
      final newId = _nextId();
      attachmentIds[attachment.id] = newId;
      return QuestionAttachment(
        id: newId,
        kind: attachment.kind,
        path: attachment.path,
        alternativeText: attachment.alternativeText,
        caption: attachment.caption,
        mimeType: attachment.mimeType,
        width: attachment.width,
        height: attachment.height,
      );
    }).toList();

    final copiedMetadata = _copyDynamicMap(source.metadata);
    final sourceMathContent = QuestionMathContent.fromMetadata(source.metadata);
    final copiedMathContent = sourceMathContent.remapForCopy(
      optionIds: optionIds,
      attachmentIds: attachmentIds,
      mapExpression: (expression) {
        final key = _mathSourceKey(expression);
        final existing = mathBySourceKey[key];
        if (existing != null) return existing;
        final cloned = _copyMathExpression(expression);
        mathBySourceKey[key] = cloned;
        clonedMath.add(cloned);
        return cloned;
      },
    );
    final normalizedMetadata = copiedMathContent.writeToMetadata(
      copiedMetadata,
    );

    return Question(
      id: _nextId(),
      text: clonedText,
      richTextFormat: source.richTextFormat,
      plainTextAccessibility: source.plainTextAccessibility,
      imageUrl: source.imageUrl,
      options: clonedOptions,
      type: source.type,
      marks: source.marks,
      negativeMarks: source.negativeMarks,
      alignment: source.alignment,
      isOptional: source.isOptional,
      correctAnswer: source.correctAnswer,
      explanation: source.explanation,
      estimatedAnswerMinutes: source.estimatedAnswerMinutes,
      difficulty: source.difficulty,
      grade: source.grade,
      subject: source.subject,
      chapter: source.chapter,
      topic: source.topic,
      learningObjective: source.learningObjective,
      cognitiveLevel: source.cognitiveLevel,
      tags: List<String>.from(source.tags),
      language: source.language,
      instructions: source.instructions,
      instructionAlignment: source.instructionAlignment,
      sourceReference: source.sourceReference,
      mathExpressions: clonedMath,
      attachments: clonedAttachments,
      tableData: _copyTable(source.tableData),
      subQuestions: source.subQuestions
          .map((item) => copyQuestion(item, copiedAt: now))
          .toList(),
      internalChoices: source.internalChoices
          .map((item) => copyQuestion(item, copiedAt: now))
          .toList(),
      createdAt: now,
      modifiedAt: now,
      version: 1,
      status: source.status,
      metadata: normalizedMetadata,
    );
  }

  List<Question> copyQuestions(Iterable<Question> questions) {
    final now = DateTime.now();
    return questions
        .map((question) => copyQuestion(question, copiedAt: now))
        .toList();
  }

  MathExpression _copyMathExpression(MathExpression source) {
    return MathExpression(
      id: _nextId(),
      latex: source.latex,
      plainText: source.plainText,
      display: source.display,
      formatVersion: source.formatVersion,
      metadata: _copyDynamicMap(source.metadata),
    );
  }

  String _mathSourceKey(MathExpression expression) =>
      expression.persistentIdentity;

  String _copyRichText(
    String source, {
    required Map<String, MathExpression> mathBySourceKey,
    required List<MathExpression> clonedMath,
  }) {
    final trimmed = source.trim();
    if (!trimmed.startsWith('[')) {
      return source;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        return source;
      }
      final operations = <Map<String, dynamic>>[];

      for (final rawOperation in decoded.whereType<Map>()) {
        final operation = Map<String, dynamic>.from(rawOperation);
        final rawInsert = operation['insert'];
        if (rawInsert is Map) {
          final insert = Map<String, dynamic>.from(rawInsert);
          _copyMathEmbed(
            insert,
            mathBySourceKey: mathBySourceKey,
            clonedMath: clonedMath,
          );
          _copyGeometryEmbed(insert);
          operation['insert'] = insert;
        }
        if (operation['attributes'] is Map) {
          operation['attributes'] = _copyDynamicMap(
            Map<String, dynamic>.from(operation['attributes'] as Map),
          );
        }
        operations.add(operation);
      }
      return jsonEncode(operations);
    } catch (_) {
      // Legacy/plain/malformed text is deliberately preserved rather than
      // making a reusable question unreadable.
      return source;
    }
  }

  void _copyMathEmbed(
    Map<String, dynamic> insert, {
    required Map<String, MathExpression> mathBySourceKey,
    required List<MathExpression> clonedMath,
  }) {
    if (!insert.containsKey(MathExpression.quillEmbedKey)) return;
    final embedded = MathExpression.tryFromQuillEmbedData(
      insert[MathExpression.quillEmbedKey],
    );
    if (embedded == null) {
      return;
    }

    final key = _mathSourceKey(embedded);
    var cloned = mathBySourceKey[key];
    if (cloned == null) {
      cloned = _copyMathExpression(embedded);
      mathBySourceKey[key] = cloned;
      clonedMath.add(cloned);
    }
    insert[MathExpression.quillEmbedKey] = cloned.toQuillEmbedData();
  }

  void _copyGeometryEmbed(Map<String, dynamic> insert) {
    if (!insert.containsKey('geometry')) return;
    final sourceData = insert['geometry'];
    Map<String, dynamic>? payload;
    var returnAsString = sourceData is String;

    if (sourceData is Map) {
      payload = Map<String, dynamic>.from(sourceData);
    } else if (sourceData is String) {
      try {
        final decoded = jsonDecode(sourceData);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Older geometry embeds may store only an ID string.
      }
    }

    GeometryDiagram? diagram;
    String? oldId;
    if (payload != null) {
      oldId = payload['id']?.toString();
      final rawDiagram = payload['diagram'];
      if (rawDiagram is Map) {
        try {
          diagram = GeometryDiagram.fromJson(
            Map<String, dynamic>.from(rawDiagram),
          );
        } catch (_) {
          diagram = null;
        }
      }
    } else if (sourceData is String && sourceData.trim().isNotEmpty) {
      oldId = sourceData.trim();
    }

    if (diagram == null && oldId != null) {
      diagram = _geometryResolver?.call(oldId);
    }
    if (diagram == null) {
      return;
    }

    final cloned = _copyGeometryDiagram(diagram);
    final nextPayload = payload == null
        ? <String, dynamic>{}
        : _copyDynamicMap(payload);
    nextPayload['id'] = cloned.id;
    nextPayload['diagram'] = cloned.toJson();

    insert['geometry'] = returnAsString ? jsonEncode(nextPayload) : nextPayload;
  }

  GeometryDiagram _copyGeometryDiagram(GeometryDiagram source) {
    final pointIds = <String, String>{};
    final points = source.points.map((point) {
      final newId = _nextId();
      pointIds[point.id] = newId;
      return GeometryPoint(
        id: newId,
        label: point.label,
        position: point.position,
        labelOffset: point.labelOffset,
        labelFontSize: point.labelFontSize,
        labelRotation: point.labelRotation,
        labelBold: point.labelBold,
      );
    }).toList();

    return GeometryDiagram(
      id: _nextId(),
      name: source.name,
      canvasSize: source.canvasSize,
      points: points,
      shapes: source.shapes
          .map(
            (shape) => GeometryShape(
              id: _nextId(),
              type: shape.type,
              pointIds: shape.pointIds.map((id) => pointIds[id] ?? id).toList(),
              radius: shape.radius,
            ),
          )
          .toList(),
      labels: source.labels
          .map(
            (label) => GeometryLabel(
              id: _nextId(),
              type: label.type,
              text: label.text,
              position: label.position,
              fontSize: label.fontSize,
              rotation: label.rotation,
              isBold: label.isBold,
            ),
          )
          .toList(),
      marks: source.marks
          .map(
            (mark) => GeometryMark(
              id: _nextId(),
              type: mark.type,
              pointIds: mark.pointIds.map((id) => pointIds[id] ?? id).toList(),
              position: mark.position,
            ),
          )
          .toList(),
      showGrid: source.showGrid,
      snapToGrid: source.snapToGrid,
      examMode: source.examMode,
      transparentBackground: source.transparentBackground,
    );
  }

  QuestionTable? _copyTable(QuestionTable? source) {
    if (source == null) {
      return null;
    }
    return QuestionTable(
      headers: List<String>.from(source.headers),
      rows: source.rows.map((row) => List<String>.from(row)).toList(),
      caption: source.caption,
      accessibilitySummary: source.accessibilitySummary,
    );
  }

  Map<String, dynamic> _copyDynamicMap(Map<String, dynamic> source) {
    try {
      final decoded = jsonDecode(jsonEncode(source));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Metadata is expected to be JSON-safe, but a shallow independent map is
      // safer than dropping custom metadata when an older file is not.
    }
    return Map<String, dynamic>.from(source);
  }
}
