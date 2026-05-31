import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/pdf/presentation/widgets/template_header_preview.dart';
import 'package:flutter/material.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/geometry_builder/painters/geometry_painter.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/pdf/presentation/widgets/template_selector.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/features/editor/services/section_word_parser.dart';
import '../widgets/question_editor_sheet.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';

class CreatePaperScreen extends ConsumerStatefulWidget {
  const CreatePaperScreen({super.key});

  @override
  ConsumerState<CreatePaperScreen> createState() => _CreatePaperScreenState();
}

class _CreatePaperScreenState extends ConsumerState<CreatePaperScreen> {
  bool _showPreview = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paper = ref.read(editorStateProvider);
      _titleController.text = paper.title;
      _instructionController.text = paper.instruction;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _showSaveAsSheet(Paper paper) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SaveAsSheet(
        initialFileNameBase: ExportFileService.cleanFileNameBase(paper.title),
      ),
    );
  }

  Future<void> _savePaperShortcut() async {
    await ref.read(editorStateProvider.notifier).savePaper();
    ref.invalidate(savedPapersProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paper saved'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(editorStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _savePaperShortcut(),
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paper.title.isEmpty ? 'New Paper' : paper.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (!_showPreview)
                Text(
                  _currentPage == 0 ? 'Paper Setup' : 'Section $_currentPage',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_showPreview ? Icons.edit : Icons.remove_red_eye),
              onPressed: () => setState(() => _showPreview = !_showPreview),
              tooltip: _showPreview ? 'Edit Mode' : 'Preview Mode',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showSaveAsSheet(paper),
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        body: _showPreview ? _buildPreview(paper) : _buildEditor(paper),
        bottomNavigationBar: !_showPreview
            ? _buildBottomNavigation(paper)
            : null,
        floatingActionButton: !_showPreview && _currentPage == 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  ref.read(editorStateProvider.notifier).addSection();
                  final targetPage =
                      paper.sections.length +
                      1; // Slide 0 is setup, sections start at 1
                  _goToPage(targetPage);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Section'),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomNavigation(Paper paper) {
    final totalPages = paper.sections.length + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withAlpha(13)),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _currentPage > 0
                  ? () => _goToPage(_currentPage - 1)
                  : null,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
            Row(
              children: List.generate(totalPages, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.blue
                        : Colors.grey.withAlpha(76),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            IconButton(
              onPressed: _currentPage < totalPages - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(Paper paper) {
    return PageView(
      controller: _pageController,
      onPageChanged: (page) => setState(() => _currentPage = page),
      children: [
        _buildSetupSlide(paper),
        ...paper.sections.map((section) => _buildSectionSlide(section)),
      ],
    );
  }

  double _editorBottomPadding({double base = 100}) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    if (keyboardState.isVisible && keyboardState.type == KeyboardType.math) {
      return keyboardState.height + base;
    }

    return base;
  }

  Widget _buildSetupSlide(Paper paper) {
    final templates = ref.watch(templateProvider).all;
    final template = templates.firstWhere(
      (t) => t.id == paper.templateId,
      orElse: () => templates.first,
    );
    final layout = template.effectiveLayout;
    final bool showSchoolName = layout.elements.any(
      (e) => e.type == ElementType.schoolName,
    );
    final List<TemplateElement> logoElements = layout.elements
        .where((e) => e.type == ElementType.logo)
        .toList();
    final List<TemplateElement> staticTextElements = layout.elements
        .where((e) => e.type == ElementType.staticText)
        .toList();

    final bool showBranding = showSchoolName || logoElements.isNotEmpty;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 20, 20, _editorBottomPadding()),
      children: [
        if (showBranding)
          _EditorCard(
            title: 'Branding',
            icon: Icons.business,
            color: Colors.blue,
            child: _buildBrandingEditor(paper, showSchoolName, logoElements),
          ),
        const SizedBox(height: 20),
        _EditorCard(
          title: 'General Info',
          icon: Icons.info_outline,
          color: Colors.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MathKeyboardField(
                controller: _titleController,
                builder: (context, fieldFocusNode, isMathActive) => TextField(
                  controller: _titleController,
                  focusNode: fieldFocusNode,
                  keyboardType: isMathActive
                      ? TextInputType.none
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Exam Title (e.g. Mid-Term 2024)',
                    hintText: 'Enter exam title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) =>
                      ref.read(editorStateProvider.notifier).updateTitle(val),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instructionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Paper Instructions',
                  hintText: 'Example: All questions are compulsory.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) => ref
                    .read(editorStateProvider.notifier)
                    .updateInstruction(val),
              ),
              const SizedBox(height: 20),
              _buildHeaderFieldsSection(paper, template),
            ],
          ),
        ),
        if (staticTextElements.isNotEmpty) ...[
          const SizedBox(height: 20),
          _EditorCard(
            title: 'Header Text',
            icon: Icons.text_fields_rounded,
            color: Colors.teal,
            child: _buildCustomHeaderTextEditor(paper, staticTextElements),
          ),
        ],
        const SizedBox(height: 20),
        _EditorCard(
          title: 'Template & Layout',
          icon: Icons.style,
          color: Colors.orange,
          child: TemplateSelector(
            selectedTemplateId: paper.templateId,
            onTemplateSelected: (id) =>
                ref.read(editorStateProvider.notifier).updateTemplate(id),
          ),
        ),
        const SizedBox(height: 20),
        _EditorCard(
          title: 'Header Preview',
          icon: Icons.preview_rounded,
          color: Colors.indigo,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TemplateHeaderPreview(paper: paper, template: template),
          ),
        ),
        const SizedBox(height: 20),
        _EditorCard(
          title: 'Extra Options',
          icon: Icons.more_horiz,
          color: Colors.blueGrey,
          child: Column(
            children: [
              _QuestionNumberingSelector(paper: paper),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text(
                  'Include OMR Sheet',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Add a full OMR sheet at the end of the PDF',
                ),
                value: paper.includeOmr,
                onChanged: (val) =>
                    ref.read(editorStateProvider.notifier).toggleOmr(val),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeaderFieldsSection(Paper paper, PaperTemplate template) {
    final List<String> requiredLabels = List<String>.from(
      template.effectiveLayout.elements
          .where((e) => e.type == ElementType.headerFieldsBlock)
          .fold<List<String>>(
            [],
            (prev, e) => [
              ...prev,
              ...List<String>.from(e.properties['fieldLabels'] ?? []),
            ],
          ),
    );
    final allowAll = requiredLabels.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Header Fields',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (allowAll)
              TextButton.icon(
                onPressed: () =>
                    ref.read(editorStateProvider.notifier).addHeaderField(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Field'),
              ),
          ],
        ),
        const Text(
          'Manage fields like Subject, Date, Class, etc.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildHeaderFieldsEditor(paper, requiredLabels, allowAll),
      ],
    );
  }

  Widget _buildSectionSlide(PaperSection section) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 20, 20, _editorBottomPadding()),
      children: [_buildSectionEditor(section, key: ValueKey(section.id))],
    );
  }

  Widget _buildCustomHeaderTextEditor(
    Paper paper,
    List<TemplateElement> elements,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit template text that appears in the paper header.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        ...elements.asMap().entries.map((entry) {
          final index = entry.key;
          final element = entry.value;
          final key = element.paperBindingKey;
          final value = paper.customHeaderValues[key] ?? element.content;
          final label = _readableHeaderTextLabel(element, index);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: ValueKey('${paper.id}-$key'),
              initialValue: value,
              maxLines: value.length > 40 ? 2 : 1,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: element.content,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.short_text_rounded, size: 18),
              ),
              onChanged: (val) => ref
                  .read(editorStateProvider.notifier)
                  .updateCustomHeaderValue(key, val),
            ),
          );
        }),
      ],
    );
  }

  String _readableHeaderTextLabel(TemplateElement element, int index) {
    final content = element.content.trim();
    if (content.isEmpty) return 'Header text ${index + 1}';
    if (content.length <= 28) return content;
    return '${content.substring(0, 28)}...';
  }

  Widget _buildHeaderFieldsEditor(
    Paper paper,
    List<String> requiredLabels,
    bool allowAll,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<PaperHeaderField> filteredFields = allowAll
        ? paper.headerFields
        : paper.headerFields
              .where(
                (f) => requiredLabels.any(
                  (l) => l.toLowerCase() == f.label.toLowerCase(),
                ),
              )
              .toList();

    if (filteredFields.isEmpty && !allowAll) {
      return const Center(
        child: Text(
          'No fields required for this template.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIdx, newIdx) => ref
              .read(editorStateProvider.notifier)
              .reorderHeaderFields(oldIdx, newIdx),
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
          children: [
            for (final field in filteredFields)
              Padding(
                key: ValueKey(field.id),
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.grey.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: paper.headerFields.indexOf(field),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.grey.withAlpha(100),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Label field
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: field.label,
                          readOnly:
                              !allowAll, // Only custom templates lock labels
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Label',
                            hintStyle: TextStyle(
                              color: Colors.grey.withAlpha(100),
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) => ref
                              .read(editorStateProvider.notifier)
                              .updateHeaderField(field.id, label: val),
                        ),
                      ),
                      // Divider
                      Container(
                        height: 20,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(10),
                      ),
                      // Value field
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: field.value,
                          enabled: !field.isPlaceholder,
                          style: TextStyle(
                            fontSize: 14,
                            color: field.isPlaceholder
                                ? Colors.grey.withAlpha(120)
                                : (isDark
                                      ? Colors.white.withAlpha(200)
                                      : Colors.black87),
                          ),
                          decoration: InputDecoration(
                            hintText: field.isPlaceholder
                                ? 'Auto-filled'
                                : 'Enter value...',
                            hintStyle: TextStyle(
                              color: Colors.grey.withAlpha(100),
                              fontStyle: field.isPlaceholder
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) => ref
                              .read(editorStateProvider.notifier)
                              .updateHeaderField(field.id, value: val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderFieldAction(
                        icon: field.isPlaceholder
                            ? Icons.edit_off_rounded
                            : Icons.edit_rounded,
                        color: field.isPlaceholder
                            ? Colors.blue
                            : Colors.grey.withAlpha(120),
                        tooltip: field.isPlaceholder
                            ? 'Enable Manual Entry'
                            : 'Set as Placeholder',
                        onTap: () => ref
                            .read(editorStateProvider.notifier)
                            .updateHeaderField(
                              field.id,
                              isPlaceholder: !field.isPlaceholder,
                            ),
                      ),
                      if (allowAll)
                        _HeaderFieldAction(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.redAccent.withAlpha(180),
                          tooltip: 'Delete Field',
                          onTap: () => ref
                              .read(editorStateProvider.notifier)
                              .deleteHeaderField(field.id),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionEditor(PaperSection section, {required Key key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 38 : 8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${section.totalMarks.toStringAsFixed(section.totalMarks.truncateToDouble() == section.totalMarks ? 0 : 1)} Marks',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${section.questions.length} Questions',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: section.prefix,
                        decoration: InputDecoration(
                          labelText: 'Section Prefix (e.g. Part A)',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) => ref
                            .read(editorStateProvider.notifier)
                            .updateSection(section.id, prefix: val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDeleteSection(section),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: section.instruction,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Section Instructions',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) => ref
                      .read(editorStateProvider.notifier)
                      .updateSection(section.id, instruction: val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text(
                          'Show Title',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: section.showTitle,
                        onChanged: (val) => ref
                            .read(editorStateProvider.notifier)
                            .updateSection(section.id, showTitle: val),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text(
                          'Show Divider',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: section.showDivider,
                        onChanged: (val) => ref
                            .read(editorStateProvider.notifier)
                            .updateSection(section.id, showDivider: val),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(13)
                        : Colors.orange.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Student must answer: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: section.requiredCount?.toString(),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'All',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final count = int.tryParse(val);
                            ref
                                .read(editorStateProvider.notifier)
                                .updateSection(
                                  section.id,
                                  requiredCount: count,
                                  clearRequiredCount: val.isEmpty,
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'out of ${section.questions.length}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Questions',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showWordModeEditor(section),
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('Word Mode'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) => ref
                .read(editorStateProvider.notifier)
                .reorderQuestions(section.id, oldIdx, newIdx),
            children: [
              for (final q in section.questions)
                Container(
                  key: ValueKey(q.id),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(8)
                        : Colors.grey.withAlpha(13),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withAlpha(25),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: q.isOptional
                            ? Colors.grey[100]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          q.marks.toStringAsFixed(0),
                          style: TextStyle(
                            color: q.isOptional
                                ? Colors.grey[600]
                                : Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: _buildQuestionPreviewText(q.text),
                    subtitle: Text(
                      '${q.type.name.toUpperCase()}${q.isOptional ? " - OPTIONAL" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: q.isOptional ? Colors.grey : Colors.blueGrey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () =>
                              _showQuestionEditor(section.id, question: q),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => ref
                              .read(editorStateProvider.notifier)
                              .deleteQuestion(section.id, q.id),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showQuestionEditor(section.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 0,
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPreviewText(String text) {
    try {
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> json = jsonDecode(text);
        final doc = quill.Document.fromJson(json.cast<Map<String, dynamic>>());
        return Text(
          doc.toPlainText().replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    } catch (_) {}
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildBrandingEditor(
    Paper paper,
    bool showSchoolName,
    List<TemplateElement> logoElements,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logoElements.isNotEmpty) ...[
          const Text(
            'Logo(s)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: logoElements.asMap().entries.map((entry) {
                final idx = entry.key;
                final String? path = paper.logos.length > idx
                    ? paper.logos[idx]
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            ref
                                .read(editorStateProvider.notifier)
                                .updateBranding(
                                  logo: image.path,
                                  logoIndex: idx,
                                );
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withAlpha(25),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      isDark ? 51 : 13,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: path != null && path.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 24,
                                      color: Colors.grey[400],
                                    ),
                            ),
                            if (path != null && path.isNotEmpty)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: GestureDetector(
                                  onTap: () => ref
                                      .read(editorStateProvider.notifier)
                                      .updateBranding(logo: '', logoIndex: idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Logo ${idx + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (showSchoolName)
          TextFormField(
            initialValue: paper.schoolName,
            decoration: InputDecoration(
              labelText: 'School/Institution Name',
              hintText: 'Enter school name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (val) => ref
                .read(editorStateProvider.notifier)
                .updateBranding(schoolName: val),
          ),
      ],
    );
  }

  void _showQuestionEditor(String sectionId, {Question? question}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          QuestionEditorSheet(sectionId: sectionId, question: question),
    );
  }

  void _showWordModeEditor(PaperSection section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SectionWordModeScreen(section: section),
      ),
    );
  }

  void _confirmDeleteSection(PaperSection section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text(
          'Are you sure you want to delete "${section.title}" and all its questions?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(editorStateProvider.notifier).deleteSection(section.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(Paper paper) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templates = ref.watch(templateProvider).all;
    final template = templates.firstWhere(
      (t) => t.id == paper.templateId,
      orElse: () => templates.first,
    );

    return Column(
      children: [
        if (_showPreview)
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? Colors.black26 : Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Layout',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TemplateSelector(
                  selectedTemplateId: paper.templateId,
                  onTemplateSelected: (id) =>
                      ref.read(editorStateProvider.notifier).updateTemplate(id),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: isDark
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.grey[200],
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).cardTheme.color
                          : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (template.hasBorder)
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Color(template.primaryColor.toInt()),
                                width: 1,
                              ),
                            ),
                            child: _buildPreviewContent(paper, template),
                          )
                        else
                          _buildPreviewContent(paper, template),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContent(Paper paper, PaperTemplate template) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: TemplateHeaderPreview(paper: paper, template: template),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (paper.instruction.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(
                      paper.instruction.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ...paper.sections.map(
                (s) => _buildPreviewSection(s, template, paper),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPreviewSection(
    PaperSection s,
    PaperTemplate template,
    Paper paper,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (s.showTitle || s.prefix.isNotEmpty)
          Text(
            '${s.prefix} ${s.showTitle ? s.title : ""}'.trim(),
            style: TextStyle(
              color: template.type == TemplateType.coaching
                  ? Color(template.primaryColor.toInt())
                  : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        if (s.instruction != null && s.instruction!.isNotEmpty)
          Text(
            s.instruction!,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        if (s.requiredCount != null && s.requiredCount! < s.questions.length)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Note: Answer any ${s.requiredCount} questions from this section.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 11,
              ),
            ),
          ),
        if (s.showDivider) const Divider(),
        _buildPreviewQuestions(s, template, paper),
      ],
    );
  }

  Widget _buildPreviewQuestions(
    PaperSection section,
    PaperTemplate template,
    Paper paper,
  ) {
    final questions = section.questions.asMap().entries.map((entry) {
      return _buildPreviewQuestion(entry.key + 1, entry.value, paper);
    }).toList();

    if (template.paperLayout != PaperLayout.twoColumn) {
      return Column(children: questions);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columnWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: questions
              .map(
                (question) => SizedBox(
                  width: columnWidth > 260 ? columnWidth : constraints.maxWidth,
                  child: question,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPreviewQuestion(int index, Question q, Paper paper) {
    final label = QuestionNumberingService.paperLabel(index, paper);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '$label. ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRichText(q.text, q.alignment),
                    if (q.isOptional)
                      const Text(
                        '(Optional/OR Choice)',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '[${q.marks.toStringAsFixed(0)}]',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (q.type == QuestionType.mcq)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4),
              child: Column(
                children: q.options.asMap().entries.map((o) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${String.fromCharCode(65 + o.key)}) '),
                        Expanded(child: _buildGeometryAwareText(o.value.text)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (q.type == QuestionType.fillInTheBlanks)
            const Padding(
              padding: EdgeInsets.only(left: 34, top: 4),
              child: Text('Ans: ________________________'),
            ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, TextAlign alignment) {
    try {
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> json = jsonDecode(text);
        final doc = quill.Document.fromJson(json.cast<Map<String, dynamic>>());
        final controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        return quill.QuillEditor.basic(
          controller: controller,
          config: quill.QuillEditorConfig(
            embedBuilders: [GeometryEmbedBuilder()],
          ),
        );
      }
    } catch (_) {}
    return _buildGeometryAwareText(text, alignment: alignment);
  }

  Widget _buildGeometryAwareText(
    String text, {
    TextAlign alignment = TextAlign.start,
  }) {
    final spans = RegExp(r'\{\{geometry:([^}]+)\}\}').allMatches(text).toList();
    if (spans.isEmpty) return Text(text, textAlign: alignment);

    final children = <Widget>[];
    var cursor = 0;
    for (final match in spans) {
      final before = text.substring(cursor, match.start).trim();
      if (before.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(before, textAlign: alignment),
          ),
        );
      }

      final diagram = GeometryDiagramRegistry.instance.diagramFor(
        match.group(1)!,
      );
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: diagram == null
                  ? Center(child: Text(match.group(0)!))
                  : CustomPaint(
                      painter: GeometryPainter(
                        diagram: diagram.copyWith(showGrid: false),
                        showPointHandles: false,
                      ),
                    ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }

    final after = text.substring(cursor).trim();
    if (after.isNotEmpty) {
      children.add(Text(after, textAlign: alignment));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _SaveAsSheet extends ConsumerStatefulWidget {
  final String initialFileNameBase;

  const _SaveAsSheet({required this.initialFileNameBase});

  @override
  ConsumerState<_SaveAsSheet> createState() => _SaveAsSheetState();
}

class _SaveAsSheetState extends ConsumerState<_SaveAsSheet> {
  late final TextEditingController _controller;
  late final MathKeyboardController _mathKeyboardController;
  var _selectedFormat = _PaperExportFormat.app;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFileNameBase);
    _mathKeyboardController = ref.read(mathKeyboardControllerProvider.notifier);
  }

  @override
  void dispose() {
    final controller = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mathKeyboardController.unregisterController(controller);
      } catch (_) {}
    });
    _controller.dispose();
    super.dispose();
  }

  PaperTemplate _templateForPaper(Paper paper) {
    final templates = ref.read(templateProvider).all;
    return templates.firstWhere(
      (template) => template.id == paper.templateId,
      orElse: () => templates.first,
    );
  }

  Future<void> _saveExport() async {
    final fileNameBase = _controller.text.trim();
    if (fileNameBase.isEmpty) {
      setState(() => _errorText = 'Enter a file name');
      return;
    }
    if (ExportFileService.hasInvalidFileNameCharacters(fileNameBase)) {
      setState(() => _errorText = 'Remove characters like / \\ : * ? " < > |');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Always save internally first
      await ref.read(editorStateProvider.notifier).savePaper();
      ref.invalidate(savedPapersProvider);

      if (_selectedFormat == _PaperExportFormat.app) {
        if (!mounted || !navigator.mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Paper saved to library successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final latestPaper = ref.read(editorStateProvider);
      final template = _templateForPaper(latestPaper);
      final file = _selectedFormat == _PaperExportFormat.pdf
          ? await PdfService.export(
              latestPaper,
              template,
              fileNameBase: fileNameBase,
            )
          : await WordExportService.export(
              latestPaper,
              template,
              fileNameBase: fileNameBase,
            );

      if (!mounted || !navigator.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Could not save. Please try again.';
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final mathKeyboardInset =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math
        ? keyboardState.height
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + mathKeyboardInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Save as',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MathKeyboardField(
              controller: _controller,
              builder: (context, focusNode, isMathActive) => TextField(
                controller: _controller,
                focusNode: focusNode,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'File name',
                  hintText: 'Example: Class 10 Mid Term',
                  errorText: _errorText,
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onSubmitted: (_) => _isSaving ? null : _saveExport(),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose format',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SaveFormatOption(
                    title: 'App',
                    subtitle: 'Library',
                    icon: Icons.bookmark_added_outlined,
                    isSelected: _selectedFormat == _PaperExportFormat.app,
                    onTap: _isSaving
                        ? null
                        : () => setState(
                            () => _selectedFormat = _PaperExportFormat.app,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SaveFormatOption(
                    title: 'PDF',
                    subtitle: 'Print',
                    icon: Icons.picture_as_pdf_outlined,
                    isSelected: _selectedFormat == _PaperExportFormat.pdf,
                    onTap: _isSaving
                        ? null
                        : () => setState(
                            () => _selectedFormat = _PaperExportFormat.pdf,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SaveFormatOption(
                    title: 'Word',
                    subtitle: 'Docx',
                    icon: Icons.description_outlined,
                    isSelected: _selectedFormat == _PaperExportFormat.word,
                    onTap: _isSaving
                        ? null
                        : () => setState(
                            () => _selectedFormat = _PaperExportFormat.word,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveExport,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save File'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PaperExportFormat { pdf, word, app }

class _SectionWordModeScreen extends ConsumerStatefulWidget {
  final PaperSection section;

  const _SectionWordModeScreen({required this.section});

  @override
  ConsumerState<_SectionWordModeScreen> createState() =>
      _SectionWordModeScreenState();
}

class _SectionWordModeScreenState
    extends ConsumerState<_SectionWordModeScreen> {
  late final quill.QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    final paper = ref.read(editorStateProvider);
    _controller.document.insert(0, _sectionWordModeText(widget.section, paper));
    _controller.addListener(_handleDocumentChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDocumentChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleDocumentChanged() {
    if (!mounted) return;
    setState(() {});
  }

  PaperTemplate _templateForPaper(Paper paper) {
    final templates = ref.read(templateProvider).all;
    return templates.firstWhere(
      (template) => template.id == paper.templateId,
      orElse: () => templates.first,
    );
  }

  Size _paperDimensions(PaperSize size) {
    return switch (size) {
      PaperSize.a4 => const Size(595.27, 841.89),
      PaperSize.a5 => const Size(419.53, 595.27),
      PaperSize.a3 => const Size(841.89, 1190.55),
      PaperSize.letter => const Size(612.0, 792.0),
      PaperSize.legal => const Size(612.0, 1008.0),
    };
  }

  String _paperSizeLabel(PaperSize size) {
    return switch (size) {
      PaperSize.a4 => 'A4',
      PaperSize.a5 => 'A5',
      PaperSize.a3 => 'A3',
      PaperSize.letter => 'Letter',
      PaperSize.legal => 'Legal',
    };
  }

  void _insertTextAtCursor(String text) {
    final docEnd = (_controller.document.length - 1).clamp(0, 1 << 30);
    final base = _controller.selection.baseOffset;
    final extent = _controller.selection.extentOffset;
    final safeBase = base < 0 ? docEnd : base.clamp(0, docEnd);
    final safeExtent = extent < 0 ? safeBase : extent.clamp(0, docEnd);
    final index = safeBase <= safeExtent ? safeBase : safeExtent;
    final length = (safeBase - safeExtent).abs();

    _controller.replaceText(index, length, text, null);
    _controller.updateSelection(
      TextSelection.collapsed(offset: (index + text.length).clamp(0, docEnd)),
      quill.ChangeSource.local,
    );

    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    _focusNode.requestFocus();
  }

  int _nextQuestionNumber() {
    final matches = RegExp(
      r'---\s*Question\b.*?---',
      caseSensitive: false,
    ).allMatches(_controller.document.toPlainText());
    return matches.length + 1;
  }

  String _nextQuestionLabel() {
    final paper = ref.read(editorStateProvider);
    return QuestionNumberingService.paperLabel(_nextQuestionNumber(), paper);
  }

  void _insertQuestionBlock() {
    final next = _nextQuestionLabel();
    _insertTextAtCursor('\n\n--- Question $next ---\n');
  }

  void _insertMcqBlock() {
    final next = _nextQuestionLabel();
    _insertTextAtCursor(
      '\n\n--- Question $next ---\n'
      'Write question here\n'
      'a) Option A\n'
      'b) Option B\n'
      'c) Option C\n'
      'd) Option D\n',
    );
  }

  void _insertFillBlankBlock() {
    final next = _nextQuestionLabel();
    _insertTextAtCursor(
      '\n\n--- Question $next ---\nFill in the blank: ________\n',
    );
  }

  void _insertPageBreak() {
    _insertTextAtCursor('\n\n--- Page Break ---\n\n');
  }

  void _formatSelection(quill.Attribute attribute) {
    _controller.formatSelection(attribute);
    _focusNode.requestFocus();
  }

  int _estimatedPageCount(double bodyHeight, PaperTemplate template) {
    final plainText = _controller.document.toPlainText();
    final wrappedLineCount = plainText
        .split('\n')
        .fold<int>(
          0,
          (count, line) => count + (line.length / 48).ceil().clamp(1, 20),
        );
    final lineHeight = (template.questionFontSize * 1.65).clamp(18.0, 28.0);
    final linesPerPage = (bodyHeight / lineHeight).floor().clamp(8, 60);
    return (wrappedLineCount / linesPerPage).ceil().clamp(1, 12);
  }

  void _showHeaderEditor(Paper paper, PaperTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _WordModeHeaderEditorSheet(paper: paper, template: template),
    );
  }

  void _showTemplateChooser(Paper paper) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WordModeTemplateSheet(paper: paper),
    );
  }

  void _showNumberingChooser(Paper paper) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: _QuestionNumberingSelector(paper: paper),
      ),
    );
  }

  void _apply() {
    final defaults = ref.read(questionEditorDefaultsProvider);
    final deltaString = jsonEncode(_controller.document.toDelta().toJson());
    final questions = SectionWordParser.parseDeltaString(
      deltaString,
      defaultType: defaults.type,
      defaultMarks: defaults.marks,
      defaultOptional: defaults.isOptional,
    );

    if (questions.isEmpty) {
      setState(() => _errorText = 'Add at least one question before applying.');
      return;
    }

    ref
        .read(editorStateProvider.notifier)
        .bulkUpdateQuestions(widget.section.id, questions);

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Updated ${questions.length} question${questions.length == 1 ? '' : 's'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final paper = ref.watch(editorStateProvider);
    final template = _templateForPaper(paper);
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final mathKeyboardInset =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math
        ? keyboardState.height
        : 0.0;
    _controller.readOnly =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _apply,
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF5F5F5),
        appBar: AppBar(
          elevation: 0,
          title: Text(
            '${widget.section.title} Word Mode',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Apply'),
              onPressed: _apply,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildWordModeRibbon(
              paper: paper,
              template: template,
              isCompact: isMobile,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: mathKeyboardInset),
                child: Stack(
                  children: [
                    _buildDocumentWorkspace(isDark, paper, template),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.section.questions.length} source questions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorText != null)
              Container(
                width: double.infinity,
                color: Colors.redAccent.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordModeRibbon({
    required Paper paper,
    required PaperTemplate template,
    bool isCompact = false,
  }) {
    return Container(
      height: isCompact ? 92 : 140,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 16,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _WordModeRibbonGroup(
              label: 'EDIT',
              children: [
                _WordModeRibbonButton(
                  icon: Icons.check_rounded,
                  label: 'Apply',
                  onTap: _apply,
                ),
                _WordModeRibbonButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const _WordModeVerticalDivider(),
            _WordModeRibbonGroup(
              label: 'HEADER',
              children: [
                _WordModeRibbonButton(
                  icon: Icons.edit_note_rounded,
                  label: 'Header',
                  onTap: () => _showHeaderEditor(paper, template),
                ),
                _WordModeRibbonButton(
                  icon: Icons.style_rounded,
                  label: 'Template',
                  onTap: () => _showTemplateChooser(paper),
                ),
                _WordModeRibbonButton(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Number',
                  onTap: () => _showNumberingChooser(paper),
                ),
              ],
            ),
            const _WordModeVerticalDivider(),
            _WordModeRibbonGroup(
              label: 'INSERT',
              children: [
                _WordModeRibbonButton(
                  icon: Icons.add_circle_outline,
                  label: 'Question',
                  onTap: _insertQuestionBlock,
                ),
                _WordModeRibbonButton(
                  icon: Icons.checklist_rtl,
                  label: 'MCQ',
                  onTap: _insertMcqBlock,
                ),
                _WordModeRibbonButton(
                  icon: Icons.short_text_rounded,
                  label: 'Blank',
                  onTap: _insertFillBlankBlock,
                ),
                _WordModeRibbonButton(
                  icon: Icons.note_add_outlined,
                  label: 'Page',
                  onTap: _insertPageBreak,
                ),
              ],
            ),
            const _WordModeVerticalDivider(),
            _WordModeRibbonGroup(
              label: 'FORMAT',
              children: [
                _WordModeFormatButton(
                  icon: Icons.format_bold,
                  label: 'Bold',
                  onTap: () => _formatSelection(quill.Attribute.bold),
                ),
                _WordModeFormatButton(
                  icon: Icons.format_italic,
                  label: 'Italic',
                  onTap: () => _formatSelection(quill.Attribute.italic),
                ),
                _WordModeFormatButton(
                  icon: Icons.format_underlined,
                  label: 'Line',
                  onTap: () => _formatSelection(quill.Attribute.underline),
                ),
                _WordModeFormatButton(
                  icon: Icons.format_list_bulleted,
                  label: 'Bullets',
                  onTap: () => _formatSelection(quill.Attribute.ul),
                ),
                _WordModeFormatButton(
                  icon: Icons.format_list_numbered,
                  label: 'Numbers',
                  onTap: () => _formatSelection(quill.Attribute.ol),
                ),
                _WordModeFormatButton(
                  icon: Icons.format_align_center,
                  label: 'Center',
                  onTap: () =>
                      _formatSelection(quill.Attribute.centerAlignment),
                ),
                if (!isCompact)
                  _WordModeFormatButton(
                    icon: Icons.format_align_left,
                    label: 'Left',
                    onTap: () =>
                        _formatSelection(quill.Attribute.leftAlignment),
                  ),
                if (!isCompact)
                  _WordModeFormatButton(
                    icon: Icons.format_align_right,
                    label: 'Right',
                    onTap: () =>
                        _formatSelection(quill.Attribute.rightAlignment),
                  ),
              ],
            ),
            const _WordModeVerticalDivider(),
            _WordModeRibbonGroup(
              label: 'SECTION',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.section.questions.length} questions',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _paperSizeLabel(template.paperSize),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.paperLayout == PaperLayout.twoColumn
                            ? 'Two column'
                            : 'Single column',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentWorkspace(
    bool isDark,
    Paper paper,
    PaperTemplate template,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageSize = _paperDimensions(template.paperSize);
        final pageAspect = pageSize.width / pageSize.height;
        final horizontalMargin = constraints.maxWidth < 760 ? 14.0 : 36.0;
        final maxPageWidth = constraints.maxWidth < 760
            ? constraints.maxWidth - (horizontalMargin * 2)
            : 720.0;
        final pageWidth = maxPageWidth.clamp(280.0, 720.0);
        final pageHeight = (pageWidth / pageAspect).clamp(420.0, 1120.0);
        final pagePadding = pageWidth < 560 ? 20.0 : 48.0;
        final firstPageEditorHeight = (pageHeight - 250).clamp(120.0, 760.0);
        final pageCount = _estimatedPageCount(firstPageEditorHeight, template);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 28,
          ),
          child: Center(
            child: Column(
              children: [
                _WordModePageShell(
                  width: pageWidth,
                  height: pageHeight,
                  isDark: isDark,
                  hasError: _errorText != null,
                  label: '${_paperSizeLabel(template.paperSize)} Page 1',
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: pagePadding,
                      vertical: pageWidth < 560 ? 22 : 42,
                    ),
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TemplateHeaderPreview(
                              paper: paper,
                              template: template,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.section.showTitle
                                  ? widget.section.title
                                  : '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: template.questionFontSize + 3,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            if ((widget.section.instruction ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.section.instruction!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            ClipRect(
                              child: MathKeyboardField(
                                controller: _controller,
                                focusNode: _focusNode,
                                builder: (context, fieldFocusNode, isMathActive) {
                                  return SizedBox(
                                    height: firstPageEditorHeight,
                                    child: quill.QuillEditor(
                                      controller: _controller,
                                      focusNode: fieldFocusNode,
                                      scrollController: _scrollController,
                                      config: quill.QuillEditorConfig(
                                        placeholder:
                                            'Tap Question, MCQ, Blank, or Page from the ribbon.',
                                        embedBuilders: [GeometryEmbedBuilder()],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                for (var page = 2; page <= pageCount; page++) ...[
                  const SizedBox(height: 28),
                  _WordModePageShell(
                    width: pageWidth,
                    height: pageHeight,
                    isDark: isDark,
                    hasError: false,
                    label: '${_paperSizeLabel(template.paperSize)} Page $page',
                    child: Center(
                      child: Container(
                        margin: EdgeInsets.all(pagePadding),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.withValues(alpha: 0.04),
                        ),
                        child: Text(
                          page == 2
                              ? 'Content continues automatically as the paper grows. Tap Page to force a page break.'
                              : 'Continuation page $page',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WordModePageShell extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  final bool hasError;
  final String label;
  final Widget child;

  const _WordModePageShell({
    required this.width,
    required this.height,
    required this.isDark,
    required this.hasError,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ),
        SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              border: Border.all(
                color: hasError
                    ? Colors.redAccent
                    : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _WordModeRibbonGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _WordModeRibbonGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(children: children),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _WordModeRibbonButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WordModeRibbonButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.blue[800]),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _WordModeFormatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WordModeFormatButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20, color: Colors.blue[800]),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _WordModeVerticalDivider extends StatelessWidget {
  const _WordModeVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      color: Colors.grey.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _WordModeHeaderEditorSheet extends ConsumerWidget {
  final Paper paper;
  final PaperTemplate template;

  const _WordModeHeaderEditorSheet({
    required this.paper,
    required this.template,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staticTextElements = template.effectiveLayout.elements
        .where((element) => element.type == ElementType.staticText)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Header',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WordModeSheetPanel(
                title: 'Paper Identity',
                icon: Icons.badge_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      key: ValueKey('word-title-${paper.id}-${paper.title}'),
                      initialValue: paper.title,
                      decoration: const InputDecoration(
                        labelText: 'Paper title',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      onChanged: (value) => ref
                          .read(editorStateProvider.notifier)
                          .updateTitle(value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey(
                        'word-school-${paper.id}-${paper.schoolName}',
                      ),
                      initialValue: paper.schoolName,
                      decoration: const InputDecoration(
                        labelText: 'School / institute name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      onChanged: (value) => ref
                          .read(editorStateProvider.notifier)
                          .updateBranding(schoolName: value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey(
                        'word-instruction-${paper.id}-${paper.instruction}',
                      ),
                      initialValue: paper.instruction,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Paper instructions',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      onChanged: (value) => ref
                          .read(editorStateProvider.notifier)
                          .updateInstruction(value),
                    ),
                    const SizedBox(height: 12),
                    _QuestionNumberingSelector(paper: paper),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _WordModeSheetPanel(
                title: 'Header Fields',
                icon: Icons.view_list_outlined,
                trailing: TextButton.icon(
                  onPressed: () =>
                      ref.read(editorStateProvider.notifier).addHeaderField(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
                child: Column(
                  children: [
                    for (final entry in paper.headerFields.asMap().entries)
                      _WordModeHeaderFieldEditor(
                        index: entry.key,
                        field: entry.value,
                        fieldCount: paper.headerFields.length,
                      ),
                  ],
                ),
              ),
              if (staticTextElements.isNotEmpty) ...[
                const SizedBox(height: 14),
                _WordModeSheetPanel(
                  title: 'Template Text',
                  icon: Icons.short_text_rounded,
                  child: Column(
                    children: [
                      for (final entry in staticTextElements.asMap().entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            key: ValueKey(
                              'word-static-${entry.value.paperBindingKey}',
                            ),
                            initialValue:
                                paper.customHeaderValues[entry
                                    .value
                                    .paperBindingKey] ??
                                entry.value.content,
                            decoration: InputDecoration(
                              labelText: _wordModeStaticTextLabel(
                                entry.value,
                                entry.key,
                              ),
                              isDense: true,
                            ),
                            onChanged: (value) => ref
                                .read(editorStateProvider.notifier)
                                .updateCustomHeaderValue(
                                  entry.value.paperBindingKey,
                                  value,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WordModeTemplateSheet extends ConsumerWidget {
  final Paper paper;

  const _WordModeTemplateSheet({required this.paper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Template',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TemplateSelector(
                selectedTemplateId: paper.templateId,
                onTemplateSelected: (id) {
                  ref.read(editorStateProvider.notifier).updateTemplate(id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WordModeHeaderFieldEditor extends ConsumerWidget {
  final int index;
  final PaperHeaderField field;
  final int fieldCount;

  const _WordModeHeaderFieldEditor({
    required this.index,
    required this.field,
    required this.fieldCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Move up',
          icon: const Icon(Icons.keyboard_arrow_up, size: 20),
          onPressed: index == 0
              ? null
              : () => ref
                    .read(editorStateProvider.notifier)
                    .reorderHeaderFields(index, index - 1),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: 'Move down',
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          onPressed: index >= fieldCount - 1
              ? null
              : () => ref
                    .read(editorStateProvider.notifier)
                    .reorderHeaderFields(index, index + 2),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: field.isPlaceholder ? 'Use blank line' : 'Show value',
          icon: Icon(
            field.isPlaceholder
                ? Icons.horizontal_rule_rounded
                : Icons.text_fields_rounded,
            size: 20,
          ),
          onPressed: () => ref
              .read(editorStateProvider.notifier)
              .updateHeaderField(field.id, isPlaceholder: !field.isPlaceholder),
        ),
        IconButton(
          tooltip: 'Delete field',
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: Colors.redAccent,
          ),
          onPressed: () => ref
              .read(editorStateProvider.notifier)
              .deleteHeaderField(field.id),
        ),
      ],
    );

    final labelField = TextFormField(
      key: ValueKey('word-field-label-${field.id}'),
      initialValue: field.label,
      decoration: const InputDecoration(labelText: 'Label', isDense: true),
      onChanged: (value) => ref
          .read(editorStateProvider.notifier)
          .updateHeaderField(field.id, label: value),
    );

    final valueField = TextFormField(
      key: ValueKey('word-field-value-${field.id}'),
      initialValue: field.value,
      decoration: const InputDecoration(labelText: 'Value', isDense: true),
      onChanged: (value) => ref
          .read(editorStateProvider.notifier)
          .updateHeaderField(
            field.id,
            value: value,
            isPlaceholder: value.trim().isEmpty,
          ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: labelField),
                    const SizedBox(width: 8),
                    controls,
                  ],
                ),
                const SizedBox(height: 8),
                valueField,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: labelField),
              const SizedBox(width: 8),
              Expanded(flex: 5, child: valueField),
              controls,
            ],
          ),
        );
      },
    );
  }
}

class _WordModeSheetPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _WordModeSheetPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

String _wordModeStaticTextLabel(TemplateElement element, int index) {
  final content = element.content.trim();
  if (content.isEmpty) return 'Template text ${index + 1}';
  if (content.length <= 28) return content;
  return '${content.substring(0, 28)}...';
}

String _sectionWordModeText(PaperSection section, Paper paper) {
  if (section.questions.isEmpty) {
    final label = QuestionNumberingService.paperLabel(1, paper);
    return '--- Question $label ---\n';
  }

  return section.questions
      .asMap()
      .entries
      .map((entry) {
        final question = entry.value;
        final label = QuestionNumberingService.paperLabel(entry.key + 1, paper);
        final buffer = StringBuffer()
          ..writeln('--- Question $label ---')
          ..writeln(_questionPlainText(question).trim());

        if (question.type == QuestionType.mcq) {
          for (final optionEntry in question.options.asMap().entries) {
            final label = String.fromCharCode(97 + optionEntry.key);
            buffer.writeln('$label) ${optionEntry.value.text}');
          }
        }

        return buffer.toString().trimRight();
      })
      .join('\n\n');
}

String _questionPlainText(Question question) {
  final text = question.text;
  try {
    if (text.startsWith('[') || text.startsWith('{')) {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        final doc = quill.Document.fromJson(
          decoded.cast<Map<String, dynamic>>(),
        );
        return doc.toPlainText();
      }
    }
  } catch (_) {}

  return text;
}

class _SaveFormatOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SaveFormatOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.blue : Theme.of(context).disabledColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Theme.of(context).dividerColor.withAlpha(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.blue : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderFieldAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderFieldAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
        splashRadius: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}

class _QuestionNumberingSelector extends ConsumerWidget {
  final Paper paper;

  const _QuestionNumberingSelector({required this.paper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = QuestionNumberingService.sample(
      paper.questionNumberStyle,
      customLabels: paper.customQuestionNumberLabels,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<QuestionNumberStyle>(
          initialValue: paper.questionNumberStyle,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Question numbering',
            prefixIcon: Icon(Icons.format_list_numbered_rounded),
            helperText:
                'Used in preview, PDF, Word, Excel, slides, and Word Mode.',
          ),
          items: QuestionNumberStyle.values.map((style) {
            return DropdownMenuItem(
              value: style,
              child: Text(QuestionNumberingService.displayName(style)),
            );
          }).toList(),
          selectedItemBuilder: (context) {
            return QuestionNumberStyle.values.map((style) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  QuestionNumberingService.displayName(style),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
          onChanged: (style) {
            if (style == null) return;
            ref
                .read(editorStateProvider.notifier)
                .updateQuestionNumberStyle(style);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Preview: $sample',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        if (paper.questionNumberStyle == QuestionNumberStyle.custom) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              'custom-question-number-labels-${paper.customQuestionNumberLabels.join("|")}',
            ),
            initialValue: paper.customQuestionNumberLabels.join(', '),
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Custom labels',
              hintText: 'Example: କ, ଖ, ଗ or क, ख, ग or Q1, Q2, Q3',
              prefixIcon: Icon(Icons.edit_rounded),
              helperText: 'Separate labels with commas or new lines.',
            ),
            onChanged: (value) {
              final labels = value
                  .split(RegExp(r'[,\n]'))
                  .map((label) => label.trim())
                  .where((label) => label.isNotEmpty)
                  .toList();
              ref
                  .read(editorStateProvider.notifier)
                  .updateCustomQuestionNumberLabels(labels);
            },
          ),
        ],
      ],
    );
  }
}

class _EditorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _EditorCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 51 : 10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
