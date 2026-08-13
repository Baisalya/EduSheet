import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Centralizes compatibility with EduSheet's persisted Quill delta string.
class QuestionRichTextCodec {
  const QuestionRichTextCodec();

  Document decodeQuestion(Question? question) {
    if (question == null || question.text.trim().isEmpty) {
      return Document();
    }

    final value = question.text.trim();
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return Document.fromJson(
          decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
    } catch (_) {
      // Legacy plain text is intentionally supported below.
    }

    final document = Document();
    document.insert(0, question.text);
    return document;
  }

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
      if (expression.id.isNotEmpty && !seen.add(expression.id)) continue;
      expressions.add(expression);
    }
    return expressions;
  }

  Set<String> embeddedMathExpressionIds(Document document) {
    return embeddedMathExpressions(document)
        .map((expression) => expression.id)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  List<MathExpression> unplacedMathExpressions(Question question) {
    final embeddedIds = embeddedMathExpressionIds(decodeQuestion(question));
    return question.mathExpressions
        .where((expression) => !embeddedIds.contains(expression.id))
        .toList();
  }

  MathExpression? _expressionFromInsert(Map<dynamic, dynamic> insert) {
    if (!insert.containsKey(MathExpression.quillEmbedKey)) return null;
    return MathExpression.tryFromQuillEmbedData(
      insert[MathExpression.quillEmbedKey],
    );
  }
}
