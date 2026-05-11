import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/presentation/widgets/template_selector.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import '../widgets/question_editor_sheet.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';

class CreatePaperScreen extends ConsumerStatefulWidget {
  const CreatePaperScreen({super.key});

  @override
  ConsumerState<CreatePaperScreen> createState() => _CreatePaperScreenState();
}

class _CreatePaperScreenState extends ConsumerState<CreatePaperScreen> {
  bool _showPreview = false;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleController.text = ref.read(editorStateProvider).title;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(editorStateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          paper.title.isEmpty ? 'New Paper' : paper.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.remove_red_eye),
            onPressed: () => setState(() => _showPreview = !_showPreview),
            tooltip: _showPreview ? 'Edit Mode' : 'Preview Mode',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => PdfService.generateAndPreview(paper),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Paper',
            onPressed: () async {
              await ref.read(editorStateProvider.notifier).savePaper();
              ref.invalidate(savedPapersProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paper saved successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _showPreview ? _buildPreview(paper) : _buildEditor(paper),
      floatingActionButton: !_showPreview ? FloatingActionButton.extended(
        onPressed: () => ref.read(editorStateProvider.notifier).addSection(),
        icon: const Icon(Icons.add),
        label: const Text('Add Section'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ) : null,
    );
  }

  Widget _buildEditor(Paper paper) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _EditorCard(
          title: 'Branding',
          icon: Icons.business,
          color: Colors.blue,
          child: _buildBrandingEditor(paper),
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
                  keyboardType: isMathActive ? TextInputType.none : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Exam Title (e.g. Mid-Term 2024)',
                    hintText: 'Enter exam title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) => ref.read(editorStateProvider.notifier).updateTitle(val),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Header Fields',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(editorStateProvider.notifier).addHeaderField(),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              const Text(
                'Add fields like Subject, Date, Class, etc.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildHeaderFieldsEditor(paper),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _EditorCard(
          title: 'Template & Layout',
          icon: Icons.style,
          color: Colors.orange,
          child: TemplateSelector(
            selectedTemplateId: paper.templateId,
            onTemplateSelected: (id) => ref.read(editorStateProvider.notifier).updateTemplate(id),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.list_alt, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Sections & Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...paper.sections.map((section) => _buildSectionEditor(section, key: ValueKey(section.id))),
        const SizedBox(height: 20),
        _EditorCard(
          title: 'Extra Options',
          icon: Icons.more_horiz,
          color: Colors.blueGrey,
          child: SwitchListTile(
            title: const Text('Include OMR Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Add a full OMR sheet at the end of the PDF'),
            value: paper.includeOmr,
            onChanged: (val) => ref.read(editorStateProvider.notifier).toggleOmr(val),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildHeaderFieldsEditor(Paper paper) {
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIdx, newIdx) => ref.read(editorStateProvider.notifier).reorderHeaderFields(oldIdx, newIdx),
          children: [
            for (final field in paper.headerFields)
              Padding(
                key: ValueKey(field.id),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: field.label,
                          decoration: InputDecoration(
                            labelText: 'Label',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => ref.read(editorStateProvider.notifier).updateHeaderField(field.id, label: val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          initialValue: field.value,
                          enabled: !field.isPlaceholder,
                          decoration: InputDecoration(
                            labelText: field.isPlaceholder ? 'Placeholder' : 'Value',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: field.isPlaceholder ? Colors.grey[100] : Colors.white,
                            hintText: field.isPlaceholder ? '________' : null,
                          ),
                          onChanged: (val) => ref.read(editorStateProvider.notifier).updateHeaderField(field.id, value: val),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          field.isPlaceholder ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 22,
                          color: field.isPlaceholder ? Colors.blue : Colors.grey,
                        ),
                        onPressed: () => ref.read(editorStateProvider.notifier).updateHeaderField(field.id, isPlaceholder: !field.isPlaceholder),
                        tooltip: 'Toggle Placeholder',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                        onPressed: () => ref.read(editorStateProvider.notifier).deleteHeaderField(field.id),
                        tooltip: 'Delete Field',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${section.totalMarks} Marks',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, prefix: val),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, instruction: val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Show Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: section.showTitle,
                          onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, showTitle: val),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Show Divider', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: section.showDivider,
                          onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, showDivider: val),
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
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Student must answer: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: section.requiredCount?.toString(),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'All',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final count = int.tryParse(val);
                              ref.read(editorStateProvider.notifier).updateSection(
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
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIdx, newIdx) => ref.read(editorStateProvider.notifier).reorderQuestions(section.id, oldIdx, newIdx),
              children: [
                for (final q in section.questions)
                  Container(
                    key: ValueKey(q.id),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: q.isOptional ? Colors.grey[100] : Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            q.marks.toStringAsFixed(0),
                            style: TextStyle(
                              color: q.isOptional ? Colors.grey[600] : Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      title: _buildQuestionPreviewText(q.text),
                      subtitle: Text(
                        '${q.type.name.toUpperCase()}${q.isOptional ? " • OPTIONAL" : ""}',
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
                            onPressed: () => _showQuestionEditor(section.id, question: q),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => ref.read(editorStateProvider.notifier).deleteQuestion(section.id, q.id),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPreviewText(String text) {
    try {
      if (text.startsWith('[') || text.startsWith('{')) {
        final List<dynamic> json = jsonDecode(text);
        final doc = quill.Document.fromJson(json.cast<Map<String, dynamic>>());
        return Text(doc.toPlainText().replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis);
      }
    } catch (_) {}
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildBrandingEditor(Paper paper) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              ref.read(editorStateProvider.notifier).updateBranding(schoolLogo: image.path);
            }
          },
          child: Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: paper.schoolLogo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(paper.schoolLogo!), fit: BoxFit.cover),
                      )
                    : Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey[400]),
              ),
              if (paper.schoolLogo != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: GestureDetector(
                    onTap: () => ref.read(editorStateProvider.notifier).updateBranding(schoolLogo: null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: TextFormField(
            initialValue: paper.schoolName,
            decoration: InputDecoration(
              labelText: 'School/Institution Name',
              hintText: 'Enter school name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) => ref.read(editorStateProvider.notifier).updateBranding(schoolName: val),
          ),
        ),
      ],
    );
  }

  void _showQuestionEditor(String sectionId, {Question? question}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuestionEditorSheet(sectionId: sectionId, question: question),
    );
  }

  void _confirmDeleteSection(PaperSection section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text('Are you sure you want to delete "${section.title}" and all its questions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  paper.schoolName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  paper.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const Divider(),
                _buildPreviewHeaderFields(paper),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Max Marks: ${paper.totalMarks}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: paper.sections.length,
              itemBuilder: (context, index) {
                final s = paper.sections[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 16),
                if (s.showTitle || s.prefix.isNotEmpty)
                  Text(
                    '${s.prefix} ${s.showTitle ? s.title : ""}'.trim(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                if (s.instruction != null)
                  Text(
                    s.instruction!,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                if (s.requiredCount != null && s.requiredCount! < s.questions.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Note: Answer any ${s.requiredCount} questions from this section.',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                if (s.showDivider) const Divider(),
                    ...s.questions.asMap().entries.map((entry) {
                      final qIdx = entry.key + 1;
                      final q = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$qIdx. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRichText(q.text),
                                      if (q.isOptional)
                                        const Text(
                                          '(Optional/OR Choice)',
                                          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                Text('[${q.marks}]', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (q.type == QuestionType.mcq)
                              Padding(
                                padding: const EdgeInsets.only(left: 24, top: 4),
                                child: Column(
                                  children: q.options.asMap().entries.map((o) {
                                    return Row(
                                      children: [
                                        Text('${String.fromCharCode(65 + o.key)}) '),
                                        Expanded(child: Text(o.value.text)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeaderFields(Paper paper) {
    if (paper.headerFields.isEmpty) return const SizedBox.shrink();

    List<List<PaperHeaderField>> rows = [];
    for (var i = 0; i < paper.headerFields.length; i += 2) {
      rows.add(paper.headerFields.sublist(i, i + 2 > paper.headerFields.length ? paper.headerFields.length : i + 2));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: row.map((field) {
              final content = field.isPlaceholder ? '________________' : field.value;
              return Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '${field.label}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: content),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRichText(String text) {
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
          config: const quill.QuillEditorConfig(),
        );
      }
    } catch (_) {}
    return Text(text);
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
