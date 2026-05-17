import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:uuid/uuid.dart';

class TemplateState {
  final List<PaperTemplate> predefined;
  final List<PaperTemplate> custom;
  final bool isLoading;

  TemplateState({
    this.predefined = const [],
    this.custom = const [],
    this.isLoading = false,
  });

  List<PaperTemplate> get all => [...predefined, ...custom];

  TemplateState copyWith({
    List<PaperTemplate>? predefined,
    List<PaperTemplate>? custom,
    bool? isLoading,
  }) {
    return TemplateState(
      predefined: predefined ?? this.predefined,
      custom: custom ?? this.custom,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TemplateNotifier extends StateNotifier<TemplateState> {
  final TemplateRepository _repository;

  TemplateNotifier(this._repository) : super(TemplateState(predefined: PaperTemplate.predefinedTemplates)) {
    loadCustomTemplates();
  }

  Future<void> loadCustomTemplates() async {
    state = state.copyWith(isLoading: true);
    final custom = await _repository.getCustomTemplates();
    state = state.copyWith(custom: custom, isLoading: false);
  }

  Future<void> saveAsCustom(PaperTemplate base, String name) async {
    final custom = PaperTemplate(
      id: const Uuid().v4(),
      name: name,
      type: base.type,
      primaryColor: base.primaryColor,
      secondaryColor: base.secondaryColor,
      headerFontSize: base.headerFontSize,
      questionFontSize: base.questionFontSize,
      hasBorder: base.hasBorder,
      centeredHeader: base.centeredHeader,
      headerLayout: base.headerLayout,
      paperLayout: base.paperLayout,
      customLayout: base.customLayout,
    );
    await _repository.saveTemplate(custom);
    await loadCustomTemplates();
  }

  Future<void> saveTemplate(PaperTemplate template) async {
    await _repository.saveTemplate(template);
    await loadCustomTemplates();
  }
}

final templateRepositoryProvider = Provider((ref) => TemplateRepository());

final templateProvider = StateNotifierProvider<TemplateNotifier, TemplateState>((ref) {
  return TemplateNotifier(ref.watch(templateRepositoryProvider));
});
