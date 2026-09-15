import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuestionRichTextInspection {
  final Document document;
  final bool usedLegacyPlainText;
  final bool malformedRichText;
  final int malformedMathEmbedCount;

  const QuestionRichTextInspection({
    required this.document,
    required this.usedLegacyPlainText,
    required this.malformedRichText,
    required this.malformedMathEmbedCount,
  });

  bool get needsRepair => malformedRichText || malformedMathEmbedCount > 0;
}

/// Centralizes compatibility with EduSheet's persisted Quill delta string.
class QuestionRichTextCodec {
  const QuestionRichTextCodec();

  QuestionRichTextInspection inspectQuestion(Question? question) {
    if (question == null || question.text.trim().isEmpty) {
      return QuestionRichTextInspection(
        document: Document(),
        usedLegacyPlainText: false,
        malformedRichText: false,
        malformedMathEmbedCount: 0,
      );
    }

    final value = question.text.trim();
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        var malformedMathEmbeds = 0;
        final safeOperations = decoded.whereType<Map>().map((raw) {
          final operation = Map<String, dynamic>.from(raw);
          final insert = operation['insert'];
          if (insert is Map &&
              insert.containsKey(MathExpression.quillEmbedKey)) {
            final expression = MathExpression.tryFromQuillEmbedData(
              insert[MathExpression.quillEmbedKey],
            );
            if (expression == null) {
              malformedMathEmbeds += 1;
              operation['insert'] = '[formula]';
            }
          }
          return operation;
        }).toList();
        try {
          return QuestionRichTextInspection(
            document: Document.fromJson(safeOperations),
            usedLegacyPlainText: false,
            malformedRichText: false,
            malformedMathEmbedCount: malformedMathEmbeds,
          );
        } catch (_) {
          return QuestionRichTextInspection(
            document: _plainFallbackDocument(question),
            usedLegacyPlainText: false,
            malformedRichText: true,
            malformedMathEmbedCount: malformedMathEmbeds,
          );
        }
      }
    } catch (_) {
      // Legacy plain text is intentionally supported below.
    }

    final expectsQuill = question.richTextFormat == 'quill-delta-json-v1';
    final looksStructured = value.startsWith('[') || value.startsWith('{');
    return QuestionRichTextInspection(
      document: _plainFallbackDocument(question),
      usedLegacyPlainText: !looksStructured,
      malformedRichText: expectsQuill && looksStructured,
      malformedMathEmbedCount: 0,
    );
  }

  Document decodeQuestion(Question? question) =>
      inspectQuestion(question).document;

  String encode(Document document) => jsonEncode(document.toDelta().toJson());

  String plainText(Document document) => document.toPlainText().trim();

  String accessibleText(Document document) {
    final buffer = StringBuffer();
    for (final operation in document.toDelta().toJson()) {
      final insert = operation['insert'];
      if (insert is String) {
        buffer.write(insert);
      } else if (insert is Map) {
        if (insert.containsKey('geometry')) buffer.write('[diagram]');
        final expression = _expressionFromInsert(insert);
        if (expression != null) {
          final fallback = expression.plainText.trim();
          buffer.write(fallback.isEmpty ? expression.latex : fallback);
        }
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<MathExpression> embeddedMathExpressions(Document document) {
    final expressions = <MathExpression>[];
    final seen = <String>{};
    for (final operation in document.toDelta().toJson()) {
      final insert = operation['insert'];
      if (insert is! Map) continue;
      final expression = _expressionFromInsert(insert);
      if (expression == null) continue;
      if (!seen.add(expression.persistentIdentity)) continue;
      expressions.add(expression);
    }
    return expressions;
  }

  Set<String> embeddedMathExpressionIds(Document document) {
    return embeddedMathExpressions(
      document,
    ).map((expression) => expression.id).where((id) => id.isNotEmpty).toSet();
  }

  List<MathExpression> unplacedMathExpressions(Question question) {
    final embeddedIdentities = embeddedMathExpressions(
      decodeQuestion(question),
    ).map((expression) => expression.persistentIdentity).toSet();
    final surfaceIdentities = const QuestionMathSurfaceService()
        .activeContentForQuestion(question)
        .expressionIdentities;
    return question.mathExpressions
        .where(
          (expression) =>
              !embeddedIdentities.contains(expression.persistentIdentity) &&
              !surfaceIdentities.contains(expression.persistentIdentity),
        )
        .toList();
  }

  MathExpression? expressionFromInsert(Map<dynamic, dynamic> insert) {
    return _expressionFromInsert(insert);
  }

  Document _plainFallbackDocument(Question question) {
    final fallback = question.plainTextAccessibility.trim().isNotEmpty
        ? question.plainTextAccessibility
        : question.text;
    final document = Document();
    document.insert(0, fallback);
    return document;
  }

  MathExpression? _expressionFromInsert(Map<dynamic, dynamic> insert) {
    if (!insert.containsKey(MathExpression.quillEmbedKey)) return null;
    return MathExpression.tryFromQuillEmbedData(
      insert[MathExpression.quillEmbedKey],
    );
  }
}
