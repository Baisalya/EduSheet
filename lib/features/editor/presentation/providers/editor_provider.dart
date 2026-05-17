import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/data/repositories/local_paper_repository.dart';

part 'editor_provider.g.dart';

final paperRepositoryProvider = Provider<PaperRepository>((ref) {
  return LocalPaperRepository();
});

final savedPapersProvider = FutureProvider.autoDispose<List<Paper>>((ref) {
  return ref.watch(paperRepositoryProvider).getAllPapers();
});

@Riverpod(keepAlive: true)
class EditorState extends _$EditorState {
  @override
  Paper build() {
    return Paper(
      id: const Uuid().v4(),
      title: 'New Paper',
      sections: [],
      headerFields: [
        PaperHeaderField(id: const Uuid().v4(), label: 'Subject', value: 'Mathematics'),
        PaperHeaderField(id: const Uuid().v4(), label: 'Class', value: '10th'),
        PaperHeaderField(id: const Uuid().v4(), label: 'Date', isPlaceholder: true),
        PaperHeaderField(id: const Uuid().v4(), label: 'Time', value: '3 Hours'),
        PaperHeaderField(id: const Uuid().v4(), label: 'Student Name', isPlaceholder: true),
        PaperHeaderField(id: const Uuid().v4(), label: 'Roll No', isPlaceholder: true),
      ],
    );
  }

  Future<void> savePaper() async {
    final repo = ref.read(paperRepositoryProvider);
    await repo.savePaper(state);
  }

  void loadPaper(Paper paper) {
    state = paper;
  }

  void reset() {
    state = build();
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

  void addHeaderField({String label = 'New Field', String value = '', bool isPlaceholder = false}) {
    final newField = PaperHeaderField(
      id: const Uuid().v4(),
      label: label,
      value: value,
      isPlaceholder: isPlaceholder,
    );
    state = state.copyWith(headerFields: [...state.headerFields, newField]);
  }

  void updateHeaderField(String id, {String? label, String? value, bool? isPlaceholder}) {
    state = state.copyWith(
      headerFields: state.headerFields.map((f) {
        if (f.id == id) {
          return f.copyWith(
            label: label ?? f.label,
            value: value ?? f.value,
            isPlaceholder: isPlaceholder ?? f.isPlaceholder,
          );
        }
        return f;
      }).toList(),
    );
  }

  void deleteHeaderField(String id) {
    state = state.copyWith(
      headerFields: state.headerFields.where((f) => f.id != id).toList(),
    );
  }

  void reorderHeaderFields(int oldIndex, int newIndex) {
    final fields = [...state.headerFields];
    if (newIndex > oldIndex) newIndex--;
    final field = fields.removeAt(oldIndex);
    fields.insert(newIndex, field);
    state = state.copyWith(headerFields: fields);
  }

  void addSection() {
    final newSection = PaperSection(
      id: const Uuid().v4(),
      title: 'Section ${state.sections.length + 1}',
    );
    state = state.copyWith(sections: [...state.sections, newSection]);
  }

  void updateSection(String sectionId, {
    String? title,
    String? instruction,
    String? prefix,
    int? requiredCount,
    bool clearRequiredCount = false,
    bool? showTitle,
    bool? showDivider,
  }) {
    state = state.copyWith(
      sections: state.sections.map((s) {
        if (s.id == sectionId) {
          return s.copyWith(
            title: title ?? s.title,
            instruction: instruction ?? s.instruction,
            prefix: prefix ?? s.prefix,
            requiredCount: requiredCount ?? s.requiredCount,
            clearRequiredCount: clearRequiredCount,
            showTitle: showTitle ?? s.showTitle,
            showDivider: showDivider ?? s.showDivider,
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

  void addQuestion(String sectionId, String text, {QuestionType type = QuestionType.descriptive, double marks = 1.0, List<QuestionOption> options = const [], bool isOptional = false}) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          final newQuestion = Question(
            id: const Uuid().v4(),
            text: text,
            type: type,
            marks: marks,
            options: options,
            isOptional: isOptional,
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
    bool? isOptional,
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
                  isOptional: isOptional ?? q.isOptional,
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
    final templates = ref.read(templateProvider).all;
    final template = templates.firstWhere((t) => t.id == templateId, orElse: () => templates.first);
    
    state = state.copyWith(templateId: templateId);

    // Automatic Field Detection
    if (template.headerLayout == HeaderLayout.custom && template.customLayout != null) {
      final fieldsBlocks = template.customLayout!.elements.where((e) => e.type == ElementType.headerFieldsBlock);
      if (fieldsBlocks.isNotEmpty) {
        final List<String> labels = List<String>.from(fieldsBlocks.first.properties['fieldLabels'] ?? []);
        final currentLabels = state.headerFields.map((f) => f.label.toLowerCase()).toList();
        
        final List<PaperHeaderField> newFields = [...state.headerFields];
        bool changed = false;
        for (var label in labels) {
          if (!currentLabels.contains(label.toLowerCase())) {
            newFields.add(PaperHeaderField(
              id: const Uuid().v4(),
              label: label,
              isPlaceholder: true,
            ));
            changed = true;
          }
        }
        if (changed) {
          state = state.copyWith(headerFields: newFields);
        }
      }
    }
  }
}
