import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';

enum WordContentBlockKind { paragraph, table, image, pageBreak }

/// Compatibility-safe bridge for Word Mode free-form content.
///
/// A Word content block is persisted as a normal [Question] with a small
/// metadata marker. This keeps [Paper] as the single source of truth and lets
/// older saved papers continue to deserialize without a migration. Smart Mode,
/// preview and exporters can identify these blocks and avoid treating them as
/// assessment questions (no numbering and no marks).
class WordContentBlockService {
  const WordContentBlockService._();

  static WordContentBlockKind? kindOf(Question question) {
    final name = question.wordContentBlockKind;
    if (name == null) return null;
    for (final kind in WordContentBlockKind.values) {
      if (kind.name == name) return kind;
    }
    return WordContentBlockKind.paragraph;
  }

  static Question paragraph({String text = ''}) {
    return _base(
      kind: WordContentBlockKind.paragraph,
      text: _delta(text),
      plainText: text.trim(),
    );
  }

  static Question table(QuestionTable table) {
    return _base(
      kind: WordContentBlockKind.table,
      text: _delta(''),
      plainText: table.caption.trim(),
      tableData: table,
    );
  }

  static Question image(QuestionAttachment attachment) {
    final plain = attachment.caption.trim().isNotEmpty
        ? attachment.caption.trim()
        : attachment.alternativeText.trim();
    return _base(
      kind: WordContentBlockKind.image,
      text: _delta(''),
      plainText: plain,
      attachments: [attachment],
    );
  }

  static Question pageBreak() {
    return _base(
      kind: WordContentBlockKind.pageBreak,
      text: _delta(''),
      plainText: '',
    );
  }

  static Question _base({
    required WordContentBlockKind kind,
    required String text,
    required String plainText,
    QuestionTable? tableData,
    List<QuestionAttachment> attachments = const [],
  }) {
    return Question(
      id: const Uuid().v4(),
      text: text,
      plainTextAccessibility: plainText,
      type: QuestionType.custom,
      marks: 0,
      tableData: tableData,
      attachments: attachments,
      metadata: {
        Question.wordContentBlockKindMetadataKey: kind.name,
        Question.wordContentBlockVersionMetadataKey: 1,
      },
    );
  }

  static String _delta(String value) {
    final normalized = value.endsWith('\n') ? value : '$value\n';
    return jsonEncode([
      {'insert': normalized},
    ]);
  }
}
