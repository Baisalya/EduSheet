import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import '../widgets/question_editor_sheet.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';

class CreatePaperScreen extends ConsumerStatefulWidget {
  const CreatePaperScreen({super.key});

  @override
  ConsumerState<CreatePaperScreen> createState() => _CreatePaperScreenState();
}

class _CreatePaperScreenState extends ConsumerState<CreatePaperScreen> {
  bool _showPreview = false;

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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildBrandingEditor(paper),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Paper Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => ref.read(editorStateProvider.notifier).updateTitle(val),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onReorder: (oldIdx, newIdx) => ref.read(editorStateProvider.notifier).reorderSections(oldIdx, newIdx),
            children: [
              for (final section in paper.sections)
                _buildSectionEditor(section, key: ValueKey(section.id)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SwitchListTile(
            title: const Text('Include OMR Sheet'),
            value: paper.includeOmr,
            onChanged: (val) => ref.read(editorStateProvider.notifier).toggleOmr(val),
          ),
        ),
      ],
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
    // For now, let's just show a simple list preview. 
    // Real "Live Preview" would use PdfPreview, but that might be heavy for mobile.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Text(paper.title, style: Theme.of(context).textTheme.headlineMedium)),
        const Divider(),
        ...paper.sections.map((s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('${s.prefix} ${s.title}'.trim(), style: Theme.of(context).textTheme.titleLarge),
            if (s.instruction != null) Text(s.instruction!, style: const TextStyle(fontStyle: FontStyle.italic)),
            const Divider(),
            ...s.questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$idx. '),
                        Expanded(child: _buildRichText(q.text)),
                        Text('[${q.marks}]'),
                      ],
                    ),
                    if (q.type == QuestionType.mcq)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 4),
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
        )),
      ],
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
