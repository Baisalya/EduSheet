import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';

/// Compatibility adapter between the persisted Question contract and the
/// Universal Smart Paper Editor view.
///
/// It does not introduce a second persistence schema. Existing Question fields
/// remain the source of truth while editor/preview/export code can treat their
/// contents as composable blocks.
class UniversalQuestionAdapter {
  const UniversalQuestionAdapter._();

  static UniversalQuestionDocument fromDraft(QuestionDraft draft) {
    return _fromParts(
      advancedContent: draft.advancedContent,
      options: draft.options,
      attachments: draft.attachments,
      tableData: draft.tableData,
      subQuestions: draft.subQuestions,
      internalChoices: draft.internalChoices,
    );
  }

  /// Builds the same universal structure directly from persisted content.
  /// Read-only renderers therefore never need to construct an authoring draft.
  static UniversalQuestionDocument fromQuestion(Question question) {
    return _fromParts(
      advancedContent: QuestionAdvancedContent.fromQuestion(question),
      options: question.options,
      attachments: question.attachments,
      tableData: question.tableData,
      subQuestions: question.subQuestions,
      internalChoices: question.internalChoices,
    );
  }

  static UniversalQuestionDocument _fromParts({
    required QuestionAdvancedContent advancedContent,
    required List<QuestionOption> options,
    required List<QuestionAttachment> attachments,
    required QuestionTable? tableData,
    required List<Question> subQuestions,
    required List<Question> internalChoices,
  }) {
    final blocks = <UniversalQuestionBlock>[
      const UniversalQuestionBlock(
        kind: UniversalQuestionBlockKind.prompt,
        id: 'prompt',
      ),
    ];

    if (advancedContent.hasStimulus) {
      blocks.add(
        const UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.stimulus,
          id: 'stimulus',
        ),
      );
    }

    if (advancedContent.hasWordBank) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.wordBank,
          id: 'word-bank',
          itemCount: advancedContent.wordBank.length,
        ),
      );
    }

    if (options.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.answerOptions,
          id: 'answer-options',
          itemCount: options.length,
        ),
      );
    }

    for (final attachment in attachments) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.attachment,
          id: 'attachment:${attachment.id}',
        ),
      );
    }

    if (tableData != null) {
      blocks.add(
        const UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.table,
          id: 'table',
        ),
      );
    }

    if (subQuestions.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.subQuestions,
          id: 'sub-questions',
          itemCount: subQuestions.length,
        ),
      );
    }

    if (internalChoices.isNotEmpty) {
      blocks.add(
        UniversalQuestionBlock(
          kind: UniversalQuestionBlockKind.internalChoice,
          id: 'internal-choice',
          itemCount: internalChoices.length,
        ),
      );
    }

    if (advancedContent.hasAnswerSpace) {
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
