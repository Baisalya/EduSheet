import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_image_attachment_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_math_text_field.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_table_editor_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_rich_text_editor.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_page_layout_sheet.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
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
  final PaperSize templatePageSize;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSchoolNameChanged;
  final ValueChanged<String> onInstructionChanged;
  final void Function(String fieldId, String value) onHeaderFieldChanged;
  final void Function(String sectionId, String title) onSectionTitleChanged;
  final void Function(String sectionId, String instruction)
  onSectionInstructionChanged;
  final void Function(String sectionId, Question question) onEditQuestion;
  final void Function(String sectionId, Question question) onReplaceQuestion;
  final void Function(String sectionId, Question block, int? insertAt)
  onInsertWordBlock;
  final void Function(String sectionId, String questionId) onDeleteQuestion;
  final VoidCallback onAddSection;
  final ValueChanged<String> onAddQuestion;
  final Future<void> Function() onImportWord;
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
    required this.templatePageSize,
    required this.onTitleChanged,
    required this.onSchoolNameChanged,
    required this.onInstructionChanged,
    required this.onHeaderFieldChanged,
    required this.onSectionTitleChanged,
    required this.onSectionInstructionChanged,
    required this.onEditQuestion,
    required this.onReplaceQuestion,
    required this.onInsertWordBlock,
    required this.onDeleteQuestion,
    required this.onAddSection,
    required this.onAddQuestion,
    required this.onImportWord,
    required this.onApplyPageLayout,
  });

  @override
  State<WordPaperEditor> createState() => _WordPaperEditorState();
}

class _WordPaperEditorState extends State<WordPaperEditor> {
  late final WordRichTextSession _richTextSession;
  String? _activeSectionId;
  String? _pendingFocusQuestionId;

