import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';

/// Compatibility adapter between the legacy persisted Question contract and
/// the Universal Smart Paper Editor view.
///
/// It does not introduce a second persistence schema. Existing Question fields
/// remain the source of truth while the authoring UI is free to treat their
/// contents as composable blocks.
class UniversalQuestionAdapter {
  const UniversalQuestionAdapter._();

  static UniversalQuestionDocument fromDraft(QuestionDraft draft) {
    final blocks = <UniversalQuestionBlock>[
      const UniversalQuestionBlock(
        kind: UniversalQuestionBlockKind.prompt,
        id: 'prompt',
      ),
    ];

    if (draft.advancedContent.hasStimulus) {
      blocks.add(
        const UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.stimulus,
          id: 'stimulus',
        ),
      );
    }

    if (draft.advancedContent.hasWordBank) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.wordBank,
          id: 'word-bank',
          itemCount: draft.advancedContent.wordBank.length,
        ),
      );
    }

    if (draft.options.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.answerOptions,
          id: 'answer-options',
          itemCount: draft.options.length,
        ),
      );
    }

    for (final attachment in draft.attachments) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.attachment,
          id: 'attachment:${attachment.id}',
        ),
      );
    }

    if (draft.tableData != null) {
      blocks.add(
        const UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.table,
          id: 'table',
        ),
      );
    }

    if (draft.subQuestions.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.subQuestions,
          id: 'sub-questions',
          itemCount: draft.subQuestions.length,
        ),
      );
    }

    if (draft.internalChoices.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.internalChoice,
          id: 'internal-choice',
          itemCount: draft.internalChoices.length,
        ),
      );
    }

    if (draft.advancedContent.hasAnswerSpace) {
      blocks.add(
        const UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.answerSpace,
          id: 'answer-space',
        ),
      );
    }

    return UniversalQuestionDocument(blocks: List.unmodifiable(blocks));
  }

  static String authoringSummary(QuestionDraft draft) {
    final document = fromDraft(draft);
    final parts = <String>[];
    if (document.contains(UniversalQuestionBlockKind.stimulus)) {
      parts.add(draft.advancedContent.stimulus!.kind.label);
    }
    if (document.contains(UniversalQuestionBlockKind.wordBank)) {
      parts.add('word bank');
    }
    if (document.contains(UniversalQuestionBlockKind.answerOptions)) {
      parts.add('${draft.options.length} options');
    }
    if (document.contains(UniversalQuestionBlockKind.subQuestions)) {
      parts.add('${draft.subQuestions.length} parts');
    }
    if (document.contains(UniversalQuestionBlockKind.internalChoice)) {
      parts.add('OR choice');
    }
    if (document.contains(UniversalQuestionBlockKind.table)) {
      parts.add('table');
    }
    if (document.contains(UniversalQuestionBlockKind.attachment)) {
      parts.add(
        '${draft.attachments.length} attachment${draft.attachments.length == 1 ? '' : 's'}',
      );
    }
    if (document.contains(UniversalQuestionBlockKind.answerSpace)) {
      parts.add('answer space');
    }
    return parts.isEmpty ? 'Free writing' : parts.join(' · ');
  }
}
