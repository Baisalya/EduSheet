import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

class SectionWordParser {
  static final RegExp _dividerPattern = RegExp(
    r'^\s*(?:-{3,}|={3,}|\[)\s*(?:question\s*)?(.+?)?\s*(?:-{3,}|={3,}|\])\s*$',
    caseSensitive: false,
  );

  static final RegExp _numberedQuestionPattern = RegExp(
    r'^\s*(?:q(?:uestion)?\.?\s*)?([0-9०-९୦-୯]+)[\).:-]\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _pageBreakPattern = RegExp(
    r'^\s*(?:-{3,}|={3,})\s*page\s+break\s*(?:-{3,}|={3,})\s*$',
    caseSensitive: false,
  );

  static final RegExp _optionPattern = RegExp(
    r'^\s*(?:\(?([a-dA-D])[\).:-])\s+(.+)$',
  );

  static List<Question> parseDeltaJson(
    List<dynamic> deltaJson, {
    QuestionType defaultType = QuestionType.descriptive,
    double defaultMarks = 1.0,
    bool defaultOptional = false,
  }) {
    final document = quill.Document.fromJson(
      deltaJson.cast<Map<String, dynamic>>(),
    );
    return parsePlainText(
      document.toPlainText(),
      defaultType: defaultType,
      defaultMarks: defaultMarks,
      defaultOptional: defaultOptional,
    );
  }

  static List<Question> parseDeltaString(
    String deltaString, {
    QuestionType defaultType = QuestionType.descriptive,
    double defaultMarks = 1.0,
    bool defaultOptional = false,
  }) {
    final decoded = jsonDecode(deltaString);
    if (decoded is! List) {
      throw const FormatException('Expected a Quill Delta JSON list.');
    }

    return parseDeltaJson(
      decoded,
      defaultType: defaultType,
      defaultMarks: defaultMarks,
      defaultOptional: defaultOptional,
    );
  }

  static List<Question> parsePlainText(
    String text, {
    QuestionType defaultType = QuestionType.descriptive,
    double defaultMarks = 1.0,
    bool defaultOptional = false,
  }) {
    final chunks = _splitIntoQuestionChunks(text);
    return chunks
        .map(
          (chunk) => _parseChunk(
            chunk,
            defaultType: defaultType,
            defaultMarks: defaultMarks,
            defaultOptional: defaultOptional,
          ),
        )
        .whereType<Question>()
        .toList();
  }

  static List<List<String>> _splitIntoQuestionChunks(String text) {
    final chunks = <List<String>>[];
    var current = <String>[];

    void flush() {
      final meaningful = current.where((line) => line.trim().isNotEmpty);
      if (meaningful.isNotEmpty) {
        chunks.add([...current]);
      }
      current = <String>[];
    }

    for (final rawLine in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (_pageBreakPattern.hasMatch(line)) {
        continue;
      }

      final dividerMatch = _dividerPattern.firstMatch(line);
      if (dividerMatch != null) {
        flush();
        continue;
      }

      final numberedMatch = _numberedQuestionPattern.firstMatch(line);
      if (numberedMatch != null && current.any((l) => l.trim().isNotEmpty)) {
        flush();
        current.add(numberedMatch.group(2)!.trim());
        continue;
      }

      if (numberedMatch != null && current.isEmpty) {
        current.add(numberedMatch.group(2)!.trim());
      } else {
        current.add(line);
      }
    }

    flush();
    return chunks;
  }

  static Question? _parseChunk(
    List<String> chunk, {
    required QuestionType defaultType,
    required double defaultMarks,
    required bool defaultOptional,
  }) {
    final questionLines = <String>[];
    final options = <QuestionOption>[];

    for (final line in chunk) {
      final optionMatch = _optionPattern.firstMatch(line);
      if (optionMatch != null) {
        options.add(
          QuestionOption(
            id: const Uuid().v4(),
            text: optionMatch.group(2)!.trim(),
          ),
        );
      } else {
        questionLines.add(line);
      }
    }

    final questionText = questionLines.join('\n').trim();
    if (questionText.isEmpty) return null;

    final detectedType = options.length >= 2 ? QuestionType.mcq : defaultType;

    return Question(
      id: const Uuid().v4(),
      text: _plainTextDelta(questionText),
      type: detectedType,
      marks: defaultMarks,
      options: detectedType == QuestionType.mcq ? options : const [],
      isOptional: defaultOptional,
    );
  }

  static String _plainTextDelta(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return jsonEncode([
      {'insert': normalized},
    ]);
  }
}
