import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';

/// Canonical printable projection of the rich content stored inside a question.
///
/// The editor is allowed to add selection chrome, resize handles and helper UI,
/// but Preview/PDF/DOCX should reason about this projection only. This keeps
/// persisted document content separate from transient authoring state.
enum QuestionPrintContentKind { richText, mathExpression, geometry }

class QuestionPrintContentObject {
  final QuestionPrintContentKind kind;
  final List<Map<String, dynamic>> operations;
  final MathExpression? mathExpression;
  final GeometryEmbedLayout? geometryLayout;

  const QuestionPrintContentObject._({
    required this.kind,
    this.operations = const [],
    this.mathExpression,
    this.geometryLayout,
  });

  factory QuestionPrintContentObject.richText(
    List<Map<String, dynamic>> operations,
  ) {
    return QuestionPrintContentObject._(
      kind: QuestionPrintContentKind.richText,
      operations: List.unmodifiable(operations),
    );
  }

  factory QuestionPrintContentObject.math(MathExpression expression) {
    return QuestionPrintContentObject._(
      kind: QuestionPrintContentKind.mathExpression,
      mathExpression: expression,
    );
  }

  factory QuestionPrintContentObject.geometry(GeometryEmbedLayout layout) {
    return QuestionPrintContentObject._(
      kind: QuestionPrintContentKind.geometry,
      geometryLayout: layout.normalized(),
    );
  }
}

class QuestionPrintContentDocument {
  final bool isStructuredRichText;
  final List<QuestionPrintContentObject> objects;

  const QuestionPrintContentDocument({
    required this.isStructuredRichText,
    required this.objects,
  });

  Iterable<GeometryEmbedLayout> get geometryEmbeds sync* {
    for (final object in objects) {
      final layout = object.geometryLayout;
      if (object.kind == QuestionPrintContentKind.geometry && layout != null) {
        yield layout;
      }
    }
  }

  String get accessibleText {
    final buffer = StringBuffer();
    for (final object in objects) {
      switch (object.kind) {
        case QuestionPrintContentKind.richText:
          for (final operation in object.operations) {
            final insert = operation['insert'];
            if (insert is String) buffer.write(insert);
          }
          break;
        case QuestionPrintContentKind.mathExpression:
          final expression = object.mathExpression;
          if (expression != null) {
            final fallback = expression.plainText.trim();
            buffer.write(fallback.isEmpty ? expression.latex : fallback);
          }
          break;
        case QuestionPrintContentKind.geometry:
          buffer.write('[diagram]');
          break;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Splits a Quill delta into printable content objects in exact document order.
///
/// Geometry editor labels such as a template name or wrap-mode label are never
/// introduced here, so they cannot leak into Preview/PDF/DOCX through this
/// boundary.
class QuestionPrintContentProjection {
  const QuestionPrintContentProjection._();

  static QuestionPrintContentDocument fromRichText(String richText) {
    final value = richText.trimLeft();
    if (!value.startsWith('[')) {
      return QuestionPrintContentDocument(
        isStructuredRichText: false,
        objects: [
          if (richText.isNotEmpty)
            QuestionPrintContentObject.richText([
              {'insert': richText},
            ]),
        ],
      );
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return fromOperations(decoded.whereType<Map>());
      }
    } catch (_) {
      // Malformed structured content is handled by the caller's legacy
      // fallback. Mark it non-structured instead of inventing document data.
    }

    return QuestionPrintContentDocument(
      isStructuredRichText: false,
      objects: [
        if (richText.isNotEmpty)
          QuestionPrintContentObject.richText([
            {'insert': richText},
          ]),
      ],
    );
  }

  static QuestionPrintContentDocument fromOperations(
    Iterable<Map<dynamic, dynamic>> rawOperations,
  ) {
    final objects = <QuestionPrintContentObject>[];
    final pendingText = <Map<String, dynamic>>[];

    void flushText() {
      if (pendingText.isEmpty) return;
      objects.add(
        QuestionPrintContentObject.richText(
          pendingText.map(Map<String, dynamic>.from).toList(growable: false),
        ),
      );
      pendingText.clear();
    }

    for (final raw in rawOperations) {
      final operation = Map<String, dynamic>.from(raw);
      final insert = operation['insert'];
      if (insert is Map) {
        if (insert.containsKey(MathExpression.quillEmbedKey)) {
          final expression = MathExpression.tryFromQuillEmbedData(
            insert[MathExpression.quillEmbedKey],
          );
          if (expression == null) {
            operation['insert'] = '[formula]';
            pendingText.add(operation);
          } else {
            flushText();
            objects.add(QuestionPrintContentObject.math(expression));
          }
          continue;
        }
        if (insert.containsKey('geometry')) {
          flushText();
          objects.add(
            QuestionPrintContentObject.geometry(
              GeometryEmbedLayout.fromData(insert['geometry']),
            ),
          );
          continue;
        }
      }
      pendingText.add(operation);
    }
    flushText();

    return QuestionPrintContentDocument(
      isStructuredRichText: true,
      objects: List.unmodifiable(objects),
    );
  }
}
