import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

part 'editor_provider.g.dart';

@riverpod
class EditorState extends _$EditorState {
  @override
  Paper build() {
    return Paper(
      id: const Uuid().v4(),
      title: 'New Paper',
      sections: [],
    );
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateBranding({String? schoolName, String? schoolLogo}) {
    state = state.copyWith(
      schoolName: schoolName ?? state.schoolName,
      schoolLogo: schoolLogo ?? state.schoolLogo,
    );
  }

  void addSection() {
    final newSection = PaperSection(
      id: const Uuid().v4(),
      title: 'Section ${state.sections.length + 1}',
    );
    state = state.copyWith(sections: [...state.sections, newSection]);
  }

  void updateSection(String sectionId, {String? title, String? instruction, String? prefix}) {
    state = state.copyWith(
      sections: state.sections.map((s) {
        if (s.id == sectionId) {
          return s.copyWith(
            title: title ?? s.title,
            instruction: instruction ?? s.instruction,
            prefix: prefix ?? s.prefix,
          );
        }
        return s;
      }).toList(),
    );
  }

  void deleteSection(String sectionId) {
    state = state.copyWith(
      sections: state.sections.where((s) => s.id != sectionId).toList(),
    );
  }

  void reorderSections(int oldIndex, int newIndex) {
    final sections = [...state.sections];
    if (newIndex > oldIndex) newIndex--;
    final section = sections.removeAt(oldIndex);
    sections.insert(newIndex, section);
    state = state.copyWith(sections: sections);
  }

  void addQuestion(String sectionId, String text, {QuestionType type = QuestionType.descriptive, double marks = 1.0, List<QuestionOption> options = const []}) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          final newQuestion = Question(
            id: const Uuid().v4(),
            text: text,
            type: type,
            marks: marks,
            options: options,
          );
          return section.copyWith(questions: [...section.questions, newQuestion]);
        }
        return section;
      }).toList(),
    );
  }

  void updateQuestion(String sectionId, String questionId, {
    String? text,
    QuestionType? type,
    double? marks,
    String? imageUrl,
    TextAlign? alignment,
    List<QuestionOption>? options,
  }) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          return section.copyWith(
            questions: section.questions.map((q) {
              if (q.id == questionId) {
                return q.copyWith(
                  text: text ?? q.text,
                  type: type ?? q.type,
                  marks: marks ?? q.marks,
                  imageUrl: imageUrl ?? q.imageUrl,
                  alignment: alignment ?? q.alignment,
                  options: options ?? q.options,
                );
              }
              return q;
            }).toList(),
          );
        }
        return section;
      }).toList(),
    );
  }

  void deleteQuestion(String sectionId, String questionId) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          return section.copyWith(
            questions: section.questions.where((q) => q.id != questionId).toList(),
          );
        }
        return section;
      }).toList(),
    );
  }

  void reorderQuestions(String sectionId, int oldIndex, int newIndex) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          final questions = [...section.questions];
          if (newIndex > oldIndex) newIndex--;
          final q = questions.removeAt(oldIndex);
          questions.insert(newIndex, q);
          return section.copyWith(questions: questions);
        }
        return section;
      }).toList(),
    );
  }

  void toggleOmr(bool value) {
    state = state.copyWith(includeOmr: value);
  }

  void updateTemplate(String templateId) {
    state = state.copyWith(templateId: templateId);
  }
}
