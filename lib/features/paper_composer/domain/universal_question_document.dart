/// A storage-independent view of the content that makes up one question.
///
/// EduSheet historically persisted a single [QuestionType] together with
/// separate fields such as options, attachments, tables, sub-questions and
/// internal choices. The smart paper editor must not treat those structures as
/// mutually exclusive. This document deliberately models them as co-existing
/// content blocks.
enum UniversalQuestionBlockKind {
  prompt,
  stimulus,
  wordBank,
  answerOptions,
  attachment,
  table,
  subQuestions,
  internalChoice,
  answerSpace,
}

class UniversalQuestionBlock {
  final UniversalQuestionBlockKind kind;
  final String id;
  final int itemCount;

  const UniversalQuestionBlock({
    required this.kind,
    required this.id,
    this.itemCount = 1,
  });
}

class UniversalQuestionDocument {
  final List<UniversalQuestionBlock> blocks;

  const UniversalQuestionDocument({required this.blocks});

  bool contains(UniversalQuestionBlockKind kind) {
    return blocks.any((block) => block.kind == kind);
  }

  int itemCount(UniversalQuestionBlockKind kind) {
    return blocks
        .where((block) => block.kind == kind)
        .fold(0, (sum, block) => sum + block.itemCount);
  }

  bool get hasStructuredContent =>
      blocks.any((block) => block.kind != UniversalQuestionBlockKind.prompt);
}
