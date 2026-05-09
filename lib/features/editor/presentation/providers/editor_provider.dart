import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';

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

  void addSection() {
    final newSection = PaperSection(
      id: const Uuid().v4(),
      title: 'Section ${state.sections.length + 1}',
    );
    state = state.copyWith(sections: [...state.sections, newSection]);
  }

  void addQuestion(String sectionId, String text, {List<String>? options}) {
    final sections = state.sections.map((section) {
      if (section.id == sectionId) {
        final newQuestion = Question(
          id: const Uuid().v4(),
          text: text,
          options: options ?? [],
        );
        return section.copyWith(questions: [...section.questions, newQuestion]);
      }
      return section;
    }).toList();
    state = state.copyWith(sections: sections);
  }

  void toggleOmr(bool value) {
    state = state.copyWith(includeOmr: value);
  }
}
