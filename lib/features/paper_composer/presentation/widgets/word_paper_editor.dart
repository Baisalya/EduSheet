import 'dart:io';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_direct_authoring_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/application/word_pagination_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/responsive/paper_page_canvas_metrics.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_page_design_surface.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_image_attachment_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_surface_view.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_table_editor_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_rich_text_editor.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_object_editor_layer.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_shape_picker_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_page_layout_sheet.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Word-style editing surface for the canonical [Paper].
///
/// Step 8 upgrades the Step-7 dual-editor foundation from a document preview
/// into a real rich authoring surface. Smart Mode and Word Mode still edit the
/// same [Paper]; Word Mode adds inline Quill editing, formatting, math,
/// geometry, free paragraphs, tables and images without maintaining a second
/// DOCX-like model.
class WordPaperEditor extends StatefulWidget {
  final Paper paper;
  final bool compact;
  final PaperTemplate template;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSchoolNameChanged;
  final ValueChanged<String> onInstructionChanged;
  final ValueChanged<PaperTextAlignment> onInstructionAlignmentChanged;
  final void Function(String fieldId, String value) onHeaderFieldChanged;
  final void Function(int logoIndex, String path) onLogoChanged;
  final void Function(String sectionId, String title) onSectionTitleChanged;
  final void Function(String sectionId, String instruction)
  onSectionInstructionChanged;
  final ValueChanged<PaperSection> onReplaceSection;
  final void Function(String sectionId, Question question) onEditQuestion;
  final void Function(String sectionId, Question question) onReplaceQuestion;
  final void Function(String sectionId, Question block, int? insertAt)
  onInsertWordBlock;
  final void Function(String sectionId, String questionId) onDeleteQuestion;
  final VoidCallback onAddSection;
  final Future<void> Function(String? sectionId) onAddFromQuestionBank;
  final Future<void> Function() onImportWord;
  final Future<void> Function() onArrangeHeader;
  final void Function(
    PaperPageLayout layout,
    String headerText,
    String footerText,
    bool showPageNumbers,
  )
  onApplyPageLayout;

  const WordPaperEditor({
    super.key,
    required this.paper,
    required this.compact,
    required this.template,
    required this.onTitleChanged,
    required this.onSchoolNameChanged,
    required this.onInstructionChanged,
    required this.onInstructionAlignmentChanged,
    required this.onHeaderFieldChanged,
    required this.onLogoChanged,
    required this.onSectionTitleChanged,
    required this.onSectionInstructionChanged,
    required this.onReplaceSection,
    required this.onEditQuestion,
    required this.onReplaceQuestion,
    required this.onInsertWordBlock,
    required this.onDeleteQuestion,
    required this.onAddSection,
    required this.onAddFromQuestionBank,
    required this.onImportWord,
    required this.onArrangeHeader,
    required this.onApplyPageLayout,
  });

  @override
  State<WordPaperEditor> createState() => _WordPaperEditorState();
}

class _WordPaperEditorState extends State<WordPaperEditor> {
  static const _mathSurfaceService = QuestionMathSurfaceService();
  late final WordRichTextSession _richTextSession;
  String? _activeSectionId;
  String? _pendingFocusQuestionId;
  _WordDocumentFormatTarget _formatTarget = _WordDocumentFormatTarget.none;
  String? _formatSectionId;
  Paper? _paginationPaper;
  WordPaginationPlan? _cachedPaginationPlan;

  @override
  void initState() {
    super.initState();
    _richTextSession = WordRichTextSession();
  }

  void _replaceQuestion(String sectionId, Question question) {
    widget.onReplaceQuestion(
      sectionId,
      _mathSurfaceService.reconcileQuestion(question),
    );
  }

