import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_view.dart';

class CreatePaperScreen extends ConsumerStatefulWidget {
  const CreatePaperScreen({super.key});

  @override
  ConsumerState<CreatePaperScreen> createState() => _CreatePaperScreenState();
}

class _CreatePaperScreenState extends ConsumerState<CreatePaperScreen> {
  final _mathController = MathFieldEditingController();
  final _focusNode = FocusNode();
  String? _activeSectionId;

  @override
  Widget build(BuildContext context) {
    final paper = ref.watch(editorStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(paper.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => PdfService.generateAndPreview(paper),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Paper Title'),
                  onChanged: (val) => ref.read(editorStateProvider.notifier).updateTitle(val),
                ),
                const SizedBox(height: 20),
                ...paper.sections.map((section) => _buildSection(section)),
                ElevatedButton.icon(
                  onPressed: () => ref.read(editorStateProvider.notifier).addSection(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Section'),
                ),
                SwitchListTile(
                  title: const Text('Include OMR Sheet'),
                  value: paper.includeOmr,
                  onChanged: (val) => ref.read(editorStateProvider.notifier).toggleOmr(val),
                ),
              ],
            ),
          ),
          if (_focusNode.hasFocus)
            MathKeyboardView(controller: _mathController),
        ],
      ),
      floatingActionButton: _activeSectionId != null ? FloatingActionButton(
        onPressed: _showAddQuestionDialog,
        child: const Icon(Icons.add_comment),
      ) : null,
    );
  }

  Widget _buildSection(PaperSection section) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton(
                  onPressed: () => setState(() => _activeSectionId = section.id),
                  child: Text(_activeSectionId == section.id ? 'ACTIVE' : 'SELECT'),
                ),
              ],
            ),
            ...section.questions.map((q) => ListTile(
              title: Text(q.text),
              subtitle: q.options.isNotEmpty ? Text(q.options.join(', ')) : null,
            )),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MathField(
              controller: _mathController,
              focusNode: _focusNode,
              decoration: const InputDecoration(hintText: 'Type question with math...'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = _mathController.currentEditingValue();
              ref.read(editorStateProvider.notifier).addQuestion(_activeSectionId!, text);
              _mathController.clear();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
