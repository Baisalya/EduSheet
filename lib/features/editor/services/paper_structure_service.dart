import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';

/// Shared paper-structure rules for authoring, preview and export.
///
/// This deliberately sits above the persisted models: it does not introduce a
/// new storage schema. It only resolves the effective section formatting that
/// already exists on [Paper] and [PaperSection].
class PaperStructureService {
  const PaperStructureService._();

  static QuestionNumberStyle effectiveNumberingStyle(
    Paper paper,
    PaperSection section,
  ) {
    return section.numberingStyle ?? paper.questionNumberStyle;
  }

  static String questionLabel(int oneBased, Paper paper, PaperSection section) {
    return QuestionNumberingService.label(
      oneBased,
      effectiveNumberingStyle(paper, section),
      customLabels: paper.customQuestionNumberLabels,
    );
  }

  static String? answerRuleText(PaperSection section) {
    final required = section.requiredCount;
    final available = section.questions
        .where((q) => !q.isOptional && !q.isWordContentBlock)
        .length;
    if (required == null ||
        required <= 0 ||
        available == 0 ||
        required >= available) {
      return null;
    }
    return 'Answer any $required of $available questions.';
  }

  /// Converts a raw section-list index into the displayed assessment-question
  /// ordinal. Word Mode free-form content blocks deliberately do not consume
  /// a question number.
  static int numberedQuestionOrdinal(
    PaperSection section,
    int rawZeroBasedIndex,
  ) {
    if (section.questions.isEmpty) return 0;
    var ordinal = 0;
    final end = rawZeroBasedIndex.clamp(0, section.questions.length - 1);
    for (var index = 0; index <= end; index++) {
      if (!section.questions[index].isWordContentBlock) ordinal++;
    }
    return ordinal;
  }

  static int assessmentQuestionCount(PaperSection section) {
    return section.questions
        .where((question) => !question.isWordContentBlock)
        .length;
  }

  static String numberingSummary(Paper paper, PaperSection section) {
    final style = effectiveNumberingStyle(paper, section);
    return QuestionNumberingService.displayName(style);
  }

  static String marksSummary(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}
