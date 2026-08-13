import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/editor/services/autosave_coordinator.dart';
import 'package:edusheet/features/paper_composer/application/paper_composer_actions.dart';
import 'package:edusheet/features/paper_composer/presentation/responsive/paper_composer_breakpoints.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_details_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_inspector_panel.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_outline_panel.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_preview_page.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_section_card.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaperComposerScreen extends ConsumerStatefulWidget {
  const PaperComposerScreen({super.key});

  @override
  ConsumerState<PaperComposerScreen> createState() => _PaperComposerScreenState();
}

class _PaperComposerScreenState extends ConsumerState<PaperComposerScreen> {
  final ScrollController _documentScroll = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _questionKeys = {};

  @override
  void dispose() {
    _documentScroll.dispose();
    super.dispose();
  }

  PaperComposerActions get _actions =>
      PaperComposerActions(ref.read(editorStateProvider.notifier));

  GlobalKey _keyForSection(String sectionId) {
    return _sectionKeys.putIfAbsent(sectionId, () => GlobalKey());
  }

  GlobalKey _keyForQuestion(String sectionId, String questionId) {
    final id = '$sectionId::$questionId';
    return _questionKeys.putIfAbsent(id, () => GlobalKey());
  }

  Future<void> _saveNow() async {
    await ref.read(editorStateProvider.notifier).savePaper();
    ref.invalidate(savedPapersProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paper saved'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _addSection() {
    _actions.addSection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_documentScroll.hasClients) return;
      _documentScroll.animateTo(
        _documentScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startFirstQuestion() {
    if (ref.read(editorStateProvider).sections.isNotEmpty) return;
    _actions.addSection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final paper = ref.read(editorStateProvider);
      if (paper.sections.isEmpty) return;
      _openQuestion(paper.sections.first.id);
    });
  }

