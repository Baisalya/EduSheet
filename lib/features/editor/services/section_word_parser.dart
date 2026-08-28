import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter/material.dart' show TextAlign;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

/// Converts the section-wide Word editor document back into individual
/// questions without flattening rich text or custom embeds.
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
    List<Question> sourceQuestions = const [],
  }) {
    final lines = _deltaToLines(deltaJson);
    final chunks = _splitRichLinesIntoQuestionChunks(lines);

    // Word Mode always writes visible question dividers. Keep the legacy
    // plain-text parser as a safe fallback for pasted/imported documents that
    // contain no rich chunks or use an unfamiliar layout.
    if (chunks.isEmpty) {
      final document = quill.Document.fromJson(
        deltaJson.cast<Map<String, dynamic>>(),
      );
      return parsePlainText(
        document.toPlainText(),
        defaultType: defaultType,
        defaultMarks: defaultMarks,
        defaultOptional: defaultOptional,
        sourceQuestions: sourceQuestions,
      );
    }

    final questions = <Question>[];
    for (var index = 0; index < chunks.length; index++) {
      final parsed = _parseRichChunk(
        chunks[index],
        sourceQuestion: index < sourceQuestions.length
            ? sourceQuestions[index]
            : null,
        defaultType: defaultType,
        defaultMarks: defaultMarks,
        defaultOptional: defaultOptional,
      );
      if (parsed != null) questions.add(parsed);
    }
    return questions;
  }

  static List<Question> parseDeltaString(
    String deltaString, {
    QuestionType defaultType = QuestionType.descriptive,
    double defaultMarks = 1.0,
    bool defaultOptional = false,
    List<Question> sourceQuestions = const [],
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
      sourceQuestions: sourceQuestions,
    );
  }

  static List<Question> parsePlainText(
    String text, {
    QuestionType defaultType = QuestionType.descriptive,
    double defaultMarks = 1.0,
    bool defaultOptional = false,
    List<Question> sourceQuestions = const [],
  }) {
    final chunks = _splitIntoQuestionChunks(text);
    final questions = <Question>[];
    for (var index = 0; index < chunks.length; index++) {
      final parsed = _parsePlainChunk(
        chunks[index],
        sourceQuestion: index < sourceQuestions.length
            ? sourceQuestions[index]
            : null,
        defaultType: defaultType,
        defaultMarks: defaultMarks,
        defaultOptional: defaultOptional,
      );
      if (parsed != null) questions.add(parsed);
    }
    return questions;
  }

  static List<_RichLine> _deltaToLines(List<dynamic> deltaJson) {
    final lines = <_RichLine>[];
    var currentOps = <Map<String, dynamic>>[];

    void finishLine([Map<String, dynamic>? newlineAttributes]) {
      lines.add(
        _RichLine(
          operations: List<Map<String, dynamic>>.unmodifiable(currentOps),
          newlineAttributes: newlineAttributes == null
              ? null
              : Map<String, dynamic>.from(newlineAttributes),
        ),
      );
      currentOps = <Map<String, dynamic>>[];
    }

    for (final rawOperation in deltaJson) {
      if (rawOperation is! Map) continue;
      final operation = Map<String, dynamic>.from(rawOperation);
      final insert = operation['insert'];
      final attributes = operation['attributes'];
      final safeAttributes = attributes is Map
          ? Map<String, dynamic>.from(attributes)
          : null;

      if (insert is! String) {
        currentOps.add(_copyOperation(operation));
        continue;
      }

      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        if (part.isNotEmpty) {
          currentOps.add({
            'insert': part,
            if (safeAttributes != null && safeAttributes.isNotEmpty)
              'attributes': Map<String, dynamic>.from(safeAttributes),
          });
        }
        if (index < parts.length - 1) finishLine(safeAttributes);
      }
    }

    if (currentOps.isNotEmpty) finishLine();
    return lines;
  }

  static List<List<_RichLine>> _splitRichLinesIntoQuestionChunks(
    List<_RichLine> lines,
  ) {
    final chunks = <List<_RichLine>>[];
    var current = <_RichLine>[];
    var sawQuestionDivider = false;

    void flush() {
      final trimmed = _trimBlankRichLines(current);
      if (trimmed.isNotEmpty) chunks.add(trimmed);
      current = <_RichLine>[];
    }

    for (final line in lines) {
      final text = line.plainText.trimRight();
      if (_pageBreakPattern.hasMatch(text)) continue;

      final dividerMatch = _dividerPattern.firstMatch(text);
      if (dividerMatch != null) {
        flush();
        sawQuestionDivider = true;
        continue;
      }

      final numberedMatch = _numberedQuestionPattern.firstMatch(text);
      if (!sawQuestionDivider && numberedMatch != null) {
        if (current.any((entry) => entry.isMeaningful)) flush();
        final questionText = numberedMatch.group(2)!.trim();
        current.add(
          _RichLine(
            operations: [
              {'insert': questionText},
            ],
            newlineAttributes: line.newlineAttributes,
          ),
        );
        continue;
      }

      current.add(line);
    }

    flush();
    return chunks;
  }

  static Question? _parseRichChunk(
    List<_RichLine> chunk, {
    required Question? sourceQuestion,
    required QuestionType defaultType,
    required double defaultMarks,
    required bool defaultOptional,
  }) {
    final questionLines = <_RichLine>[];
    final optionTexts = <String>[];

    for (final line in chunk) {
      final optionMatch = _optionPattern.firstMatch(line.plainText);
      if (optionMatch != null && !line.hasEmbed) {
        optionTexts.add(optionMatch.group(2)!.trim());
      } else {
        questionLines.add(line);
      }
    }

    final trimmedQuestionLines = _trimBlankRichLines(questionLines);
    if (trimmedQuestionLines.isEmpty ||
        !trimmedQuestionLines.any((line) => line.isMeaningful)) {
      return null;
    }

    final options = _buildOptions(
      optionTexts,
      sourceQuestion?.options ?? const [],
    );
    final detectedType = options.length >= 2
        ? QuestionType.mcq
        : sourceQuestion?.type ?? defaultType;

    return Question(
      id: sourceQuestion?.id ?? const Uuid().v4(),
      text: jsonEncode(_linesToDelta(trimmedQuestionLines)),
      imageUrl: sourceQuestion?.imageUrl,
      options: detectedType == QuestionType.mcq ? options : const [],
      type: detectedType,
      marks: sourceQuestion?.marks ?? defaultMarks,
      alignment:
          sourceQuestion?.alignment ?? _alignmentFromLines(questionLines),
      isOptional: sourceQuestion?.isOptional ?? defaultOptional,
    );
  }

  static List<QuestionOption> _buildOptions(
    List<String> optionTexts,
    List<QuestionOption> sourceOptions,
  ) {
    return optionTexts.asMap().entries.map((entry) {
      final source = entry.key < sourceOptions.length
          ? sourceOptions[entry.key]
          : null;
      return QuestionOption(
        id: source?.id ?? const Uuid().v4(),
        text: entry.value,
        isCorrect: source?.isCorrect ?? false,
      );
    }).toList();
  }

  static List<Map<String, dynamic>> _linesToDelta(List<_RichLine> lines) {
    final delta = <Map<String, dynamic>>[];
    for (final line in lines) {
      delta.addAll(line.operations.map(_copyOperation));
      delta.add({
        'insert': '\n',
        if (line.newlineAttributes != null &&
            line.newlineAttributes!.isNotEmpty)
          'attributes': Map<String, dynamic>.from(line.newlineAttributes!),
      });
    }
    if (delta.isEmpty) {
      delta.add({'insert': '\n'});
    }
    return delta;
  }

  static TextAlign _alignmentFromLines(List<_RichLine> lines) {
    for (final line in lines) {
      final align = line.newlineAttributes?['align'];
      switch (align) {
        case 'center':
          return TextAlign.center;
        case 'right':
          return TextAlign.right;
        case 'justify':
          return TextAlign.justify;
      }
    }
    return TextAlign.left;
  }

  static List<_RichLine> _trimBlankRichLines(List<_RichLine> lines) {
    var start = 0;
    var end = lines.length;
    while (start < end && !lines[start].isMeaningful) {
      start++;
    }
    while (end > start && !lines[end - 1].isMeaningful) {
      end--;
    }
    return lines.sublist(start, end);
  }

  static Map<String, dynamic> _copyOperation(Map<String, dynamic> operation) {
    final copy = <String, dynamic>{'insert': operation['insert']};
    final attributes = operation['attributes'];
    if (attributes is Map && attributes.isNotEmpty) {
      copy['attributes'] = Map<String, dynamic>.from(attributes);
    }
    return copy;
  }

  static List<List<String>> _splitIntoQuestionChunks(String text) {
    final chunks = <List<String>>[];
    var current = <String>[];

    void flush() {
      final meaningful = current.where((line) => line.trim().isNotEmpty);
      if (meaningful.isNotEmpty) chunks.add([...current]);
      current = <String>[];
    }

    for (final rawLine in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (_pageBreakPattern.hasMatch(line)) continue;

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

  static Question? _parsePlainChunk(
    List<String> chunk, {
    required Question? sourceQuestion,
    required QuestionType defaultType,
    required double defaultMarks,
    required bool defaultOptional,
  }) {
    final questionLines = <String>[];
    final optionTexts = <String>[];

    for (final line in chunk) {
      final optionMatch = _optionPattern.firstMatch(line);
      if (optionMatch != null) {
        optionTexts.add(optionMatch.group(2)!.trim());
      } else {
        questionLines.add(line);
      }
    }

    final questionText = questionLines.join('\n').trim();
    if (questionText.isEmpty) return null;

    final options = _buildOptions(
      optionTexts,
      sourceQuestion?.options ?? const [],
    );
    final detectedType = options.length >= 2
        ? QuestionType.mcq
        : sourceQuestion?.type ?? defaultType;

    return Question(
      id: sourceQuestion?.id ?? const Uuid().v4(),
      text: _plainTextDelta(questionText),
      imageUrl: sourceQuestion?.imageUrl,
      options: detectedType == QuestionType.mcq ? options : const [],
      type: detectedType,
      marks: sourceQuestion?.marks ?? defaultMarks,
      alignment: sourceQuestion?.alignment ?? TextAlign.left,
      isOptional: sourceQuestion?.isOptional ?? defaultOptional,
    );
  }

  static String _plainTextDelta(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return jsonEncode([
      {'insert': normalized},
    ]);
  }
}

class _RichLine {
  final List<Map<String, dynamic>> operations;
  final Map<String, dynamic>? newlineAttributes;

  const _RichLine({required this.operations, required this.newlineAttributes});

  String get plainText {
    final buffer = StringBuffer();
    for (final operation in operations) {
      final insert = operation['insert'];
      if (insert is String) {
        buffer.write(insert);
      } else if (insert != null) {
        buffer.write('\uFFFC');
      }
    }
    return buffer.toString();
  }

  bool get hasEmbed =>
      operations.any((operation) => operation['insert'] is! String);

  bool get isMeaningful => plainText.trim().isNotEmpty || hasEmbed;
}