  @override
  void initState() {
    super.initState();
    _richTextSession = WordRichTextSession();
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
    if (_activeSectionId == sectionId && _pendingFocusQuestionId == null) {
      return;
    }
    setState(() {
      _activeSectionId = sectionId;
      if (_pendingFocusQuestionId == questionId) {
        _pendingFocusQuestionId = null;
      }
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
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    final attachment = await QuestionImageAttachmentSheet.show(context);
    if (attachment == null || !mounted) return;
    final block = WordContentBlockService.image(attachment);
    setState(() {
      _activeSectionId = sectionId;
      _pendingFocusQuestionId = block.id;
    });
    widget.onInsertWordBlock(sectionId, block, _targetInsertIndex(sectionId));
  }

  void _insertQuestion() {
    final sectionId = _targetSectionId;
    if (sectionId == null) return;
    widget.onAddQuestion(sectionId);
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
    widget.onReplaceQuestion(sectionId, question.copyWith(tableData: table));
  }

  Future<void> _editBlockImage(String sectionId, Question question) async {
    final initial = question.attachments.firstOrNull;
    final attachment = await QuestionImageAttachmentSheet.show(
      context,
      initial: initial,
    );
    if (attachment == null || !mounted) return;
    widget.onReplaceQuestion(
      sectionId,
      question.copyWith(attachments: [attachment]),
    );
  }

  ({double width, double height}) _resolvedPagePoints() {
    final explicit = widget.paper.pageLayout.explicitPageSizePoints;
    if (explicit != null) return explicit;

    final portrait = switch (widget.templatePageSize) {
      PaperSize.a4 => (width: 595.28, height: 841.89),
      PaperSize.a5 => (width: 419.53, height: 595.28),
      PaperSize.a3 => (width: 841.89, height: 1190.55),
      PaperSize.letter => (width: 612.0, height: 792.0),
      PaperSize.legal => (width: 612.0, height: 1008.0),
    };
    if (widget.paper.pageLayout.orientation == PaperPageOrientation.landscape) {
      return (width: portrait.height, height: portrait.width);
    }
    return portrait;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pagePoints = _resolvedPagePoints();
    final relativeWidth = 820 * (pagePoints.width / 595.28);
    final preferredPreviewWidth = relativeWidth.clamp(560, 980).toDouble();
    final outerHorizontal = widget.compact ? 20.0 : 48.0;
    final availablePreviewWidth =
        (MediaQuery.sizeOf(context).width - outerHorizontal)
            .clamp(280, 980)
            .toDouble();
    final previewWidth = preferredPreviewWidth < availablePreviewWidth
        ? preferredPreviewWidth
        : availablePreviewWidth;
    final pageScale = previewWidth / pagePoints.width;
    final margins = widget.paper.pageLayout.margins;
    final pagePadding = EdgeInsets.fromLTRB(
      (margins.leftPoints * pageScale).clamp(12, 120).toDouble(),
      (margins.topPoints * pageScale).clamp(14, 140).toDouble(),
      (margins.rightPoints * pageScale).clamp(12, 120).toDouble(),
      (margins.bottomPoints * pageScale).clamp(18, 160).toDouble(),
    );
    final pageMinHeight = (pagePoints.height * pageScale)
        .clamp(520, 1500)
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
            onInsertQuestion: _insertQuestion,
            onInsertPageBreak: _insertPageBreak,
            onImportWord: widget.onImportWord,
            onPageLayout: _openPageLayout,
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('word-paper-editor-scroll'),
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 10 : 24,
                16,
                widget.compact ? 10 : 24,
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
                        color: Colors.white,
                        elevation: 1,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: pageMinHeight),
                          child: Padding(
                            padding: pagePadding,
                            child: Theme(
                              data: ThemeData.light(useMaterial3: true),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  height: widget.paper.pageLayout.lineSpacing,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 16),
                                    if (widget.paper.instruction
                                            .trim()
                                            .isNotEmpty ||
                                        widget.paper.sections.isNotEmpty)
                                      _InlineDocumentField(
                                        key: const Key(
                                          'word-paper-instruction',
                                        ),
                                        initialValue: widget.paper.instruction,
                                        hintText: 'General instructions',
                                        minLines: 1,
                                        maxLines: 6,
                                        textStyle: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                        onChanged: widget.onInstructionChanged,
                                      ),
                                    if (widget.paper.instruction
                                        .trim()
                                        .isNotEmpty)
                                      const Divider(height: 28),
                                    for (
                                      var sectionIndex = 0;
                                      sectionIndex <
                                          widget.paper.sections.length;
                                      sectionIndex++
                                    ) ...[
                                      _buildSection(
                                        widget.paper.sections[sectionIndex],
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
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.center,
                                      child: OutlinedButton.icon(
                                        key: const Key('word-mode-add-section'),
                                        onPressed: widget.onAddSection,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Add section'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
        _InlineDocumentField(
          key: const Key('word-paper-school-name'),
          initialValue: widget.paper.schoolName,
          hintText: 'School / institution name',
          textAlign: TextAlign.center,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          onChanged: widget.onSchoolNameChanged,
        ),
        const SizedBox(height: 6),
        _InlineDocumentField(
          key: const Key('word-paper-title'),
          initialValue: widget.paper.title,
          hintText: 'Question paper title',
          textAlign: TextAlign.center,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          onChanged: widget.onTitleChanged,
        ),
        if (widget.paper.headerFields.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (widget.compact)
            Column(
              children: [
                for (final field in widget.paper.headerFields) ...[
                  _HeaderFieldEditor(
                    field: field,
                    onChanged: (value) =>
                        widget.onHeaderFieldChanged(field.id, value),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final field in widget.paper.headerFields)
                  SizedBox(
                    width: 230,
                    child: _HeaderFieldEditor(
                      field: field,
                      onChanged: (value) =>
                          widget.onHeaderFieldChanged(field.id, value),
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildSection(PaperSection section) {
    final answerRule = PaperStructureService.answerRuleText(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.showTitle || section.title.trim().isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (section.prefix.trim().isNotEmpty) ...[
                Text(
                  section.prefix.trim(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: _InlineDocumentField(
                  key: Key('word-section-title-${section.id}'),
                  initialValue: section.title,
                  hintText: 'Section title',
                  textAlign: TextAlign.center,
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  onChanged: (value) =>
                      widget.onSectionTitleChanged(section.id, value),
                ),
              ),
            ],
          ),
        _InlineDocumentField(
          key: Key('word-section-instruction-${section.id}'),
          initialValue: section.instruction ?? '',
          hintText: 'Section instruction (optional)',
          textAlign: TextAlign.center,
          minLines: 1,
          maxLines: 4,
          textStyle: const TextStyle(fontStyle: FontStyle.italic),
          onChanged: (value) =>
              widget.onSectionInstructionChanged(section.id, value),
        ),
        if (answerRule != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              answerRule,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (section.showDivider) const Divider(height: 24),
        for (var rawIndex = 0; rawIndex < section.questions.length; rawIndex++)
          _WordQuestionBlock(
            key: Key('word-question-${section.questions[rawIndex].id}'),
            paper: widget.paper,
            section: section,
            question: section.questions[rawIndex],
            numberedOrdinal: PaperStructureService.numberedQuestionOrdinal(
              section,
              rawIndex,
            ),
            compact: widget.compact,
            autofocus:
                _pendingFocusQuestionId == section.questions[rawIndex].id,
            session: _richTextSession,
            onActivated: () =>
                _activate(section.id, section.questions[rawIndex].id),
            onChanged: (question) =>
                widget.onReplaceQuestion(section.id, question),
            onOpenFullEditor: () =>
                widget.onEditQuestion(section.id, section.questions[rawIndex]),
            onDelete: () => widget.onDeleteQuestion(
              section.id,
              section.questions[rawIndex].id,
            ),
            onEditTable: () =>
                _editBlockTable(section.id, section.questions[rawIndex]),
            onEditImage: () =>
                _editBlockImage(section.id, section.questions[rawIndex]),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: Key('word-add-question-${section.id}'),
              onPressed: () {
                setState(() => _activeSectionId = section.id);
                widget.onAddQuestion(section.id);
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
}

class _WordEditorRibbon extends StatelessWidget {
  final bool compact;
  final WordRichTextSession session;
  final bool canInsert;
  final VoidCallback onInsertParagraph;
  final Future<void> Function() onInsertTable;
  final Future<void> Function() onInsertImage;
  final VoidCallback onInsertQuestion;
  final VoidCallback onInsertPageBreak;
  final Future<void> Function() onImportWord;
  final Future<void> Function() onPageLayout;

  const _WordEditorRibbon({
    required this.compact,
    required this.session,
    required this.canInsert,
    required this.onInsertParagraph,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertQuestion,
    required this.onInsertPageBreak,
    required this.onImportWord,
    required this.onPageLayout,
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
                      _InsertActions(
                        compact: true,
                        enabled: canInsert,
                        session: session,
                        onInsertParagraph: onInsertParagraph,
                        onInsertTable: onInsertTable,
                        onInsertImage: onInsertImage,
                        onInsertQuestion: onInsertQuestion,
                        onInsertPageBreak: onInsertPageBreak,
                        onImportWord: onImportWord,
                        onPageLayout: onPageLayout,
                      ),
                      if (controller != null) ...[
                        const SizedBox(height: 4),
                        QuillSimpleToolbar(
                          controller: controller,
                          config: _compactToolbarConfig,
                        ),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                            if (controller == null)
                              Text(
                                'Click in a question or paragraph to format it.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            else
                              QuillSimpleToolbar(
                                controller: controller,
                                config: _desktopToolbarConfig,
                              ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 20),
                      _InsertActions(
                        compact: false,
                        enabled: canInsert,
                        session: session,
                        onInsertParagraph: onInsertParagraph,
                        onInsertTable: onInsertTable,
                        onInsertImage: onInsertImage,
                        onInsertQuestion: onInsertQuestion,
                        onInsertPageBreak: onInsertPageBreak,
                        onImportWord: onImportWord,
                        onPageLayout: onPageLayout,
                      ),
                      const VerticalDivider(width: 20),
                      _LayoutActions(
                        canInsertPageBreak: canInsert,
                        onInsertPageBreak: onInsertPageBreak,
                        onPageLayout: onPageLayout,
                      ),
                    ],
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

class _InsertActions extends StatelessWidget {
  final bool compact;
  final bool enabled;
  final WordRichTextSession session;
  final VoidCallback onInsertParagraph;
  final Future<void> Function() onInsertTable;
  final Future<void> Function() onInsertImage;
  final VoidCallback onInsertQuestion;
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
    required this.onInsertQuestion,
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
      onTap: onImportWord,
    );
    final mathAction = _RibbonAction(
      key: const Key('word-ribbon-math'),
      icon: Icons.functions_rounded,
      label: 'Math',
      enabled: session.hasActiveEditor,
      onTap: session.insertMath,
    );
    final geometryAction = _RibbonAction(
      key: const Key('word-ribbon-geometry'),
      icon: Icons.category_outlined,
      label: 'Geometry',
      enabled: session.hasActiveEditor,
      onTap: session.insertGeometry,
    );
    final paragraphAction = _RibbonAction(
      key: const Key('word-ribbon-paragraph'),
      icon: Icons.notes_rounded,
      label: 'Paragraph',
      enabled: enabled,
      onTap: onInsertParagraph,
    );
    final tableAction = _RibbonAction(
      key: const Key('word-ribbon-table'),
      icon: Icons.grid_on_outlined,
      label: 'Table',
      enabled: enabled,
      onTap: onInsertTable,
    );
    final imageAction = _RibbonAction(
      key: const Key('word-ribbon-image'),
      icon: Icons.image_outlined,
      label: 'Image',
      enabled: enabled,
      onTap: onInsertImage,
    );
    final questionAction = _RibbonAction(
      key: const Key('word-ribbon-question'),
      icon: Icons.quiz_outlined,
      label: 'Question',
      enabled: enabled,
      onTap: onInsertQuestion,
    );

    if (compact) {
      // Keep the most common creation actions visible first on narrow phones.
      // Step 10's Import Word action remains available by horizontal scroll,
      // but no longer pushes Paragraph off the initial viewport.
      final compactActions = <Widget>[
        paragraphAction,
        questionAction,
        tableAction,
        imageAction,
        mathAction,
        geometryAction,
        _RibbonAction(
          key: const Key('word-ribbon-page-layout'),
          icon: Icons.description_outlined,
          label: 'Layout',
          enabled: true,
          onTap: onPageLayout,
        ),
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
      paragraphAction,
      tableAction,
      imageAction,
      questionAction,
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

  const _LayoutActions({
    required this.canInsertPageBreak,
    required this.onInsertPageBreak,
    required this.onPageLayout,
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
              key: const Key('word-ribbon-page-layout'),
              icon: Icons.description_outlined,
              label: 'Page setup',
              enabled: true,
              onTap: onPageLayout,
            ),
            _RibbonAction(
              key: const Key('word-ribbon-page-break'),
              icon: Icons.insert_page_break_outlined,
              label: 'Page break',
              enabled: canInsertPageBreak,
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
  final VoidCallback onTap;

  const _RibbonAction({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
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
                    ? 'Word Mode: tap any question/paragraph and type directly. Formatting, Math and Geometry use the active cursor.'
                    : 'Word Mode edits the same paper as Smart Mode. Type and format question text inline, or insert free paragraphs, tables and images; Smart Mode keeps the structure and preserves custom Word content.',
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

class _HeaderFieldEditor extends StatelessWidget {
  final PaperHeaderField field;
  final ValueChanged<String> onChanged;

  const _HeaderFieldEditor({required this.field, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${field.label}:',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _InlineDocumentField(
            key: Key('word-header-field-${field.id}'),
            initialValue: field.value,
            hintText: field.isPlaceholder ? 'Enter ${field.label}' : 'Value',
            onChanged: onChanged,
          ),
        ),
      ],
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
  final VoidCallback onEditImage;

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
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final isWordBlock = question.isWordContentBlock;
    final kind = WordContentBlockService.kindOf(question);
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
                        _ => Icons.notes_rounded,
                      },
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WordRichTextEditor(
                      question: question,
                      compact: compact,
                      autofocus: autofocus,
                      session: session,
                      onActivated: onActivated,
                      onChanged: onChanged,
                    ),
                    if (advanced.hasStimulus) ...[
                      const SizedBox(height: 7),
                      if (advanced.stimulus!.title.trim().isNotEmpty)
                        Text(
                          advanced.stimulus!.title.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      Text(advanced.stimulus!.text.trim()),
                    ],
                    if (question.options.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (var i = 0; i < question.options.length; i++)
                        _InlineOptionEditor(
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
                      Text('Word bank: ${advanced.wordBank.join(' • ')}'),
                    ],
                    if (question.tableData != null) ...[
                      const SizedBox(height: 8),
                      _WordQuestionTable(table: question.tableData!),
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
                        _WordAttachmentPreview(attachment: attachment),
                      if (isWordBlock)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onEditImage,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit image'),
                          ),
                        ),
                    ],
                    if (question.subQuestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (var i = 0; i < question.subQuestions.length; i++)
                        _NestedQuestionLine(
                          label: '(${_alphaLabel(i)})',
                          question: question.subQuestions[i],
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
              if (!isWordBlock) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
  final String label;
  final QuestionOption option;
  final ValueChanged<String> onChanged;

  const _InlineOptionEditor({
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
            child: QuestionMathTextField(
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
  final QuestionTable table;

  const _WordQuestionTable({required this.table});

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
                text: i < table.headers.length ? table.headers[i] : '',
                bold: true,
              ),
          ],
        ),
      );
    }
    for (final row in table.rows) {
      rows.add(
        TableRow(
          children: [
            for (var i = 0; i < columnCount; i++)
              _TableCellText(text: i < row.length ? row[i] : ''),
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
            child: Text(
              table.caption.trim(),
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
  final String text;
  final bool bold;

  const _TableCellText({required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        text,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    );
  }
}

class _WordAttachmentPreview extends StatelessWidget {
  final QuestionAttachment attachment;

  const _WordAttachmentPreview({required this.attachment});

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
                  child: Text(
                    description.isEmpty
                        ? 'Attached image / diagram'
                        : description,
                  ),
                ),
              ],
            ),
          if (canShowImage && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _NestedQuestionLine extends StatelessWidget {
  final String label;
  final Question question;

  const _NestedQuestionLine({required this.label, required this.question});

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
            child: QuestionRichTextPreview(question: question, maxHeight: 220),
          ),
          const SizedBox(width: 8),
          Text(
            '[${PaperStructureService.marksSummary(question.marks)}]',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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

  const _InlineDocumentField({
    super.key,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
    this.textAlign = TextAlign.left,
    this.minLines = 1,
    this.maxLines = 2,
    this.textStyle,
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
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _InlineDocumentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue == _controller.text) return;
    if (!_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
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
