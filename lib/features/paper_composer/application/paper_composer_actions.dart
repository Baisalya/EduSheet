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

  void deleteSection(String sectionId) => _editor.deleteSection(sectionId);

  void duplicateSection(String sectionId) => _editor.duplicateSection(sectionId);

  void duplicateQuestion(String sectionId, String questionId) {
    _editor.duplicateQuestion(sectionId, questionId);
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
    final section = paper.sections.where((item) => item.id == sectionId).firstOrNull;
    if (section == null) return false;

    final question = draft.toQuestion(
      plainTextAccessibility: plainTextAccessibility,
    );
    final questions = [...section.questions];
    final existingIndex = questions.indexWhere((item) => item.id == question.id);

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
