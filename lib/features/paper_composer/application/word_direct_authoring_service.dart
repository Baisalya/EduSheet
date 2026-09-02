import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';

/// Canonical mutations used by Word Mode's direct-on-page authoring flow.
///
/// Phase 4A intentionally keeps [Paper] / [Question] as the only persisted
/// document model. Creating a question inline or adding a picture therefore
/// produces the same [Question] objects that Smart Mode, Preview and exporters
/// already understand; there is no parallel Word-only document copy.
class WordDirectAuthoringService {
  const WordDirectAuthoringService._();

  static Question blankAssessmentQuestion({double? defaultMarks}) {
    final marks = _normalizedMarks(defaultMarks);
    return QuestionDraft.create(
      type: QuestionType.descriptive,
      marks: marks,
    ).toQuestion(plainTextAccessibility: '');
  }

  static Question appendImage(
    Question question,
    QuestionAttachment attachment,
  ) {
    return question.copyWith(
      attachments: [...question.attachments, attachment],
    );
  }

  static Question replaceImage(
    Question question,
    String attachmentId,
    QuestionAttachment replacement,
  ) {
    final attachments = [
      for (final item in question.attachments)
        if (item.id == attachmentId)
          replacement.copyWith(id: attachmentId)
        else
          item,
    ];
    return question.copyWith(attachments: attachments);
  }

  static Question removeImage(Question question, String attachmentId) {
    return question.copyWith(
      attachments: question.attachments
          .where((item) => item.id != attachmentId)
          .toList(growable: false),
    );
  }

  static double _normalizedMarks(double? value) {
    if (value == null || !value.isFinite || value <= 0) return 1.0;
    return value;
  }
}
