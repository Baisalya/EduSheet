import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/data/repositories/local_paper_repository.dart';
import 'package:edusheet/features/editor/services/autosave_coordinator.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_controller.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_providers.dart';

part 'editor_provider.g.dart';

final productionPaperRepositoryProvider = Provider<PaperRepository>((ref) {
  return LocalPaperRepository();
});

final paperRepositoryProvider = Provider<PaperRepository>((ref) {
  final demoSession = ref.watch(guidedDemoControllerProvider);
  if (isPaperDemoActive(demoSession)) {
    return ref.watch(demoPaperRepositoryProvider);
  }
  return ref.watch(productionPaperRepositoryProvider);
});

final savedPapersProvider = FutureProvider.autoDispose<List<Paper>>((ref) {
  return ref.watch(paperRepositoryProvider).getAllPapers();
});

class QuestionEditorDefaults {
  final QuestionType type;
  final double marks;
  final bool isOptional;

  const QuestionEditorDefaults({
    this.type = QuestionType.descriptive,
    this.marks = 1.0,
    this.isOptional = false,
  });

  QuestionEditorDefaults copyWith({
    QuestionType? type,
    double? marks,
    bool? isOptional,
  }) {
    return QuestionEditorDefaults(
      type: type ?? this.type,
      marks: marks ?? this.marks,
      isOptional: isOptional ?? this.isOptional,
    );
  }
}

final questionEditorDefaultsProvider = StateProvider<QuestionEditorDefaults>(
  (ref) => const QuestionEditorDefaults(),
);

final editorSaveStatusProvider = StateProvider<AutosaveStatus>(
  (ref) => const AutosaveStatus(AutosavePhase.idle),
);

@immutable
class EditorSessionSnapshot {
  const EditorSessionSnapshot({
    required this.paper,
    required this.currentDocumentPersisted,
  });

  final Paper paper;
  final bool currentDocumentPersisted;
}

@Riverpod(keepAlive: true)
class EditorState extends _$EditorState {
  static const int _historyLimit = 50;

  late final QuestionCopyService _questionCopyService = QuestionCopyService(
    geometryResolver: GeometryDiagramRegistry.instance.diagramFor,
  );

  late AutosaveCoordinator<Paper> _autosave;
  final List<Paper> _undoStack = [];
  final List<Paper> _redoStack = [];
  bool _historyNavigation = false;
  final Set<String> _persistedDocumentIds = <String>{};
  final Set<String> _unsavedEditedIds = <String>{};

  @override
  Paper build() {
    final repository = ref.read(paperRepositoryProvider);
    _autosave = _createAutosaveCoordinator(repository);
    ref.onDispose(() => _autosave.dispose());

    listenSelf((previous, next) {
      if (previous != null && previous != next) {
        if (!_historyNavigation) {
          _undoStack.add(previous);
          if (_undoStack.length > _historyLimit) _undoStack.removeAt(0);
          _redoStack.clear();
          if (!_persistedDocumentIds.contains(next.id)) {
            _unsavedEditedIds.add(next.id);
          }
        }
        if (_shouldAutosave(next)) {
          _autosave.schedule(next);
        } else {
          ref.read(editorSaveStatusProvider.notifier).state =
              const AutosaveStatus(AutosavePhase.idle);
        }
      }
    });

    return _newPaper();
  }

  AutosaveCoordinator<Paper> _createAutosaveCoordinator(
    PaperRepository repository,
  ) {
    return AutosaveCoordinator<Paper>(
      save: (paper) async {
        await repository.savePaper(paper);
        _persistedDocumentIds.add(paper.id);
        _unsavedEditedIds.remove(paper.id);
      },
      onStatus: (status) {
        ref.read(editorSaveStatusProvider.notifier).state = status;
        if (status.phase == AutosavePhase.saved) {
          ref.invalidate(savedPapersProvider);
        }
      },
    );
  }

  void _rebindAutosaveRepository(PaperRepository repository) {
    _autosave.dispose();
    _autosave = _createAutosaveCoordinator(repository);
  }

  Paper _newPaper() {
    return Paper(
      id: const Uuid().v4(),
      title: 'New Paper',
      schoolName: '',
      templateId: PaperStyleCatalog.defaultTemplateId,
      sections: const [],
      logos: const [],
      createdAt: DateTime.now(),
      headerFields: [
        PaperHeaderField(
          id: const Uuid().v4(),
          label: 'Subject',
          isPlaceholder: true,
        ),
        PaperHeaderField(
          id: const Uuid().v4(),
          label: 'Class',
          isPlaceholder: true,
        ),
        PaperHeaderField(
          id: const Uuid().v4(),
          label: 'Time',
          isPlaceholder: true,
        ),
      ],
    );
  }

