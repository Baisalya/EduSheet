import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';

/// Application boundary between the new authoring UI and the existing editor
/// state/repository/autosave implementation.
class PaperComposerActions {
  final EditorState _editor;

  const PaperComposerActions(this._editor);

  void addSection() => _editor.addSection();

  void renameSection(String sectionId, String title) {
    _editor.updateSection(sectionId, title: title.trim());
  }

  void updateSectionInstruction(String sectionId, String instruction) {
    _editor.updateSection(sectionId, instruction: instruction.trim());
  }

  void updateSectionStructure(
    String sectionId, {
    required String prefix,
    required int? requiredCount,
    required QuestionNumberStyle? numberingStyle,
    required double? defaultMarks,
    required bool showTitle,
    required bool showDivider,
    required bool pageBreakBefore,
    required int answerSpaceLines,
    required bool ruledAnswerArea,
    required bool graphAnswerArea,
  }) {
    _editor.updateSection(
      sectionId,
      prefix: prefix.trim(),
      requiredCount: requiredCount,
      clearRequiredCount: requiredCount == null,
      numberingStyle: numberingStyle,
      clearNumberingStyle: numberingStyle == null,
      defaultMarks: defaultMarks,
      clearDefaultMarks: defaultMarks == null,
      showTitle: showTitle,
      showDivider: showDivider,
      pageBreakBefore: pageBreakBefore,
      answerSpaceLines: answerSpaceLines,
      ruledAnswerArea: ruledAnswerArea,
      graphAnswerArea: graphAnswerArea,
    );
  }

  void reorderQuestions(String sectionId, int oldIndex, int newIndex) {
    _editor.reorderQuestions(sectionId, oldIndex, newIndex);
  }

  void reorderSections(int oldIndex, int newIndex) {
    _editor.reorderSections(oldIndex, newIndex);
  }

  void deleteSection(String sectionId) => _editor.deleteSection(sectionId);

  void duplicateSection(String sectionId) =>
      _editor.duplicateSection(sectionId);

  void duplicateQuestion(String sectionId, String questionId) {
    _editor.duplicateQuestion(sectionId, questionId);
  }

  void addQuestionsFromBank(String sectionId, List<Question> questions) {
    _editor.addQuestionsFromBank(sectionId, questions);
  }

  void addSectionWithQuestionsFromBank(List<Question> questions) {
    _editor.addSectionWithQuestionsFromBank(questions);
  }

  void replaceQuestion(String sectionId, Question question) {
    _editor.replaceQuestionObject(sectionId, question);
  }

  void insertQuestionBlock(
    String sectionId,
    Question question, {
    int? insertAt,
  }) {
    _editor.insertQuestionObject(sectionId, question, insertAt: insertAt);
  }

  void deleteQuestion(String sectionId, String questionId) {
    _editor.deleteQuestion(sectionId, questionId);
  }

  bool saveQuestion({
    required Paper paper,
    required String sectionId,
    required QuestionDraft draft,
    required String plainTextAccessibility,
    int? insertAt,
  }) {
    final section = paper.sections
        .where((item) => item.id == sectionId)
        .firstOrNull;
    if (section == null) return false;

    final question = draft.toQuestion(
      plainTextAccessibility: plainTextAccessibility,
    );
    final questions = [...section.questions];
    final existingIndex = questions.indexWhere(
      (item) => item.id == question.id,
    );

    if (existingIndex >= 0) {
      questions[existingIndex] = question;
    } else {
      final index = (insertAt ?? questions.length)
          .clamp(0, questions.length)
          .toInt();
      questions.insert(index, question);
    }

    _editor.bulkUpdateQuestions(sectionId, questions);
    return true;
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