  @override
  void didUpdateWidget(covariant WordPaperEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeSectionId != null &&
        !widget.paper.sections.any(
          (section) => section.id == _activeSectionId,
        )) {
      _activeSectionId = null;
    }
  }

  @override
  void dispose() {
    _richTextSession.dispose();
    super.dispose();
  }

  String? get _targetSectionId {
    if (_activeSectionId != null) return _activeSectionId;
    return widget.paper.sections.firstOrNull?.id;
  }

  WordPaginationPlan get _paginationPlan {
    final cached = _cachedPaginationPlan;
    if (identical(_paginationPaper, widget.paper) && cached != null) {
      return cached;
    }
    final plan = WordPaginationService.planFor(widget.paper);
    _paginationPaper = widget.paper;
    _cachedPaginationPlan = plan;
    return plan;
  }

  int? _targetInsertIndex(String sectionId) {
    final section = widget.paper.sections
        .where((item) => item.id == sectionId)
        .firstOrNull;
    if (section == null) return null;
    final activeId = _richTextSession.activeQuestionId;
    if (activeId == null) return section.questions.length;
    final index = section.questions.indexWhere((item) => item.id == activeId);
    return index < 0 ? section.questions.length : index + 1;
  }

  void _activate(String sectionId, String questionId) {
    if (_activeSectionId == sectionId &&
        _pendingFocusQuestionId == null &&
        _formatTarget == _WordDocumentFormatTarget.none) {
      return;
    }
    setState(() {
      _activeSectionId = sectionId;
      _formatTarget = _WordDocumentFormatTarget.none;
      _formatSectionId = null;
      if (_pendingFocusQuestionId == questionId) {
        _pendingFocusQuestionId = null;
      }
    });
  }

  void _activateDocumentFormat(
    _WordDocumentFormatTarget target, {
    String? sectionId,
  }) {
    if (_formatTarget == target && _formatSectionId == sectionId) return;
    setState(() {
      _formatTarget = target;
      _formatSectionId = sectionId;
      if (sectionId != null) _activeSectionId = sectionId;
    });
  }

  PaperSection? get _formatSection {
    final id = _formatSectionId;
    if (id == null) return null;
    return _sectionById(id);
  }

  PaperSection? _sectionById(String sectionId) {
    return widget.paper.sections
        .where((section) => section.id == sectionId)
        .firstOrNull;
  }

  ({String sectionId, Question question})? get _activeQuestionTarget {
    final questionId = _richTextSession.activeQuestionId;
    if (questionId == null) return null;

    if (_activeSectionId != null) {
      final section = _sectionById(_activeSectionId!);
      final question = section?.questions
          .where((item) => item.id == questionId)
          .firstOrNull;
      if (section != null && question != null && !question.isWordContentBlock) {
        return (sectionId: section.id, question: question);
      }
    }

    for (final section in widget.paper.sections) {
      final question = section.questions
          .where((item) => item.id == questionId)
          .firstOrNull;
      if (question != null && !question.isWordContentBlock) {
        return (sectionId: section.id, question: question);
      }
    }
    return null;
  }

  void _restoreActiveEditorFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _richTextSession.restoreFocus();
    });
  }

  void _insertParagraph() {
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    final block = WordContentBlockService.paragraph();
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = block.id;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _insertTable() async {
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    final table = await QuestionTableEditorSheet.show(context);
    if (table == null || !mounted) return;
    final block = WordContentBlockService.table(table);
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = block.id;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _insertImage() async {
    final activeTarget = _activeQuestionTarget;
    final sectionId = activeTarget?.sectionId ?? _targetSectionId;
    if (sectionId == null) return;

    final attachment = await QuestionImageAttachmentSheet.show(context);
    if (attachment == null || !mounted) return;

    if (activeTarget != null) {
      final updated = WordDirectAuthoringService.appendImage(
        activeTarget.question,
        attachment,
      );
      setState(() {
        _activeSectionId = activeTarget.sectionId;
        _pendingFocusQuestionId = activeTarget.question.id;
      });
      _replaceQuestion(activeTarget.sectionId, updated);
      _restoreActiveEditorFocus();
      return;
    }

    final block = WordContentBlockService.image(attachment);
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = block.id;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _insertShape([WordShapeKind? requestedKind]) async {
    final activeTarget = _activeQuestionTarget;
    final sectionId = activeTarget?.sectionId ?? _targetSectionId;
    if (sectionId == null) return;

    final kind = requestedKind ?? await WordShapePickerSheet.show(context);
    if (kind == null || !mounted) return;

    final shape = WordShapeService.create(kind);
    if (activeTarget != null) {
      _replaceQuestion(
        activeTarget.sectionId,
        WordShapeService.append(activeTarget.question, shape),
      );
      setState(() {
        _activeSectionId = activeTarget.sectionId;
        _pendingFocusQuestionId = activeTarget.question.id;
      });
      _restoreActiveEditorFocus();
      return;
    }

    final block = WordContentBlockService.shape(shape);
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = null;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _insertTextBox() => _insertShape(WordShapeKind.textBox);

  Future<void> _insertFloatingGeometry() async {
    final activeTarget = _activeQuestionTarget;
    final sectionId = activeTarget?.sectionId ?? _targetSectionId;
    if (sectionId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) return;
    GeometryDiagramRegistry.instance.save(diagram);
    final object = WordShapeService.createGeometry(diagram);
    if (activeTarget != null) {
      _replaceQuestion(
        activeTarget.sectionId,
        WordShapeService.append(activeTarget.question, object),
      );
      setState(() {
        _activeSectionId = activeTarget.sectionId;
        _pendingFocusQuestionId = activeTarget.question.id;
      });
      return;
    }
    final block = WordContentBlockService.shape(object);
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = null;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _editFloatingGeometry(
    String sectionId,
    String questionId,
    WordShapeObject object,
  ) async {
    final diagram = object.geometryDiagram;
    if (diagram == null) return;
    final updatedDiagram = await GeometryBuilderScreen.show(
      context,
      initialDiagram: diagram,
    );
    if (updatedDiagram == null || !mounted) return;
    GeometryDiagramRegistry.instance.save(updatedDiagram);
    final section = _sectionById(sectionId);
    final currentQuestion = section?.questions
        .where((item) => item.id == questionId)
        .firstOrNull;
    if (currentQuestion == null) return;
    final currentObject = WordShapeService.shapesOf(currentQuestion)
        .where((item) => item.id == object.id)
        .firstOrNull;
    if (currentObject == null) return;
    _replaceQuestion(
      sectionId,
      WordShapeService.replace(
        currentQuestion,
        currentObject.copyWith(geometryDiagram: updatedDiagram),
      ),
    );
  }

  void _insertQuestion() {
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    final section = _sectionById(sectionId);
    if (section == null) return;
    final question = WordDirectAuthoringService.blankAssessmentQuestion(
      defaultMarks: section.defaultMarks,
    );
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = question.id;
    });
    widget.onInsertWordBlock(
      sectionId,
      question,
      _targetInsertIndex(sectionId),
    );
  }

  void _insertPageBreak() {
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    final block = WordContentBlockService.pageBreak();
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = null;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  Future<void> _openQuestionBank() async {
    await widget.onAddFromQuestionBank(_targetSectionId);
  }

  Future<void> _openPageLayout() async {
    final draft = await WordPageLayoutSheet.show(context, paper: widget.paper);
    if (draft == null || !mounted) return;
    widget.onApplyPageLayout(
      draft.layout,
      draft.headerText,
      draft.footerText,
      draft.showPageNumbers,
    );
  }

  Future<void> _editBlockTable(String sectionId, Question question) async {
    final table = await QuestionTableEditorSheet.show(
      context,
      initial: question.tableData,
    );
    if (table == null || !mounted) return;
    _replaceQuestion(sectionId, question.copyWith(tableData: table));
  }

  Future<void> _editQuestionImage(
    String sectionId,
    Question question,
    QuestionAttachment current,
  ) async {
    final attachment = await QuestionImageAttachmentSheet.show(
      context,
      initial: current,
    );
    if (attachment == null || !mounted) return;
    _replaceQuestion(
      sectionId,
      WordDirectAuthoringService.replaceImage(question, current.id, attachment),
    );
    _restoreActiveEditorFocus();
  }

  void _removeQuestionImage(
    String sectionId,
    Question question,
    QuestionAttachment attachment,
  ) {
    _replaceQuestion(
      sectionId,
      WordDirectAuthoringService.removeImage(question, attachment.id),
    );
  }

  Future<void> _editLogo(int logoIndex) async {
    final existing = logoIndex < widget.paper.logos.length
        ? widget.paper.logos[logoIndex].trim()
        : '';
    final action = await showAdaptiveModalBottomSheet<_LogoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'School logo',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                existing.isEmpty
                    ? 'Choose a PNG or JPG for this header logo slot.'
                    : 'Replace the selected logo or remove it from this slot.',
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(existing.isEmpty ? 'Choose logo' : 'Replace logo'),
                onTap: () => Navigator.pop(context, _LogoAction.choose),
              ),
              if (existing.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Remove logo'),
                  onTap: () => Navigator.pop(context, _LogoAction.remove),
                ),
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Add or manage logo slots'),
                subtitle: const Text(
                  'Place multiple logos anywhere in the header.',
                ),
                onTap: () => Navigator.pop(context, _LogoAction.manageSlots),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _LogoAction.remove) {
      widget.onLogoChanged(logoIndex, '');
      return;
    }
    if (action == _LogoAction.manageSlots) {
      await widget.onArrangeHeader();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty || !mounted) return;
    widget.onLogoChanged(logoIndex, path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageMetrics = PaperPageCanvasMetrics.resolve(
      layout: widget.paper.pageLayout,
      templatePageSize: widget.template.paperSize,
      viewportWidth: MediaQuery.sizeOf(context).width,
      templateTwoColumn: widget.template.paperLayout == PaperLayout.twoColumn,
    );
    final previewWidth = pageMetrics.pageWidth;
    final pagePadding = pageMetrics.pagePadding;
    final pageMinHeight = pageMetrics.pageMinHeight;
    final resolvedColumnCount = pageMetrics.resolvedColumnCount;
    final columnGap = (widget.paper.pageLayout.columnSpacingPoints *
            pageMetrics.pageScale)
        .clamp(6.0, 96.0)
        .toDouble();
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _WordEditorRibbon(
            compact: widget.compact,
            session: _richTextSession,
            canInsert: _targetSectionId != null,
            onInsertParagraph: _insertParagraph,
            onInsertTable: _insertTable,
            onInsertImage: _insertImage,
            onInsertShape: () => _insertShape(),
            onInsertTextBox: _insertTextBox,
            onInsertFloatingGeometry: _insertFloatingGeometry,
            onInsertQuestion: _insertQuestion,
            onAddSection: widget.onAddSection,
            onQuestionBank: _openQuestionBank,
            onInsertPageBreak: _insertPageBreak,
            onImportWord: widget.onImportWord,
            onArrangeHeader: widget.onArrangeHeader,
            onPageLayout: _openPageLayout,
            formatTarget: _formatTarget,
            paperInstructionAlignment: widget.paper.instructionAlignment,
            formatSection: _formatSection,
            onPaperInstructionAlignmentChanged:
                widget.onInstructionAlignmentChanged,
            onReplaceSection: widget.onReplaceSection,
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('word-paper-editor-scroll'),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                widget.compact ? 110 : 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: previewWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WordModeNotice(compact: widget.compact),
                      const SizedBox(height: 12),
                      Material(
                        key: const Key('word-paper-document'),
                        color: Colors.transparent,
                        elevation: 1,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: widget.template.hasBorder
                              ? BorderSide(
                                  color: Color(
                                    widget.template.primaryColor.toInt(),
                                  ),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: pageMinHeight),
                          child: PaperPageDesignSurface(
                            layout: widget.paper.pageLayout,
                            pageScale: pageMetrics.pageScale,
                            pagePadding: pagePadding,
                            resolvedColumnCount: resolvedColumnCount,
                            compact: widget.compact,
                            showEditorChrome: true,
                            child: Padding(
                              padding: pagePadding,
                              child: Theme(
                              data: ThemeData.light(useMaterial3: true),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: widget.template.questionFontSize,
                                  height: widget.paper.pageLayout.lineSpacing,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 10),
                                    if (widget.paper.instruction
                                        .trim()
                                        .isNotEmpty) ...[
                                      const Divider(height: 28),
                                      _InlineDocumentField(
                                        key: const Key(
                                          'word-paper-instruction',
                                        ),
                                        initialValue: widget.paper.instruction,
                                        hintText: 'General instructions',
                                        minLines: 1,
                                        maxLines: 6,
                                        textAlign: widget
                                            .paper
                                            .instructionAlignment
                                            .textAlign,
                                        textStyle: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                        onChanged: widget.onInstructionChanged,
                                        onFocusChanged: (focused) {
                                          if (focused) {
                                            _activateDocumentFormat(
                                              _WordDocumentFormatTarget
                                                  .paperInstruction,
                                            );
                                          }
                                        },
                                      ),
                                      const Divider(height: 30),
                                    ] else if (widget
                                        .paper
                                        .sections
                                        .isNotEmpty) ...[
                                      _InlineDocumentField(
                                        key: const Key(
                                          'word-paper-instruction',
                                        ),
                                        initialValue: '',
                                        hintText: 'Add general instructions',
                                        minLines: 1,
                                        maxLines: 6,
                                        textAlign: widget
                                            .paper
                                            .instructionAlignment
                                            .textAlign,
                                        textStyle: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                        onChanged: widget.onInstructionChanged,
                                        onFocusChanged: (focused) {
                                          if (focused) {
                                            _activateDocumentFormat(
                                              _WordDocumentFormatTarget
                                                  .paperInstruction,
                                            );
                                          }
                                        },
                                      ),
                                      const Divider(height: 30),
                                    ],
                                    for (
                                      var sectionIndex = 0;
                                      sectionIndex <
                                          widget.paper.sections.length;
                                      sectionIndex++
                                    ) ...[
                                      _buildSection(
                                        widget.paper.sections[sectionIndex],
                                        columnCount: resolvedColumnCount,
                                        columnGap: columnGap,
                                      ),
                                      if (sectionIndex !=
                                          widget.paper.sections.length - 1)
                                        SizedBox(
                                          height:
                                              14 +
                                              widget
                                                  .paper
                                                  .pageLayout
                                                  .paragraphSpacingPoints,
                                        ),
                                    ],
                                    if (widget.paper.footerText
                                            .trim()
                                            .isNotEmpty ||
                                        (widget.paper.showPageNumbers &&
                                            widget
                                                    .paper
                                                    .pageLayout
                                                    .pageNumberPosition !=
                                                PaperPageNumberPosition
                                                    .headerRight)) ...[
                                      const SizedBox(height: 18),
                                      const Divider(height: 16),
                                      _WordFooterPreview(paper: widget.paper),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                      if (!widget.compact) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.center,
                          child: OutlinedButton.icon(
                            key: const Key('word-mode-add-section-footer'),
                            onPressed: widget.onAddSection,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add another section'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.paper.headerText.trim().isNotEmpty ||
            (widget.paper.showPageNumbers &&
                widget.paper.pageLayout.pageNumberPosition ==
                    PaperPageNumberPosition.headerRight)) ...[
          Row(
            children: [
              if (widget.paper.headerText.trim().isNotEmpty)
                Expanded(
                  child: Text(
                    widget.paper.headerText.trim(),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                )
              else
                const Spacer(),
              if (widget.paper.showPageNumbers &&
                  widget.paper.pageLayout.pageNumberPosition ==
                      PaperPageNumberPosition.headerRight)
                const Text(
                  'Page 1',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 10),
        ],
        PaperHeaderLayoutCanvas(
          key: const Key('word-wysiwyg-header-canvas'),
          template: widget.template,
          paper: widget.paper,
          editable: true,
          onSchoolNameChanged: widget.onSchoolNameChanged,
          onTitleChanged: widget.onTitleChanged,
          onHeaderFieldChanged: widget.onHeaderFieldChanged,
          onLogoPressed: _editLogo,
        ),
      ],
    );
  }

  Widget _buildSection(
    PaperSection section, {
    required int columnCount,
    required double columnGap,
  }) {
    final answerRule = PaperStructureService.answerRuleText(section);
    final hasManualPageBreak = section.questions.any(
      (question) =>
          question.isWordContentBlock &&
          WordContentBlockService.kindOf(question) ==
              WordContentBlockKind.pageBreak,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: section.spacing.beforePoints),
        if (section.showTopDivider) const Divider(height: 18),
        if (section.showTitle || section.prefix.trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: section.headingBoxed
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : EdgeInsets.zero,
            decoration: section.headingBoxed
                ? BoxDecoration(border: Border.all(color: Colors.black54))
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: switch (section.headingAlignment) {
                      PaperTextAlignment.left => MainAxisAlignment.start,
                      PaperTextAlignment.center => MainAxisAlignment.center,
                      PaperTextAlignment.right => MainAxisAlignment.end,
                    },
                    children: [
                      if (section.prefix.trim().isNotEmpty) ...[
                        Text(
                          section.headingUppercase
                              ? section.prefix.trim().toUpperCase()
                              : section.prefix.trim(),
                          style: TextStyle(
                            fontSize: section.headingSize.previewFontSize,
                            fontWeight: section.headingBold
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (section.showTitle)
                        Flexible(
                          child: _InlineDocumentField(
                            key: Key('word-section-title-${section.id}'),
                            initialValue: section.title,
                            displayTransform: section.headingUppercase
                                ? (value) => value.toUpperCase()
                                : null,
                            hintText: 'Section title',
                            textAlign: section.headingAlignment.textAlign,
                            textStyle: TextStyle(
                              fontSize: section.headingSize.previewFontSize,
                              fontWeight: section.headingBold
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                            ),
                            onChanged: (value) =>
                                widget.onSectionTitleChanged(section.id, value),
                            onFocusChanged: (focused) {
                              if (focused) {
                                _activateDocumentFormat(
                                  _WordDocumentFormatTarget.sectionHeading,
                                  sectionId: section.id,
                                );
                              }
                            },
                          ),
                        ),
                      if (section.sectionMarksDisplay ==
                              SectionMarksDisplay.inline &&
                          section.sectionMarksText != null)
                        Text(
                          ' (${section.sectionMarksText})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
                if (section.sectionMarksDisplay == SectionMarksDisplay.right &&
                    section.sectionMarksText != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    section.sectionMarksText!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        if (section.showInstructionLabel &&
            section.instruction?.trim().isNotEmpty == true)
          Text(
            'Instruction:',
            textAlign: section.instructionAlignment.textAlign,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        _InlineDocumentField(
          key: Key('word-section-instruction-${section.id}'),
          initialValue: section.instruction ?? '',
          hintText: 'Section instruction (optional)',
          textAlign: section.instructionAlignment.textAlign,
          minLines: 1,
          maxLines: 4,
          textStyle: const TextStyle(fontStyle: FontStyle.italic),
          onChanged: (value) =>
              widget.onSectionInstructionChanged(section.id, value),
          onFocusChanged: (focused) {
            if (focused) {
              _activateDocumentFormat(
                _WordDocumentFormatTarget.sectionInstruction,
                sectionId: section.id,
              );
            }
          },
        ),
        if (answerRule != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              answerRule,
              textAlign: section.answerRuleAlignment.textAlign,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (section.showBottomDivider) const Divider(height: 24),
        SizedBox(height: section.spacing.afterPoints),
        if (columnCount > 1 && !hasManualPageBreak)
          for (
            var rawIndex = 0;
            rawIndex < section.questions.length;
            rawIndex += columnCount
          )
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var offset = 0; offset < columnCount; offset++) ...[
                    if (offset > 0) SizedBox(width: columnGap),
                    Expanded(
                      child: rawIndex + offset < section.questions.length
                          ? _buildWordQuestion(section, rawIndex + offset)
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            )
        else
          for (
            var rawIndex = 0;
            rawIndex < section.questions.length;
            rawIndex++
          )
            _buildWordQuestion(section, rawIndex),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: Key('word-add-question-${section.id}'),
              onPressed: () {
                setState(() => _activeSectionId = section.id);
                _insertQuestion();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Question'),
            ),
            TextButton.icon(
              key: Key('word-add-paragraph-${section.id}'),
              onPressed: () {
                setState(() => _activeSectionId = section.id);
                _insertParagraph();
              },
              icon: const Icon(Icons.notes_rounded, size: 18),
              label: const Text('Paragraph'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordQuestion(PaperSection section, int rawIndex) {
    final question = section.questions[rawIndex];
    return _WordQuestionBlock(
      key: Key('word-question-${question.id}'),
      paper: widget.paper,
      section: section,
      question: question,
      numberedOrdinal: PaperStructureService.numberedQuestionOrdinal(
        section,
        rawIndex,
      ),
      compact: widget.compact,
      autofocus: _pendingFocusQuestionId == question.id,
      session: _richTextSession,
      onActivated: () => _activate(section.id, question.id),
      onChanged: (value) => _replaceQuestion(section.id, value),
      onOpenFullEditor: () => widget.onEditQuestion(section.id, question),
      onDelete: () => widget.onDeleteQuestion(section.id, question.id),
      onEditTable: () => _editBlockTable(section.id, question),
      onEditImage: (attachment) =>
          _editQuestionImage(section.id, question, attachment),
      onRemoveImage: (attachment) =>
          _removeQuestionImage(section.id, question, attachment),
      ownerPageIndex: _paginationPlan.pageOfQuestion(question.id),
      onEditGeometry: (object) =>
          _editFloatingGeometry(section.id, question.id, object),
    );
  }
}

enum _LogoAction { choose, remove, manageSlots }

enum _WordDocumentFormatTarget {
  none,
  paperInstruction,
  sectionHeading,
  sectionInstruction,
}

class _WordEditorRibbon extends StatelessWidget {
  final bool compact;
  final WordRichTextSession session;
  final bool canInsert;
  final VoidCallback onInsertParagraph;
  final Future<void> Function() onInsertTable;
  final Future<void> Function() onInsertImage;
  final Future<void> Function() onInsertShape;
  final Future<void> Function() onInsertTextBox;
  final Future<void> Function() onInsertFloatingGeometry;
  final VoidCallback onInsertQuestion;
  final VoidCallback onAddSection;
  final Future<void> Function() onQuestionBank;
  final VoidCallback onInsertPageBreak;
  final Future<void> Function() onImportWord;
  final Future<void> Function() onArrangeHeader;
  final Future<void> Function() onPageLayout;
  final _WordDocumentFormatTarget formatTarget;
  final PaperTextAlignment paperInstructionAlignment;
  final PaperSection? formatSection;
  final ValueChanged<PaperTextAlignment> onPaperInstructionAlignmentChanged;
  final ValueChanged<PaperSection> onReplaceSection;

  const _WordEditorRibbon({
    required this.compact,
    required this.session,
    required this.canInsert,
    required this.onInsertParagraph,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertShape,
    required this.onInsertTextBox,
    required this.onInsertFloatingGeometry,
    required this.onInsertQuestion,
    required this.onAddSection,
    required this.onQuestionBank,
    required this.onInsertPageBreak,
    required this.onImportWord,
    required this.onArrangeHeader,
    required this.onPageLayout,
    required this.formatTarget,
    required this.paperInstructionAlignment,
    required this.formatSection,
    required this.onPaperInstructionAlignmentChanged,
    required this.onReplaceSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: Key(compact ? 'word-mobile-toolbar' : 'word-desktop-ribbon'),
      color: theme.colorScheme.surface,
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          final controller = session.activeController;
          final hasDocumentContext =
              formatTarget != _WordDocumentFormatTarget.none;
          final documentToolbar = _WordDocumentContextToolbar(
            target: formatTarget,
            paperInstructionAlignment: paperInstructionAlignment,
            section: formatSection,
            onPaperInstructionAlignmentChanged:
                onPaperInstructionAlignmentChanged,
            onReplaceSection: onReplaceSection,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 6 : 14,
              compact ? 5 : 8,
              compact ? 6 : 14,
              compact ? 6 : 8,
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        key: const Key('word-mobile-primary-actions'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StructureActions(
                              compact: true,
                              canInsert: canInsert,
                              onAddSection: onAddSection,
                              onInsertQuestion: onInsertQuestion,
                              onQuestionBank: onQuestionBank,
                            ),
                            const SizedBox(width: 4),
                            _RibbonAction(
                              key: const Key('word-ribbon-header-layout'),
                              icon: Icons.dashboard_customize_outlined,
                              label: 'Header',
                              enabled: true,
                              onTap: onArrangeHeader,
                            ),
                            _RibbonAction(
                              key: const Key('word-ribbon-page-layout'),
                              icon: Icons.description_outlined,
                              label: 'Page setup',
                              enabled: true,
                              onTap: onPageLayout,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      _InsertActions(
                        compact: true,
                        enabled: canInsert,
                        session: session,
                        onInsertParagraph: onInsertParagraph,
                        onInsertTable: onInsertTable,
                        onInsertImage: onInsertImage,
                        onInsertShape: onInsertShape,
                        onInsertTextBox: onInsertTextBox,
                        onInsertFloatingGeometry: onInsertFloatingGeometry,
                        onInsertPageBreak: onInsertPageBreak,
                        onImportWord: onImportWord,
                        onPageLayout: onPageLayout,
                      ),
                      if (hasDocumentContext) ...[
                        const SizedBox(height: 4),
                        documentToolbar,
                      ] else if (controller != null) ...[
                        const SizedBox(height: 4),
                        QuillSimpleToolbar(
                          controller: controller,
                          config: _compactToolbarConfig,
                        ),
                      ],
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 1400.0;
                      final hasActiveHomeTools =
                          hasDocumentContext || controller != null;
                      final homeWidth = hasActiveHomeTools
                          ? (availableWidth * 0.30)
                                .clamp(320.0, 500.0)
                                .toDouble()
                          : 190.0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            key: const Key('word-desktop-home-group'),
                            width: homeWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Home',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (hasDocumentContext)
                                  documentToolbar
                                else if (controller == null)
                                  Text(
                                    'Select content to format',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: QuillSimpleToolbar(
                                      controller: controller,
                                      config: _desktopToolbarConfig,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const Key('word-desktop-command-scroll'),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StructureActions(
                                    compact: false,
                                    canInsert: canInsert,
                                    onAddSection: onAddSection,
                                    onInsertQuestion: onInsertQuestion,
                                    onQuestionBank: onQuestionBank,
                                  ),
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    height: 54,
                                    child: VerticalDivider(width: 12),
                                  ),
                                  _InsertActions(
                                    compact: false,
                                    enabled: canInsert,
                                    session: session,
                                    onInsertParagraph: onInsertParagraph,
                                    onInsertTable: onInsertTable,
                                    onInsertImage: onInsertImage,
                                    onInsertShape: onInsertShape,
                                    onInsertTextBox: onInsertTextBox,
                                    onInsertFloatingGeometry: onInsertFloatingGeometry,
                                    onInsertPageBreak: onInsertPageBreak,
                                    onImportWord: onImportWord,
                                    onPageLayout: onPageLayout,
                                  ),
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    height: 54,
                                    child: VerticalDivider(width: 12),
                                  ),
                                  _LayoutActions(
                                    canInsertPageBreak: canInsert,
                                    onInsertPageBreak: onInsertPageBreak,
                                    onPageLayout: onPageLayout,
                                    onArrangeHeader: onArrangeHeader,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  static const _compactToolbarConfig = QuillSimpleToolbarConfig(
    showFontFamily: false,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: false,
    showInlineCode: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showHeaderStyle: false,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: true,
    showLink: false,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showAlignmentButtons: true,
    showSubscript: true,
    showSuperscript: true,
    showSearchButton: false,
    multiRowsDisplay: false,
  );

  static const _desktopToolbarConfig = QuillSimpleToolbarConfig(
    showFontFamily: true,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: true,
    showClearFormat: true,
    showHeaderStyle: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: true,
    showIndent: true,
    showLink: true,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showAlignmentButtons: true,
    showSubscript: true,
    showSuperscript: true,
    showSearchButton: false,
    multiRowsDisplay: false,
  );
}

class _WordDocumentContextToolbar extends StatelessWidget {
  final _WordDocumentFormatTarget target;
  final PaperTextAlignment paperInstructionAlignment;
  final PaperSection? section;
  final ValueChanged<PaperTextAlignment> onPaperInstructionAlignmentChanged;
  final ValueChanged<PaperSection> onReplaceSection;

  const _WordDocumentContextToolbar({
    required this.target,
    required this.paperInstructionAlignment,
    required this.section,
    required this.onPaperInstructionAlignmentChanged,
    required this.onReplaceSection,
  });

  PaperTextAlignment get _alignment {
    switch (target) {
      case _WordDocumentFormatTarget.paperInstruction:
        return paperInstructionAlignment;
      case _WordDocumentFormatTarget.sectionHeading:
        return section?.headingAlignment ?? PaperTextAlignment.center;
      case _WordDocumentFormatTarget.sectionInstruction:
        return section?.instructionAlignment ?? PaperTextAlignment.center;
      case _WordDocumentFormatTarget.none:
        return PaperTextAlignment.left;
    }
  }

  void _setAlignment(PaperTextAlignment value) {
    final current = section;
    switch (target) {
      case _WordDocumentFormatTarget.paperInstruction:
        onPaperInstructionAlignmentChanged(value);
        break;
      case _WordDocumentFormatTarget.sectionHeading:
        if (current != null) {
          onReplaceSection(current.copyWith(headingAlignment: value));
        }
        break;
      case _WordDocumentFormatTarget.sectionInstruction:
        if (current != null) {
          onReplaceSection(current.copyWith(instructionAlignment: value));
        }
        break;
      case _WordDocumentFormatTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = section;
    final isHeading = target == _WordDocumentFormatTarget.sectionHeading;
    return Wrap(
      key: const Key('word-document-context-toolbar'),
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<PaperTextAlignment>(
          key: const Key('word-document-alignment'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: PaperTextAlignment.left,
              icon: Icon(Icons.format_align_left_rounded, size: 18),
              tooltip: 'Align left',
            ),
            ButtonSegment(
              value: PaperTextAlignment.center,
              icon: Icon(Icons.format_align_center_rounded, size: 18),
              tooltip: 'Align center',
            ),
            ButtonSegment(
              value: PaperTextAlignment.right,
              icon: Icon(Icons.format_align_right_rounded, size: 18),
              tooltip: 'Align right',
            ),
          ],
          selected: {_alignment},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) _setAlignment(selection.first);
          },
        ),
        if (isHeading && current != null) ...[
          FilterChip(
            key: const Key('word-section-bold'),
            selected: current.headingBold,
            avatar: const Icon(Icons.format_bold_rounded, size: 18),
            label: const Text('Bold'),
            onSelected: (value) =>
                onReplaceSection(current.copyWith(headingBold: value)),
          ),
          PopupMenuButton<SectionHeadingSize>(
            key: const Key('word-section-heading-size'),
            tooltip: 'Heading size',
            initialValue: current.headingSize,
            onSelected: (value) =>
                onReplaceSection(current.copyWith(headingSize: value)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SectionHeadingSize.small,
                child: Text('Small heading'),
              ),
              PopupMenuItem(
                value: SectionHeadingSize.normal,
                child: Text('Normal heading'),
              ),
              PopupMenuItem(
                value: SectionHeadingSize.large,
                child: Text('Large heading'),
              ),
            ],
            child: Chip(
              avatar: const Icon(Icons.format_size_rounded, size: 18),
              label: Text(switch (current.headingSize) {
                SectionHeadingSize.small => 'Small',
                SectionHeadingSize.normal => 'Normal',
                SectionHeadingSize.large => 'Large',
              }),
            ),
          ),
          FilterChip(
            key: const Key('word-section-top-divider'),
            selected: current.showTopDivider,
            avatar: const Icon(Icons.border_top_rounded, size: 18),
            label: const Text('Top line'),
            onSelected: (value) =>
                onReplaceSection(current.copyWith(showTopDivider: value)),
          ),
          FilterChip(
            key: const Key('word-section-bottom-divider'),
            selected: current.showBottomDivider,
            avatar: const Icon(Icons.border_bottom_rounded, size: 18),
            label: const Text('Bottom line'),
            onSelected: (value) =>
                onReplaceSection(current.copyWith(showBottomDivider: value)),
          ),
        ],
      ],
    );
  }
}

class _StructureActions extends StatelessWidget {
  final bool compact;
  final bool canInsert;
  final VoidCallback onAddSection;
  final VoidCallback onInsertQuestion;
  final Future<void> Function() onQuestionBank;

  const _StructureActions({
    required this.compact,
    required this.canInsert,
    required this.onAddSection,
    required this.onInsertQuestion,
    required this.onQuestionBank,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _RibbonAction(
        key: const Key('word-mode-add-section'),
        icon: Icons.add_box_outlined,
        label: compact ? 'Section' : 'Add section',
        enabled: true,
        emphasized: true,
        dense: !compact,
        onTap: onAddSection,
      ),
      _RibbonAction(
        key: const Key('word-ribbon-question'),
        icon: Icons.quiz_outlined,
        label: 'Question',
        enabled: canInsert,
        dense: !compact,
        onTap: onInsertQuestion,
      ),
      _RibbonAction(
        key: const Key('word-ribbon-question-bank'),
        icon: Icons.inventory_2_outlined,
        label: compact ? 'Bank' : 'Question Bank',
        enabled: true,
        dense: !compact,
        onTap: onQuestionBank,
      ),
    ];

    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: actions);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Structure',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }
}

class _InsertActions extends StatelessWidget {
  final bool compact;
  final bool enabled;
  final WordRichTextSession session;
  final VoidCallback onInsertParagraph;
  final Future<void> Function() onInsertTable;
  final Future<void> Function() onInsertImage;
  final Future<void> Function() onInsertShape;
  final Future<void> Function() onInsertTextBox;
  final Future<void> Function() onInsertFloatingGeometry;
  final VoidCallback onInsertPageBreak;
  final Future<void> Function() onImportWord;
  final Future<void> Function() onPageLayout;

  const _InsertActions({
    required this.compact,
    required this.enabled,
    required this.session,
    required this.onInsertParagraph,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertShape,
    required this.onInsertTextBox,
    required this.onInsertFloatingGeometry,
    required this.onInsertPageBreak,
    required this.onImportWord,
    required this.onPageLayout,
  });

  @override
  Widget build(BuildContext context) {
    final importAction = _RibbonAction(
      key: const Key('word-ribbon-import'),
      icon: Icons.file_open_outlined,
      label: 'Import Word',
      enabled: true,
      dense: !compact,
      onTap: onImportWord,
    );
    final mathAction = _RibbonAction(
      key: const Key('word-ribbon-math'),
      icon: Icons.functions_rounded,
      label: 'Math',
      enabled: session.hasActiveEditor,
      dense: !compact,
      onTap: session.insertMath,
    );
    final geometryAction = _RibbonAction(
      key: const Key('word-ribbon-geometry'),
      icon: Icons.category_outlined,
      label: 'Geometry',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertFloatingGeometry,
    );
    final inlineGeometryAction = _RibbonAction(
      key: const Key('word-ribbon-inline-geometry'),
      icon: Icons.format_align_left_rounded,
      label: 'Inline diagram',
      enabled: session.hasActiveEditor,
      dense: !compact,
      onTap: session.insertGeometry,
    );
    final paragraphAction = _RibbonAction(
      key: const Key('word-ribbon-paragraph'),
      icon: Icons.notes_rounded,
      label: 'Paragraph',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertParagraph,
    );
    final tableAction = _RibbonAction(
      key: const Key('word-ribbon-table'),
      icon: Icons.grid_on_outlined,
      label: 'Table',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertTable,
    );
    final imageAction = _RibbonAction(
      key: const Key('word-ribbon-image'),
      icon: Icons.image_outlined,
      label: 'Picture',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertImage,
    );
    final textBoxAction = _RibbonAction(
      key: const Key('word-ribbon-text-box'),
      icon: Icons.text_fields_rounded,
      label: 'Text box',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertTextBox,
    );
    final shapeAction = _RibbonAction(
      key: const Key('word-ribbon-shape'),
      icon: Icons.crop_square_rounded,
      label: 'Shape',
      enabled: enabled,
      dense: !compact,
      onTap: onInsertShape,
    );
    if (compact) {
      // Keep the most common creation actions visible first on narrow phones.
      // Step 10's Import Word action remains available by horizontal scroll,
      // but no longer pushes Paragraph off the initial viewport.
      final compactActions = <Widget>[
        paragraphAction,
        tableAction,
        imageAction,
        textBoxAction,
        shapeAction,
        mathAction,
        geometryAction,
        inlineGeometryAction,
        _RibbonAction(
          key: const Key('word-ribbon-page-break'),
          icon: Icons.insert_page_break_outlined,
          label: 'Page break',
          enabled: enabled,
          onTap: onInsertPageBreak,
        ),
        importAction,
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: compactActions),
      );
    }

    final actions = <Widget>[
      importAction,
      mathAction,
      geometryAction,
      inlineGeometryAction,
      paragraphAction,
      tableAction,
      imageAction,
      textBoxAction,
      shapeAction,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insert',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }
}

class _LayoutActions extends StatelessWidget {
  final bool canInsertPageBreak;
  final VoidCallback onInsertPageBreak;
  final Future<void> Function() onPageLayout;
  final Future<void> Function() onArrangeHeader;

  const _LayoutActions({
    required this.canInsertPageBreak,
    required this.onInsertPageBreak,
    required this.onPageLayout,
    required this.onArrangeHeader,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Layout',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RibbonAction(
              key: const Key('word-ribbon-header-layout'),
              icon: Icons.dashboard_customize_outlined,
              label: 'Header',
              enabled: true,
              dense: true,
              onTap: onArrangeHeader,
            ),
            _RibbonAction(
              key: const Key('word-ribbon-page-layout'),
              icon: Icons.description_outlined,
              label: 'Page setup',
              enabled: true,
              dense: true,
              onTap: onPageLayout,
            ),
            _RibbonAction(
              key: const Key('word-ribbon-page-break'),
              icon: Icons.insert_page_break_outlined,
              label: 'Page break',
              enabled: canInsertPageBreak,
              dense: true,
              onTap: onInsertPageBreak,
            ),
          ],
        ),
      ],
    );
  }
}

class _RibbonAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool emphasized;
  final bool dense;
  final VoidCallback onTap;

  const _RibbonAction({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    this.emphasized = false,
    this.dense = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dense) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final foreground = enabled
          ? (emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)
          : scheme.onSurface.withValues(alpha: 0.38);
      final background = emphasized
          ? scheme.primaryContainer.withValues(alpha: enabled ? 0.9 : 0.45)
          : Colors.transparent;

      // Desktop uses compact Office-style tiles instead of wide horizontal
      // text buttons. This keeps Structure + Insert + Layout visible together
      // on a normal full-screen window while the outer command strip remains
      // horizontally scrollable for genuinely narrow/free-form windows.
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Tooltip(
          message: label,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 82,
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 17, color: foreground),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontSize: 10.5,
                          fontWeight: emphasized
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final button = emphasized
        ? FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
    return Padding(padding: const EdgeInsets.only(right: 3), child: button);
  }
}

class _WordFooterPreview extends StatelessWidget {
  final Paper paper;

  const _WordFooterPreview({required this.paper});

  @override
  Widget build(BuildContext context) {
    final position = paper.pageLayout.pageNumberPosition;
    final showFooterPageNumber =
        paper.showPageNumbers &&
        position != PaperPageNumberPosition.headerRight;
    final parts = <String>[
      if (paper.footerText.trim().isNotEmpty) paper.footerText.trim(),
      if (showFooterPageNumber) 'Page 1',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  •  '),
      textAlign: position == PaperPageNumberPosition.footerRight
          ? TextAlign.right
          : TextAlign.center,
      style: const TextStyle(fontSize: 10, color: Colors.black54),
    );
  }
}

class _WordModeNotice extends StatelessWidget {
  final bool compact;

  const _WordModeNotice({required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.article_outlined,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact
                    ? 'Word Mode: type directly on the page. Tap a section title or instruction for alignment and line controls; Math, Geometry and Pictures use the active question; logo slots can be replaced, removed or multiplied from Arrange header.'
                    : 'WYSIWYG Word Mode edits the canonical paper directly. Click a section title or instruction to format alignment, heading size and divider lines from Home. Math, Geometry and Pictures use the active question. Header logo slots can be replaced, removed or added from Arrange header.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordQuestionBlock extends StatelessWidget {
  final Paper paper;
  final PaperSection section;
  final Question question;
  final int numberedOrdinal;
  final bool compact;
  final bool autofocus;
  final WordRichTextSession session;
  final VoidCallback onActivated;
  final ValueChanged<Question> onChanged;
  final VoidCallback onOpenFullEditor;
  final VoidCallback onDelete;
  final VoidCallback onEditTable;
  final ValueChanged<QuestionAttachment> onEditImage;
  final ValueChanged<QuestionAttachment> onRemoveImage;
  final int ownerPageIndex;
  final Future<void> Function(WordShapeObject object) onEditGeometry;

  const _WordQuestionBlock({
    super.key,
    required this.paper,
    required this.section,
    required this.question,
    required this.numberedOrdinal,
    required this.compact,
    required this.autofocus,
    required this.session,
    required this.onActivated,
    required this.onChanged,
    required this.onOpenFullEditor,
    required this.onDelete,
    required this.onEditTable,
    required this.onEditImage,
    required this.onRemoveImage,
    required this.ownerPageIndex,
    required this.onEditGeometry,
  });

  static String _alphaLabel(int index) {
    var value = index + 1;
    final codes = <int>[];
    while (value > 0) {
      value -= 1;
      codes.add(97 + value % 26);
      value ~/= 26;
    }
    return String.fromCharCodes(codes.reversed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = theme.platform;
    final desktopInteractions =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final isWordBlock = question.isWordContentBlock;
    final kind = WordContentBlockService.kindOf(question);
    final shapes = WordShapeService.shapesOf(question);
    if (isWordBlock && kind == WordContentBlockKind.pageBreak) {
      return _WordPageBreakMarker(onDelete: onDelete);
    }
    final label = isWordBlock
        ? ''
        : PaperStructureService.questionLabel(numberedOrdinal, paper, section);

    return Padding(
      padding: EdgeInsets.only(
        bottom: (6 + paper.pageLayout.paragraphSpacingPoints)
            .clamp(8, 32)
            .toDouble(),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isWordBlock
              ? theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.38)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isWordBlock)
                SizedBox(
                  width: 34,
                  child: Text(
                    '$label.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 7, top: 4),
                  child: Tooltip(
                    message: 'Free Word content',
                    child: Icon(
                      switch (kind) {
                        WordContentBlockKind.table => Icons.grid_on_outlined,
                        WordContentBlockKind.image => Icons.image_outlined,
                        WordContentBlockKind.shape => Icons.crop_square_rounded,
                        _ => Icons.notes_rounded,
                      },
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(
                child: WordObjectEditorLayer(
                  shapes: shapes,
                  compact: compact,
                  desktopInteractions: desktopInteractions,
                  onShapesChanged: (updatedShapes) => onChanged(
                    WordShapeService.replaceAll(question, updatedShapes),
                  ),
                  ownerPageIndex: ownerPageIndex,
                  onEditGeometry: onEditGeometry,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (question.instructions.trim().isNotEmpty) ...[
                      QuestionMathSurfaceView(
                        question: question,
                        surfaceKey: QuestionMathSurfaceKey.instructions,
                        fallbackText: question.instructions.trim(),
                        textAlign: question.instructionAlignment.textAlign,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: WordRichTextEditor(
                            question: question,
                            compact: compact,
                            autofocus: autofocus,
                            session: session,
                            onActivated: onActivated,
                            onChanged: onChanged,
                          ),
                        ),
                        if (!isWordBlock &&
                            section.questionMarksPlacement ==
                                QuestionMarksPlacement.inline) ...[
                          const SizedBox(width: 6),
                          _InlineMarksEditor(
                            marks: question.marks,
                            onChanged: (marks) =>
                                onChanged(question.copyWith(marks: marks)),
                          ),
                        ],
                      ],
                    ),
                    if (advanced.hasStimulus) ...[
                      const SizedBox(height: 7),
                      if (advanced.stimulus!.title.trim().isNotEmpty)
                        QuestionMathSurfaceView(
                          question: question,
                          surfaceKey: QuestionMathSurfaceKey.stimulusTitle,
                          fallbackText: advanced.stimulus!.title.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      QuestionMathSurfaceView(
                        question: question,
                        surfaceKey: QuestionMathSurfaceKey.stimulusText,
                        fallbackText: advanced.stimulus!.text.trim(),
                        style: TextStyle(
                          fontStyle:
                              advanced.stimulus!.kind ==
                                  QuestionStimulusKind.poem
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                    if (question.options.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (var i = 0; i < question.options.length; i++)
                        _InlineOptionEditor(
                          question: question,
                          label: '${String.fromCharCode(65 + i)})',
                          option: question.options[i],
                          onChanged: (value) {
                            final options = [...question.options];
                            options[i] = options[i].copyWith(text: value);
                            onChanged(question.copyWith(options: options));
                          },
                        ),
                    ],
                    if (advanced.hasWordBank) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Word bank:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          for (final entry in advanced.wordBank.asMap().entries)
                            QuestionMathSurfaceView(
                              question: question,
                              surfaceKey: QuestionMathSurfaceKey.wordBank(
                                entry.key,
                              ),
                              fallbackText: entry.value,
                            ),
                        ],
                      ),
                    ],
                    if (question.tableData != null) ...[
                      const SizedBox(height: 8),
                      _WordQuestionTable(
                        question: question,
                        table: question.tableData!,
                      ),
                      if (isWordBlock)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onEditTable,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit table'),
                          ),
                        ),
                    ],
                    if (question.attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final attachment in question.attachments)
                        _WordAttachmentPreview(
                          question: question,
                          attachment: attachment,
                          onEdit: () => onEditImage(attachment),
                          onRemove: () => onRemoveImage(attachment),
                        ),
                    ],
                    if (question.subQuestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (var i = 0; i < question.subQuestions.length; i++)
                        _NestedQuestionLine(
                          label: '(${_alphaLabel(i)})',
                          question: question.subQuestions[i],
                          section: section,
                        ),
                    ],
                    if (question.internalChoices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (
                        var i = 0;
                        i < question.internalChoices.length;
                        i++
                      ) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              'OR',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        _NestedQuestionLine(
                          label: '',
                          question: question.internalChoices[i],
                          section: section,
                        ),
                      ],
                    ],
                    if (!isWordBlock)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onOpenFullEditor,
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text(
                            'Options, marks & advanced question settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isWordBlock) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (section.questionMarksPlacement ==
                        QuestionMarksPlacement.rightEdge)
                      _InlineMarksEditor(
                        marks: question.marks,
                        onChanged: (marks) =>
                            onChanged(question.copyWith(marks: marks)),
                      ),
                    PopupMenuButton<String>(
                      key: Key('word-question-menu-${question.id}'),
                      tooltip: 'Question actions',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onSelected: (value) {
                        switch (value) {
                          case 'settings':
                            onOpenFullEditor();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'settings',
                          child: Text('Question settings'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete question'),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else
                IconButton(
                  tooltip: 'Delete free content',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordPageBreakMarker extends StatelessWidget {
  final VoidCallback onDelete;

  const _WordPageBreakMarker({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.insert_page_break_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Page break',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Remove page break',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineOptionEditor extends StatefulWidget {
  final Question question;
  final String label;
  final QuestionOption option;
  final ValueChanged<String> onChanged;

  const _InlineOptionEditor({
    required this.question,
    required this.label,
    required this.option,
    required this.onChanged,
  });

  @override
  State<_InlineOptionEditor> createState() => _InlineOptionEditorState();
}

class _InlineOptionEditorState extends State<_InlineOptionEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.option.text);
  }

  @override
  void didUpdateWidget(covariant _InlineOptionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.option.text) return;
    _controller.value = TextEditingValue(
      text: widget.option.text,
      selection: TextSelection.collapsed(offset: widget.option.text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionMathTextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 3),
                  ),
                  onChanged: widget.onChanged,
                ),
                QuestionMathSurfaceView(
                  question: widget.question,
                  surfaceKey: QuestionMathSurfaceKey.option(widget.option.id),
                  fallbackText: widget.option.text,
                  showFallback: false,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMarksEditor extends StatefulWidget {
  final double marks;
  final ValueChanged<double> onChanged;

  const _InlineMarksEditor({required this.marks, required this.onChanged});

  @override
  State<_InlineMarksEditor> createState() => _InlineMarksEditorState();
}

class _InlineMarksEditorState extends State<_InlineMarksEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.marks));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _InlineMarksEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus || oldWidget.marks == widget.marks) return;
    _controller.text = _format(widget.marks);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Row(
        children: [
          const Text('[', style: TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: TextField(
              key: const Key('word-inline-marks'),
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value.trim());
                if (parsed == null || !parsed.isFinite || parsed <= 0) return;
                widget.onChanged(parsed);
              },
            ),
          ),
          const Text(']', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String _format(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _WordQuestionTable extends StatelessWidget {
  final Question question;
  final QuestionTable table;

  const _WordQuestionTable({required this.question, required this.table});

  @override
  Widget build(BuildContext context) {
    final columnCount = [
      table.headers.length,
      ...table.rows.map((row) => row.length),
    ].fold<int>(0, (max, value) => value > max ? value : max);
    if (columnCount == 0) return const SizedBox.shrink();

    final rows = <TableRow>[];
    if (table.headers.isNotEmpty) {
      rows.add(
        TableRow(
          children: [
            for (var i = 0; i < columnCount; i++)
              _TableCellText(
                question: question,
                surfaceKey: QuestionMathSurfaceKey.tableHeader(i),
                text: i < table.headers.length ? table.headers[i] : '',
                bold: true,
              ),
          ],
        ),
      );
    }
    for (final rowEntry in table.rows.asMap().entries) {
      final row = rowEntry.value;
      rows.add(
        TableRow(
          children: [
            for (var i = 0; i < columnCount; i++)
              _TableCellText(
                question: question,
                surfaceKey: QuestionMathSurfaceKey.tableCell(rowEntry.key, i),
                text: i < row.length ? row[i] : '',
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (table.caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: QuestionMathSurfaceView(
              question: question,
              surfaceKey: QuestionMathSurfaceKey.tableCaption,
              fallbackText: table.caption.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Table(
          border: TableBorder.all(color: Colors.black38, width: 0.7),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        ),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  final Question question;
  final String surfaceKey;
  final String text;
  final bool bold;

  const _TableCellText({
    required this.question,
    required this.surfaceKey,
    required this.text,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: QuestionMathSurfaceView(
        question: question,
        surfaceKey: surfaceKey,
        fallbackText: text,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }
}

class _WordAttachmentPreview extends StatelessWidget {
  final Question question;
  final QuestionAttachment attachment;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _WordAttachmentPreview({
    required this.question,
    required this.attachment,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final path = attachment.path.trim();
    final file = path.isEmpty ? null : File(path);
    final canShowImage =
        attachment.kind != QuestionAttachmentKind.file &&
        file != null &&
        file.existsSync();
    final description = attachment.caption.trim().isNotEmpty
        ? attachment.caption.trim()
        : attachment.alternativeText.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canShowImage)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.file(file, fit: BoxFit.contain),
            )
          else
            Row(
              children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: description.isEmpty
                      ? const Text('Attached image / diagram')
                      : QuestionMathSurfaceView(
                          question: question,
                          surfaceKey: QuestionMathSurfaceKey.attachmentCaption(
                            attachment.id,
                          ),
                          fallbackText: description,
                        ),
                ),
              ],
            ),
          if (canShowImage && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: QuestionMathSurfaceView(
                question: question,
                surfaceKey: QuestionMathSurfaceKey.attachmentCaption(
                  attachment.id,
                ),
                fallbackText: description,
                textAlign: TextAlign.center,
                alignment: WrapAlignment.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (attachment.kind == QuestionAttachmentKind.image &&
              (onEdit != null || onRemove != null))
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      key: ValueKey('word-image-replace-${attachment.id}'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Replace'),
                    ),
                  if (onRemove != null)
                    TextButton.icon(
                      key: ValueKey('word-image-remove-${attachment.id}'),
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WordReadOnlyQuestionSurfaces extends StatelessWidget {
  final Question question;

  const _WordReadOnlyQuestionSurfaces({required this.question});

  @override
  Widget build(BuildContext context) {
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final hasContent =
        advanced.hasStimulus ||
        question.options.isNotEmpty ||
        advanced.hasWordBank ||
        question.tableData != null ||
        question.attachments.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (advanced.hasStimulus) ...[
            if (advanced.stimulus!.title.trim().isNotEmpty)
              QuestionMathSurfaceView(
                question: question,
                surfaceKey: QuestionMathSurfaceKey.stimulusTitle,
                fallbackText: advanced.stimulus!.title.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            QuestionMathSurfaceView(
              question: question,
              surfaceKey: QuestionMathSurfaceKey.stimulusText,
              fallbackText: advanced.stimulus!.text.trim(),
              style: TextStyle(
                fontStyle: advanced.stimulus!.kind == QuestionStimulusKind.poem
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 5),
            for (final entry in question.options.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${String.fromCharCode(65 + entry.key)}) '),
                    QuestionMathSurfaceView(
                      question: question,
                      surfaceKey: QuestionMathSurfaceKey.option(entry.value.id),
                      fallbackText: entry.value.text,
                    ),
                  ],
                ),
              ),
          ],
          if (advanced.hasWordBank) ...[
            const SizedBox(height: 5),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Word bank:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final entry in advanced.wordBank.asMap().entries)
                  QuestionMathSurfaceView(
                    question: question,
                    surfaceKey: QuestionMathSurfaceKey.wordBank(entry.key),
                    fallbackText: entry.value,
                  ),
              ],
            ),
          ],
          if (question.tableData != null) ...[
            const SizedBox(height: 6),
            _WordQuestionTable(question: question, table: question.tableData!),
          ],
          if (question.attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final attachment in question.attachments)
              _WordAttachmentPreview(
                question: question,
                attachment: attachment,
              ),
          ],
        ],
      ),
    );
  }
}

class _NestedQuestionLine extends StatelessWidget {
  final String label;
  final Question question;
  final PaperSection section;

  const _NestedQuestionLine({
    required this.label,
    required this.question,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 34,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (question.instructions.trim().isNotEmpty) ...[
                  QuestionMathSurfaceView(
                    question: question,
                    surfaceKey: QuestionMathSurfaceKey.instructions,
                    fallbackText: question.instructions.trim(),
                    textAlign: question.instructionAlignment.textAlign,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: QuestionRichTextPreview(
                        question: question,
                        maxHeight: 220,
                      ),
                    ),
                    if (section.questionMarksPlacement ==
                        QuestionMarksPlacement.inline) ...[
                      const SizedBox(width: 5),
                      Text(
                        '[${PaperStructureService.marksSummary(question.marks)}]',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                _WordReadOnlyQuestionSurfaces(question: question),
              ],
            ),
          ),
          if (section.questionMarksPlacement ==
              QuestionMarksPlacement.rightEdge) ...[
            const SizedBox(width: 8),
            Text(
              '[${PaperStructureService.marksSummary(question.marks)}]',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineDocumentField extends StatefulWidget {
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextAlign textAlign;
  final int minLines;
  final int maxLines;
  final TextStyle? textStyle;
  final String Function(String value)? displayTransform;
  final ValueChanged<bool>? onFocusChanged;

  const _InlineDocumentField({
    super.key,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
    this.textAlign = TextAlign.left,
    this.minLines = 1,
    this.maxLines = 2,
    this.textStyle,
    this.displayTransform,
    this.onFocusChanged,
  });

  @override
  State<_InlineDocumentField> createState() => _InlineDocumentFieldState();
}

class _InlineDocumentFieldState extends State<_InlineDocumentField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _displayValue(widget.initialValue),
    );
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _InlineDocumentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus) {
      final displayValue = _displayValue(widget.initialValue);
      if (displayValue == _controller.text) return;
      _controller.value = TextEditingValue(
        text: displayValue,
        selection: TextSelection.collapsed(offset: displayValue.length),
      );
    }
  }

  String _displayValue(String value) {
    return widget.displayTransform?.call(value) ?? value;
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    final value = _focusNode.hasFocus
        ? widget.initialValue
        : _displayValue(widget.initialValue);
    if (_controller.text == value) return;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      style: widget.textStyle,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.45),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      ),
      onChanged: widget.onChanged,
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
