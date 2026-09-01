import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';

class ResolvedQuestionAnswerSpace {
  final QuestionAnswerSpaceStyle style;
  final int lines;
  final bool questionOverride;

  const ResolvedQuestionAnswerSpace({
    required this.style,
    required this.lines,
    required this.questionOverride,
  });

  bool get isVisible => style != QuestionAnswerSpaceStyle.none && lines > 0;
}

class QuestionAdvancedStructureService {
  const QuestionAdvancedStructureService._();

  static String partLabel(int index) => '(${_numberToAlpha(index + 1)})';

  static List<String> accessibilityFragments(QuestionDraft draft) {
    final fragments = <String>[];
    final advanced = draft.advancedContent;
    if (advanced.hasStimulus) {
      final stimulus = advanced.stimulus!;
      if (stimulus.title.trim().isNotEmpty) {
        fragments.add(stimulus.title.trim());
      }
      fragments.add(stimulus.text.trim());
    }
    if (advanced.hasWordBank) {
      fragments.add('Word bank: ${advanced.wordBank.join(', ')}');
    }
    final table = draft.tableData;
    if (table != null) {
      if (table.caption.trim().isNotEmpty) fragments.add(table.caption.trim());
      if (table.accessibilitySummary.trim().isNotEmpty) {
        fragments.add(table.accessibilitySummary.trim());
      } else {
        final cells = <String>[
          ...table.headers,
          ...table.rows.expand((row) => row),
        ].map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).toList();
        if (cells.isNotEmpty) fragments.add('Table: ${cells.join(', ')}');
      }
    }
    for (final attachment in draft.attachments) {
      final description = attachment.alternativeText.trim().isNotEmpty
          ? attachment.alternativeText.trim()
          : attachment.caption.trim();
      if (description.isNotEmpty) fragments.add(description);
    }
    for (final child in draft.subQuestions) {
      if (child.plainTextAccessibility.trim().isNotEmpty) {
        fragments.add(child.plainTextAccessibility.trim());
      }
    }
    for (final choice in draft.internalChoices) {
      if (choice.plainTextAccessibility.trim().isNotEmpty) {
        fragments.add(choice.plainTextAccessibility.trim());
      }
    }
    return fragments;
  }

  static bool internalChoiceMarksBalanced(List<Question> choices) {
    if (choices.length < 2) return true;
    final first = choices.first.marks;
    return choices
        .skip(1)
        .every((choice) => (choice.marks - first).abs() < 0.001);
  }

  static String internalChoiceMarksSummary(List<Question> choices) {
    if (choices.isEmpty) return '';
    final marks = choices.map((choice) => _marks(choice.marks)).toSet();
    return marks.length == 1
        ? '${marks.first} marks each'
        : '${marks.join(' / ')} marks';
  }

  static ResolvedQuestionAnswerSpace resolveAnswerSpace(
    Question question,
    PaperSection section, {
    int fallbackLines = 0,
  }) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    if (advanced.hasAnswerSpace) {
      return ResolvedQuestionAnswerSpace(
        style: advanced.answerSpace.style,
        lines: advanced.answerSpace.lines,
        questionOverride: true,
      );
    }

    if (section.answerSpaceLines > 0) {
      final style = section.graphAnswerArea
          ? QuestionAnswerSpaceStyle.graph
          : section.ruledAnswerArea
          ? QuestionAnswerSpaceStyle.ruled
          : QuestionAnswerSpaceStyle.blank;
      return ResolvedQuestionAnswerSpace(
        style: style,
        lines: section.answerSpaceLines,
        questionOverride: false,
      );
    }

    if (fallbackLines > 0) {
      return ResolvedQuestionAnswerSpace(
        style: QuestionAnswerSpaceStyle.ruled,
        lines: fallbackLines,
        questionOverride: false,
      );
    }

    return const ResolvedQuestionAnswerSpace(
      style: QuestionAnswerSpaceStyle.none,
      lines: 0,
      questionOverride: false,
    );
  }

  static String _numberToAlpha(int value) {
    var number = value < 1 ? 1 : value;
    final codes = <int>[];
    while (number > 0) {
      number -= 1;
      codes.add(97 + (number % 26));
      number ~/= 26;
    }
    return String.fromCharCodes(codes.reversed);
  }

  static String _marks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