  Future<void> _openQuestion(
    String sectionId, {
    Question? question,
    QuestionType? initialType,
    int? insertAt,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: MediaQuery.sizeOf(context).width < 700,
        builder: (context) => QuestionComposerPage(
          sectionId: sectionId,
          question: question,
          initialType: initialType,
          insertAt: insertAt,
        ),
      ),
    );
  }

  Future<void> _renameSection(PaperSection section) async {
    final value = await _askText(
      title: 'Rename section',
      label: 'Section title',
      initial: section.title,
      maxLines: 1,
    );
    if (value == null) return;
    _actions.renameSection(section.id, value);
  }

  Future<void> _editSectionInstruction(PaperSection section) async {
    final value = await _askText(
      title: 'Section instruction',
      label: 'Instruction shown to students',
      initial: section.instruction ?? '',
      maxLines: 4,
    );
    if (value == null) return;
    _actions.updateSectionInstruction(section.id, value);
  }

  Future<String?> _askText({
    required String title,
    required String label,
    required String initial,
    required int maxLines,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: maxLines == 1 ? 1 : 3,
            maxLines: maxLines,
            decoration: InputDecoration(labelText: label),
            onSubmitted: maxLines == 1
                ? (value) => Navigator.pop(context, value.trim())
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDelete(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSection(PaperSection section) async {
    final confirmed = await _confirmDelete(
      'Delete section?',
      'This removes ${section.questions.length} question${section.questions.length == 1 ? '' : 's'} from this paper.',
    );
    if (confirmed) _actions.deleteSection(section.id);
  }

  Future<void> _deleteQuestion(PaperSection section, Question question) async {
    final confirmed = await _confirmDelete(
      'Delete question?',
      'This question will be removed from ${section.title}.',
    );
    if (confirmed) _actions.deleteQuestion(section.id, question.id);
  }

  void _scrollToSection(String sectionId) {
    final sectionContext = _keyForSection(sectionId).currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
      return;
    }

    if (!_documentScroll.hasClients) return;
    final paper = ref.read(editorStateProvider);
    final index = paper.sections.indexWhere((section) => section.id == sectionId);
    if (index < 0 || paper.sections.isEmpty) return;
    final fraction = paper.sections.length <= 1
        ? 0.0
        : index / (paper.sections.length - 1);
    _documentScroll.animateTo(
      _documentScroll.position.maxScrollExtent * fraction,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToQuestion(String sectionId, String questionId) {
    _scrollToSection(sectionId);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final questionContext = _keyForQuestion(sectionId, questionId).currentContext;
      if (questionContext == null || !questionContext.mounted) return;
      Scrollable.ensureVisible(
        questionContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
  }

  Future<void> _openPreview(Paper paper) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => PaperPreviewPage(paper: paper)),
    );
  }

  PaperTemplate? _selectedTemplate() {
    final paper = ref.read(editorStateProvider);
    final templates = ref.read(templateProvider).all;
    for (final template in templates) {
      if (template.id == paper.templateId) return template;
    }
    return templates.isEmpty ? null : templates.first;
  }

  Future<void> _exportPdf(Paper paper) async {
    final template = _selectedTemplate();
    if (template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paper style is available.')),
      );
      return;
    }
    try {
      final file = await PdfService.export(paper, template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to ${file.path}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export PDF: $error')),
      );
    }
  }

  Future<void> _exportWord(Paper paper) async {
    final template = _selectedTemplate();
    if (template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paper style is available.')),
      );
      return;
    }
    try {
      final file = await WordExportService.export(paper, template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word file saved to ${file.path}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export Word file: $error')),
      );
    }
  }

  Future<void> _openPdfPreview(Paper paper) async {
    final template = _selectedTemplate();
    if (template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paper style is available.')),
      );
      return;
    }
    try {
      await PdfService.generateAndPreview(paper, template);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open PDF preview: $error')),
      );
    }
  }

  Future<void> _showCompactOutline(Paper paper) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: PaperOutlinePanel(
          paper: paper,
          onAddSection: () {
            Navigator.pop(context);
            _addSection();
          },
          onSelectSection: (sectionId) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToSection(sectionId),
            );
          },
          onSelectQuestion: (sectionId, questionId) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToQuestion(sectionId, questionId),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(editorStateProvider);
    final saveStatus = ref.watch(editorSaveStatusProvider);
    final editor = ref.read(editorStateProvider.notifier);

    _sectionKeys.removeWhere(
      (id, key) => !paper.sections.any((section) => section.id == id),
    );
    final questionIds = <String>{
      for (final section in paper.sections)
        for (final question in section.questions) '${section.id}::${question.id}',
    };
    _questionKeys.removeWhere((id, key) => !questionIds.contains(id));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          _saveNow();
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = PaperComposerBreakpoints.isCompact(width);
            final expanded = PaperComposerBreakpoints.isExpanded(width);

            return Scaffold(
              appBar: _buildAppBar(
                context,
                paper,
                saveStatus,
                editor,
                compact,
                expanded,
              ),
              body: Row(
                children: [
                  if (expanded) ...[
                    SizedBox(
                      width: 260,
                      child: PaperOutlinePanel(
                        paper: paper,
                        onAddSection: _addSection,
                        onSelectSection: _scrollToSection,
                        onSelectQuestion: _scrollToQuestion,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(child: _buildDocument(context, paper, compact)),
                  if (expanded) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 280,
                      child: PaperInspectorPanel(
                        paper: paper,
                        onEditDetails: () => PaperDetailsSheet.show(context, paper),
                        onChooseStyle: () => PaperStyleSheet.show(
                          context,
                          selectedTemplateId: paper.templateId,
                        ),
                        onPreview: () => _openPreview(paper),
                        onPrintPreview: () => _openPdfPreview(paper),
                      ),
                    ),
                  ],
                ],
              ),
              floatingActionButton: compact && paper.sections.isNotEmpty
                  ? FloatingActionButton.extended(
                      onPressed: () => _openQuestion(paper.sections.last.id),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Question'),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Paper paper,
    AutosaveStatus saveStatus,
    EditorState editor,
    bool compact,
    bool expanded,
  ) {
    return AppBar(
      titleSpacing: compact ? 4 : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paper.title.trim().isEmpty ? 'New Paper' : paper.title.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${paper.sections.length} section${paper.sections.length == 1 ? '' : 's'} · ${_questionCount(paper)} questions · ${saveStatus.accessibleLabel}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        if (!compact) ...[
          IconButton(
            tooltip: 'Undo',
            onPressed: editor.canUndo ? editor.undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: editor.canRedo ? editor.redo : null,
            icon: const Icon(Icons.redo_rounded),
          ),
        ],
        if (!expanded)
          IconButton(
            tooltip: 'Paper outline',
            onPressed: () => _showCompactOutline(paper),
            icon: const Icon(Icons.segment_rounded),
          ),
        IconButton(
          tooltip: 'Preview paper',
          onPressed: () => _openPreview(paper),
          icon: const Icon(Icons.visibility_outlined),
        ),
        if (!compact)
          TextButton.icon(
            onPressed: _saveNow,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        PopupMenuButton<_PaperMenuAction>(
          tooltip: 'Paper actions',
          onSelected: (value) {
            switch (value) {
              case _PaperMenuAction.details:
                PaperDetailsSheet.show(context, paper);
                break;
              case _PaperMenuAction.style:
                PaperStyleSheet.show(
                  context,
                  selectedTemplateId: paper.templateId,
                );
                break;
              case _PaperMenuAction.pdfPreview:
                _openPdfPreview(paper);
                break;
              case _PaperMenuAction.exportPdf:
                _exportPdf(paper);
                break;
              case _PaperMenuAction.exportWord:
                _exportWord(paper);
                break;
              case _PaperMenuAction.save:
                _saveNow();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _PaperMenuAction.details,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.tune_rounded),
                title: Text('Paper details'),
              ),
            ),
            PopupMenuItem(
              value: _PaperMenuAction.style,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.style_outlined),
                title: Text('Paper style'),
              ),
            ),
            PopupMenuItem(
              value: _PaperMenuAction.pdfPreview,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('PDF / print preview'),
              ),
            ),
            PopupMenuItem(
              value: _PaperMenuAction.exportPdf,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_rounded),
                title: Text('Export PDF'),
              ),
            ),
            PopupMenuItem(
              value: _PaperMenuAction.exportWord,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined),
                title: Text('Export Word'),
              ),
            ),
            PopupMenuItem(
              value: _PaperMenuAction.save,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.save_outlined),
                title: Text('Save now'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildDocument(BuildContext context, Paper paper, bool compact) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: paper.sections.isEmpty
          ? _buildEmptyPaper(context, paper)
          : ListView.separated(
              controller: _documentScroll,
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 24,
                20,
                compact ? 10 : 24,
                compact ? 110 : 40,
              ),
              itemCount: paper.sections.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == paper.sections.length) {
                  return Center(
                    child: OutlinedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add section'),
                    ),
                  );
                }

                final section = paper.sections[index];
                return Center(
                  key: _keyForSection(section.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: PaperSectionCard(
                      section: section,
                      sectionNumber: index + 1,
                      onAddQuestion: () => _openQuestion(section.id),
                      onEditQuestion: (question) => _openQuestion(
                        section.id,
                        question: question,
                      ),
                      onDuplicateQuestion: (question) =>
                          _actions.duplicateQuestion(section.id, question.id),
                      onDeleteQuestion: (question) =>
                          _deleteQuestion(section, question),
                      questionKeyFor: (question) =>
                          _keyForQuestion(section.id, question.id),
                      onRename: () => _renameSection(section),
                      onEditInstruction: () => _editSectionInstruction(section),
                      onDuplicateSection: () =>
                          _actions.duplicateSection(section.id),
                      onDeleteSection: () => _deleteSection(section),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyPaper(BuildContext context, Paper paper) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.description_outlined, size: 42),
              ),
              const SizedBox(height: 20),
              Text(
                'Create questions, not forms',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a section, write the question, and insert mathematics or geometry only when you need it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _startFirstQuestion,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Write first question'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => PaperDetailsSheet.show(context, paper),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Set paper details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _questionCount(Paper paper) {
    return paper.sections.fold<int>(
      0,
      (sum, section) => sum + section.questions.length,
    );
  }
}

enum _PaperMenuAction { details, style, pdfPreview, exportPdf, exportWord, save }