  bool _shouldAutosave(Paper paper) {
    // Existing saved papers keep professional autosave behavior. A brand-new
    // paper is not written to Saved Papers until the teacher explicitly saves
    // it once. This prevents ghost "New Paper" entries when Create Paper is
    // opened and then closed.
    return _persistedDocumentIds.contains(paper.id);
  }

  bool get isCurrentPaperPersisted =>
      _persistedDocumentIds.contains(state.id);

  bool get hasMeaningfulUnsavedDraft =>
      !isCurrentPaperPersisted &&
      _unsavedEditedIds.contains(state.id) &&
      _isMeaningfulDraft(state);

  void discardCurrentUnsavedPaper() {
    if (isCurrentPaperPersisted) return;
    final discardedId = state.id;
    _autosave.discardPending(resetStatus: false);
    _unsavedEditedIds.remove(discardedId);
    _replaceWithoutHistory(_newPaper());
    ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
      AutosavePhase.idle,
    );
  }

  bool _isMeaningfulDraft(Paper paper) {
    if (paper.sections.isNotEmpty) return true;
    if (paper.schoolName.trim().isNotEmpty) return true;
    if (paper.instruction.trim().isNotEmpty) return true;
    if (paper.logos.any((logo) => logo.trim().isNotEmpty)) return true;
    if (paper.maximumMarks != null) return true;
    if (paper.includeCoverPage || paper.includeOmr) return true;
    if (paper.headerText.trim().isNotEmpty ||
        paper.footerText.trim().isNotEmpty) {
      return true;
    }
    if (paper.showPageNumbers) return true;
    if (paper.templateId != PaperStyleCatalog.defaultTemplateId) return true;
    if (paper.title.trim().isNotEmpty && paper.title.trim() != 'New Paper') {
      return true;
    }
    return paper.headerFields.any((field) {
      final value = field.value.trim();
      return value.isNotEmpty && !field.isPlaceholder;
    });
  }

  Future<void> savePaper() async {
    _autosave.schedule(state);
    await _autosave.flush();
  }

  Future<void> flushPendingAutosave() => _autosave.flush();

  bool isPaperPersisted(String paperId) =>
      _persistedDocumentIds.contains(paperId);

  void loadPaper(Paper paper) {
    _autosave.discardPending(resetStatus: false);
    _unsavedEditedIds.remove(paper.id);
    _persistedDocumentIds.add(paper.id);
    _replaceWithoutHistory(paper);
    ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
      AutosavePhase.saved,
    );
  }

  EditorSessionSnapshot captureSessionSnapshot() {
    return EditorSessionSnapshot(
      paper: state,
      currentDocumentPersisted: _persistedDocumentIds.contains(state.id),
    );
  }

  Future<EditorSessionSnapshot> prepareForDemoIsolation() async {
    // Demo Mode temporarily rebinds the editor to an isolated repository.
    // Preserve a meaningful real draft with an explicit safety checkpoint
    // before that repository switch. This is intentionally narrower than
    // normal autosave: an untouched brand-new paper is still not persisted,
    // so opening Create Paper and leaving it never creates a ghost entry.
    if (!isCurrentPaperPersisted && hasMeaningfulUnsavedDraft) {
      _autosave.schedule(state);
    }
    await _autosave.flush();
    if (_autosave.status.phase == AutosavePhase.failed) {
      throw StateError(
        'The current paper could not be saved before starting Demo Mode.',
      );
    }
    return captureSessionSnapshot();
  }

  Future<EditorSessionSnapshot> enterDemoIsolation(
    PaperRepository demoRepository,
  ) async {
    final snapshot = await prepareForDemoIsolation();
    _rebindAutosaveRepository(demoRepository);
    _persistedDocumentIds.clear();
    _unsavedEditedIds.clear();
    _replaceWithoutHistory(_newPaper());
    ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
      AutosavePhase.idle,
    );
    return snapshot;
  }

  Future<void> exitDemoIsolation(
    EditorSessionSnapshot snapshot,
    PaperRepository productionRepository,
  ) async {
    await _autosave.flush();
    _rebindAutosaveRepository(productionRepository);
    restoreSessionSnapshot(snapshot);
  }

  void restoreSessionSnapshot(EditorSessionSnapshot snapshot) {
    _autosave.discardPending(resetStatus: false);
    _persistedDocumentIds.clear();
    _unsavedEditedIds.clear();
    if (snapshot.currentDocumentPersisted) {
      _persistedDocumentIds.add(snapshot.paper.id);
    }
    _replaceWithoutHistory(snapshot.paper);
    if (!_shouldAutosave(snapshot.paper)) {
      ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
        AutosavePhase.idle,
      );
    }
  }

  void reset() {
    _autosave.discardPending(resetStatus: false);
    _unsavedEditedIds.clear();
    _replaceWithoutHistory(_newPaper());
    ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
      AutosavePhase.idle,
    );
  }

  /// Starts a fresh paper from a syllabus context without saving it merely
  /// because Class/Subject were prefilled. New papers require one explicit
  /// Save; after that, normal autosave handles subsequent edits.
  Future<String> startNewPaperForSyllabus({
    String? className,
    String? subjectName,
  }) async {
    await _autosave.flush();
    _autosave.discardPending(resetStatus: false);
    _unsavedEditedIds.clear();
    final base = _newPaper();
    final cleanClass = className?.trim() ?? '';
    final cleanSubject = subjectName?.trim() ?? '';
    final paper = base.copyWith(
      headerFields: base.headerFields.map((field) {
        final normalized = field.label.trim().toLowerCase();
        if (normalized == 'class' && cleanClass.isNotEmpty) {
          return field.copyWith(value: cleanClass, isPlaceholder: false);
        }
        if (normalized == 'subject' && cleanSubject.isNotEmpty) {
          return field.copyWith(value: cleanSubject, isPlaceholder: false);
        }
        return field;
      }).toList(growable: false),
    );
    _replaceWithoutHistory(paper);
    ref.read(editorSaveStatusProvider.notifier).state = const AutosaveStatus(
      AutosavePhase.idle,
    );
    return paper.id;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(state);
    _historyNavigation = true;
    state = previous;
    _historyNavigation = false;
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(state);
    _historyNavigation = true;
    state = next;
    _historyNavigation = false;
  }

  void _replaceWithoutHistory(Paper paper) {
    _undoStack.clear();
    _redoStack.clear();
    _historyNavigation = true;
    state = paper;
    _historyNavigation = false;
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateInstruction(String instruction) {
    state = state.copyWith(instruction: instruction);
  }

  void updateInstructionAlignment(PaperTextAlignment alignment) {
    state = state.copyWith(instructionAlignment: alignment);
  }

  /// Applies the teacher-facing Paper Setup form as one document mutation.
  ///
  /// This keeps autosave and undo/redo semantic: pressing Undo after saving
  /// Paper Setup restores the previous setup in one step instead of walking
  /// backwards through each individual field edit. Empty header IDs are
  /// assigned here so presentation widgets never own persistent identifiers.
  void applyPaperSetup({
    required String title,
    required String schoolName,
    required String instruction,
    PaperTextAlignment? instructionAlignment,
    required List<String> logos,
    required List<PaperHeaderField> headerFields,
    double? maximumMarks,
    bool clearMaximumMarks = false,
  }) {
    final normalizedFields = headerFields
        .map((field) {
          if (field.id.trim().isNotEmpty) return field;
          return field.copyWith(id: const Uuid().v4());
        })
        .toList(growable: false);

    state = state.copyWith(
      title: title,
      schoolName: schoolName,
      instruction: instruction,
      instructionAlignment: instructionAlignment ?? state.instructionAlignment,
      logos: List<String>.unmodifiable(logos),
      headerFields: normalizedFields,
      maximumMarks: maximumMarks,
      clearMaximumMarks: clearMaximumMarks,
    );
  }

  void updatePaperSettings({
    double? maximumMarks,
    bool clearMaximumMarks = false,
    bool? includeCoverPage,
    String? headerText,
    String? footerText,
    bool? showPageNumbers,
  }) {
    state = state.copyWith(
      maximumMarks: maximumMarks,
      clearMaximumMarks: clearMaximumMarks,
      includeCoverPage: includeCoverPage,
      headerText: headerText,
      footerText: footerText,
      showPageNumbers: showPageNumbers,
    );
  }

  /// Applies canonical page/layout settings as one undoable paper mutation.
  /// Word Mode, preview, PDF and Word export all read these same values.
  void updatePageLayout(PaperPageLayout layout) {
    state = state.copyWith(pageLayout: layout);
  }

  /// Applies the Word-style Page Setup surface as one undoable mutation.
  void applyPageLayout({
    required PaperPageLayout layout,
    required String headerText,
    required String footerText,
    required bool showPageNumbers,
  }) {
    state = state.copyWith(
      pageLayout: layout,
      headerText: headerText,
      footerText: footerText,
      showPageNumbers: showPageNumbers,
    );
  }

  void updateBranding({String? schoolName, String? logo, int? logoIndex}) {
    if (logoIndex != null) {
      final newLogos = List<String>.from(state.logos);
      while (newLogos.length <= logoIndex) {
        newLogos.add('');
      }
      newLogos[logoIndex] = logo ?? '';
      state = state.copyWith(
        schoolName: schoolName ?? state.schoolName,
        logos: newLogos,
      );
    } else {
      state = state.copyWith(schoolName: schoolName ?? state.schoolName);
    }
  }

  void addHeaderField({
    String label = 'New Field',
    String value = '',
    bool isPlaceholder = false,
  }) {
    final newField = PaperHeaderField(
      id: const Uuid().v4(),
      label: label,
      value: value,
      isPlaceholder: isPlaceholder,
    );
    state = state.copyWith(headerFields: [...state.headerFields, newField]);
  }

  void updateHeaderField(
    String id, {
    String? label,
    String? value,
    bool? isPlaceholder,
  }) {
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

  void updateCustomHeaderValue(String key, String value) {
    final values = Map<String, String>.from(state.customHeaderValues);
    values[key] = value;
    state = state.copyWith(customHeaderValues: values);
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

  void addSectionWithQuestionsFromBank(List<Question> questions) {
    if (questions.isEmpty) return;
    final section = PaperSection(
      id: const Uuid().v4(),
      title: 'Section ${state.sections.length + 1}',
      questions: questions.map(_cloneQuestion).toList(),
    );
    // Section creation and the complete bank batch are one document mutation,
    // so a single Undo restores the previously empty paper.
    state = state.copyWith(sections: [...state.sections, section]);
  }

  void addSectionFromTemplate(PaperSection source) {
    final section = PaperSection(
      id: const Uuid().v4(),
      title: source.title,
      instruction: source.instruction,
      prefix: source.prefix,
      questions: source.questions.map(_cloneQuestion).toList(),
      requiredCount: source.requiredCount,
      showTitle: source.showTitle,
      showTopDivider: source.showTopDivider,
      showBottomDivider: source.showBottomDivider,
      headingAlignment: source.headingAlignment,
      instructionAlignment: source.instructionAlignment,
      answerRuleAlignment: source.answerRuleAlignment,
      showInstructionLabel: source.showInstructionLabel,
      headingBold: source.headingBold,
      headingUppercase: source.headingUppercase,
      headingBoxed: source.headingBoxed,
      headingSize: source.headingSize,
      spacing: source.spacing,
      sectionMarksDisplay: source.sectionMarksDisplay,
      questionMarksPlacement: source.questionMarksPlacement,
      numberingStyle: source.numberingStyle,
      defaultMarks: source.defaultMarks,
      pageBreakBefore: source.pageBreakBefore,
      keepTogether: source.keepTogether,
      answerSpaceLines: source.answerSpaceLines,
      ruledAnswerArea: source.ruledAnswerArea,
      graphAnswerArea: source.graphAnswerArea,
    );
    state = state.copyWith(sections: [...state.sections, section]);
  }

  void replaceSectionObject(PaperSection replacement) {
    state = state.copyWith(
      sections: state.sections
          .map(
            (section) => section.id == replacement.id ? replacement : section,
          )
          .toList(growable: false),
    );
  }

  void updateSection(
    String sectionId, {
    String? title,
    String? instruction,
    String? prefix,
    int? requiredCount,
    bool clearRequiredCount = false,
    bool? showTitle,
    bool? showDivider,
    bool? showTopDivider,
    bool? showBottomDivider,
    PaperTextAlignment? headingAlignment,
    PaperTextAlignment? instructionAlignment,
    PaperTextAlignment? answerRuleAlignment,
    bool? showInstructionLabel,
    bool? headingBold,
    bool? headingUppercase,
    bool? headingBoxed,
    SectionHeadingSize? headingSize,
    SectionSpacing? spacing,
    SectionMarksDisplay? sectionMarksDisplay,
    QuestionMarksPlacement? questionMarksPlacement,
    QuestionNumberStyle? numberingStyle,
    bool clearNumberingStyle = false,
    double? defaultMarks,
    bool clearDefaultMarks = false,
    bool? pageBreakBefore,
    bool? keepTogether,
    int? answerSpaceLines,
    bool? ruledAnswerArea,
    bool? graphAnswerArea,
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
            showDivider:
                showBottomDivider ?? showDivider ?? s.showBottomDivider,
            showTopDivider: showTopDivider ?? s.showTopDivider,
            showBottomDivider:
                showBottomDivider ?? showDivider ?? s.showBottomDivider,
            headingAlignment: headingAlignment ?? s.headingAlignment,
            instructionAlignment:
                instructionAlignment ?? s.instructionAlignment,
            answerRuleAlignment: answerRuleAlignment ?? s.answerRuleAlignment,
            showInstructionLabel:
                showInstructionLabel ?? s.showInstructionLabel,
            headingBold: headingBold ?? s.headingBold,
            headingUppercase: headingUppercase ?? s.headingUppercase,
            headingBoxed: headingBoxed ?? s.headingBoxed,
            headingSize: headingSize ?? s.headingSize,
            spacing: spacing ?? s.spacing,
            sectionMarksDisplay: sectionMarksDisplay ?? s.sectionMarksDisplay,
            questionMarksPlacement:
                questionMarksPlacement ?? s.questionMarksPlacement,
            numberingStyle: numberingStyle ?? s.numberingStyle,
            clearNumberingStyle: clearNumberingStyle,
            defaultMarks: defaultMarks ?? s.defaultMarks,
            clearDefaultMarks: clearDefaultMarks,
            pageBreakBefore: pageBreakBefore ?? s.pageBreakBefore,
            keepTogether: keepTogether ?? s.keepTogether,
            answerSpaceLines: answerSpaceLines ?? s.answerSpaceLines,
            ruledAnswerArea: ruledAnswerArea ?? s.ruledAnswerArea,
            graphAnswerArea: graphAnswerArea ?? s.graphAnswerArea,
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

  void addQuestion(
    String sectionId,
    String text, {
    QuestionType type = QuestionType.descriptive,
    double marks = 1.0,
    List<QuestionOption> options = const [],
    bool isOptional = false,
    int? insertAt,
    List<MathExpression> mathExpressions = const [],
  }) {
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
            mathExpressions: mathExpressions,
          );
          final questions = [...section.questions];
          final index =
              insertAt?.clamp(0, questions.length).toInt() ?? questions.length;
          questions.insert(index, newQuestion);
          return section.copyWith(questions: questions);
        }
        return section;
      }).toList(),
    );
  }

  Question _cloneQuestion(Question source) {
    return _questionCopyService.copyQuestion(source);
  }

  void addQuestionsFromBank(String sectionId, List<Question> questions) {
    if (questions.isEmpty) return;
    final clonedQuestions = questions.map(_cloneQuestion).toList();
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id != sectionId) return section;
        return section.copyWith(
          questions: [...section.questions, ...clonedQuestions],
        );
      }).toList(),
    );
  }

  void duplicateQuestion(String sectionId, String questionId) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id != sectionId) return section;
        final index = section.questions.indexWhere((q) => q.id == questionId);
        if (index == -1) return section;
        final questions = [...section.questions];
        questions.insert(index + 1, _cloneQuestion(questions[index]));
        return section.copyWith(questions: questions);
      }).toList(),
    );
  }

  void duplicateSection(String sectionId) {
    final sourceIndex = state.sections.indexWhere(
      (item) => item.id == sectionId,
    );
    if (sourceIndex == -1) return;
    final source = state.sections[sourceIndex];
    final duplicate = PaperSection(
      id: const Uuid().v4(),
      title: '${source.title} copy',
      instruction: source.instruction,
      prefix: source.prefix,
      questions: source.questions.map(_cloneQuestion).toList(),
      requiredCount: source.requiredCount,
      showTitle: source.showTitle,
      showTopDivider: source.showTopDivider,
      showBottomDivider: source.showBottomDivider,
      headingAlignment: source.headingAlignment,
      instructionAlignment: source.instructionAlignment,
      answerRuleAlignment: source.answerRuleAlignment,
      showInstructionLabel: source.showInstructionLabel,
      headingBold: source.headingBold,
      headingUppercase: source.headingUppercase,
      headingBoxed: source.headingBoxed,
      headingSize: source.headingSize,
      spacing: source.spacing,
      sectionMarksDisplay: source.sectionMarksDisplay,
      questionMarksPlacement: source.questionMarksPlacement,
      numberingStyle: source.numberingStyle,
      defaultMarks: source.defaultMarks,
      pageBreakBefore: source.pageBreakBefore,
      keepTogether: source.keepTogether,
      answerSpaceLines: source.answerSpaceLines,
      ruledAnswerArea: source.ruledAnswerArea,
      graphAnswerArea: source.graphAnswerArea,
    );
    final sections = [...state.sections]..insert(sourceIndex + 1, duplicate);
    state = state.copyWith(sections: sections);
  }

  void updateQuestion(
    String sectionId,
    String questionId, {
    String? text,
    QuestionType? type,
    double? marks,
    String? imageUrl,
    TextAlign? alignment,
    List<QuestionOption>? options,
    bool? isOptional,
    List<MathExpression>? mathExpressions,
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
                  mathExpressions: mathExpressions ?? q.mathExpressions,
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

  void replaceQuestionObject(String sectionId, Question question) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id != sectionId) return section;
        final questions = [...section.questions];
        final index = questions.indexWhere((item) => item.id == question.id);
        if (index < 0) return section;
        questions[index] = question;
        return section.copyWith(questions: questions);
      }).toList(),
    );
  }

  void insertQuestionObject(
    String sectionId,
    Question question, {
    int? insertAt,
  }) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id != sectionId) return section;
        final questions = [...section.questions];
        final index = (insertAt ?? questions.length)
            .clamp(0, questions.length)
            .toInt();
        questions.insert(index, question);
        return section.copyWith(questions: questions);
      }).toList(),
    );
  }

  void bulkUpdateQuestions(String sectionId, List<Question> questions) {
    state = state.copyWith(
      sections: state.sections.map((section) {
        if (section.id == sectionId) {
          return section.copyWith(questions: questions);
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
            questions: section.questions
                .where((q) => q.id != questionId)
                .toList(),
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

  void moveQuestion({
    required String fromSectionId,
    required String toSectionId,
    required String questionId,
    int? toIndex,
  }) {
    final sections = [...state.sections];
    final fromIndex = sections.indexWhere((item) => item.id == fromSectionId);
    final destinationIndex = sections.indexWhere(
      (item) => item.id == toSectionId,
    );
    if (fromIndex == -1 || destinationIndex == -1) return;

    final sourceQuestions = [...sections[fromIndex].questions];
    final questionIndex = sourceQuestions.indexWhere(
      (item) => item.id == questionId,
    );
    if (questionIndex == -1) return;
    final question = sourceQuestions.removeAt(questionIndex);

    if (fromIndex == destinationIndex) {
      final insertion = (toIndex ?? sourceQuestions.length)
          .clamp(0, sourceQuestions.length)
          .toInt();
      sourceQuestions.insert(insertion, question);
      sections[fromIndex] = sections[fromIndex].copyWith(
        questions: sourceQuestions,
      );
    } else {
      final destinationQuestions = [...sections[destinationIndex].questions];
      final insertion = (toIndex ?? destinationQuestions.length)
          .clamp(0, destinationQuestions.length)
          .toInt();
      destinationQuestions.insert(insertion, question);
      sections[fromIndex] = sections[fromIndex].copyWith(
        questions: sourceQuestions,
      );
      sections[destinationIndex] = sections[destinationIndex].copyWith(
        questions: destinationQuestions,
      );
    }
    state = state.copyWith(sections: sections);
  }

  void toggleOmr(bool value) {
    state = state.copyWith(includeOmr: value);
  }

  void updateQuestionNumberStyle(QuestionNumberStyle style) {
    state = state.copyWith(questionNumberStyle: style);
  }

  void updateCustomQuestionNumberLabels(List<String> labels) {
    state = state.copyWith(customQuestionNumberLabels: labels);
  }

  void updateTemplate(String templateId) {
    final resolved = PaperTemplateResolver.resolve(
      templateId,
      ref.read(templateProvider).all,
    );
    state = state.copyWith(templateId: resolved.id);
  }
}
