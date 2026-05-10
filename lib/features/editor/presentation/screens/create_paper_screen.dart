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
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(editorStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(paper.title),
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
        ],
      ),
      body: _showPreview ? _buildPreview(paper) : _buildEditor(paper),
      floatingActionButton: !_showPreview ? FloatingActionButton.extended(
        onPressed: () => ref.read(editorStateProvider.notifier).addSection(),
        icon: const Icon(Icons.add),
        label: const Text('Add Section'),
      ) : null,
    );
  }

  Widget _buildEditor(Paper paper) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildBrandingEditor(paper),
              const SizedBox(height: 24),
              _buildSectionHeader('General Info'),
              const SizedBox(height: 12),
              MathKeyboardField(
                controller: _titleController,
                builder: (context, fieldFocusNode, isMathActive) => TextField(
                  controller: _titleController..text = paper.title,
                  focusNode: fieldFocusNode,
                  keyboardType: isMathActive ? TextInputType.none : TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Exam Title (e.g. Mid-Term 2024)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => ref.read(editorStateProvider.notifier).updateTitle(val),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Header Fields (Customizable)'),
              const Text('Add fields like Subject, Date, Class, etc.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildHeaderFieldsEditor(paper),
              const SizedBox(height: 24),
              _buildSectionHeader('Template & Layout'),
              const SizedBox(height: 12),
              TemplateSelector(
                selectedTemplateId: paper.templateId,
                onTemplateSelected: (id) => ref.read(editorStateProvider.notifier).updateTemplate(id),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Sections & Questions'),
              const SizedBox(height: 8),
              ...paper.sections.map((section) => _buildSectionEditor(section, key: ValueKey(section.id))),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Include OMR Sheet'),
                subtitle: const Text('Add a full OMR sheet at the end'),
                value: paper.includeOmr,
                onChanged: (val) => ref.read(editorStateProvider.notifier).toggleOmr(val),
              ),
            ],
          ),
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: field.label,
                        decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
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
                          border: const OutlineInputBorder(),
                          hintText: field.isPlaceholder ? '________' : null,
                        ),
                        onChanged: (val) => ref.read(editorStateProvider.notifier).updateHeaderField(field.id, value: val),
                      ),
                    ),
                    IconButton(
                      icon: Icon(field.isPlaceholder ? Icons.check_box : Icons.check_box_outline_blank, size: 20),
                      onPressed: () => ref.read(editorStateProvider.notifier).updateHeaderField(field.id, isPlaceholder: !field.isPlaceholder),
                      tooltip: 'Toggle Placeholder',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => ref.read(editorStateProvider.notifier).deleteHeaderField(field.id),
                      tooltip: 'Delete Field',
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref.read(editorStateProvider.notifier).addHeaderField(),
          icon: const Icon(Icons.add),
          label: const Text('Add Header Field'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
    );
  }

  Widget _buildSectionEditor(PaperSection section, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            Expanded(child: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('${section.questions.length} Questions', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        subtitle: section.instruction != null ? Text(section.instruction!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: section.prefix,
                        decoration: const InputDecoration(labelText: 'Prefix (e.g. Part A)'),
                        onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, prefix: val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteSection(section),
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: section.instruction,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                  onChanged: (val) => ref.read(editorStateProvider.notifier).updateSection(section.id, instruction: val),
                ),
              ],
            ),
          ),
          const Divider(),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) => ref.read(editorStateProvider.notifier).reorderQuestions(section.id, oldIdx, newIdx),
            children: [
              for (final q in section.questions)
                ListTile(
                  key: ValueKey(q.id),
                  leading: CircleAvatar(child: Text(q.marks.toStringAsFixed(0))),
                  title: _buildQuestionPreviewText(q.text),
                  subtitle: Text(q.type.name.toUpperCase()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showQuestionEditor(section.id, question: q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => ref.read(editorStateProvider.notifier).deleteQuestion(section.id, q.id),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              onPressed: () => _showQuestionEditor(section.id),
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
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
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: paper.schoolLogo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(paper.schoolLogo!), fit: BoxFit.cover),
                  )
                : const Icon(Icons.add_a_photo, size: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            initialValue: paper.schoolName,
            decoration: const InputDecoration(labelText: 'School Name'),
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
                    Text(
                      '${s.prefix} ${s.title}'.trim(),
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
                    const Divider(),
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
                                Expanded(child: _buildRichText(q.text)),
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
