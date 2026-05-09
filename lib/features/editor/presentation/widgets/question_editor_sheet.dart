import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';

import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';

// Note: I'll need to check if vsc_quill_delta_to_html is available, 
// if not I might need another way to convert delta to html for storage.
// For now let's assume I can use Delta directly as a JSON string.

class QuestionEditorSheet extends ConsumerStatefulWidget {
  final String sectionId;
  final Question? question;

  const QuestionEditorSheet({
    super.key,
    required this.sectionId,
    this.question,
  });

  @override
  ConsumerState<QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends ConsumerState<QuestionEditorSheet> {
  late QuillController _controller;
  late QuestionType _type;
  late double _marks;
  late List<QuestionOption> _options;

  @override
  void initState() {
    super.initState();
    _type = widget.question?.type ?? QuestionType.descriptive;
    _marks = widget.question?.marks ?? 1.0;
    _options = widget.question?.options.map((o) => o.copyWith()).toList() ?? [];

    if (widget.question != null) {
      // For now, let's assume 'text' is a Delta JSON string
      try {
        // Simple heuristic: if it looks like JSON, parse as Delta
        if (widget.question!.text.startsWith('[') || widget.question!.text.startsWith('{')) {
          final List<dynamic> json = jsonDecode(widget.question!.text);
          _controller = QuillController(
            document: Document.fromJson(json.cast<Map<String, dynamic>>()),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          // fallback to plain text if it's not JSON
          _controller = QuillController.basic();
          _controller.document.insert(0, widget.question!.text);
        }
      } catch (e) {
        _controller = QuillController.basic();
        _controller.document.insert(0, widget.question!.text);
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  void _save() {
    final text = jsonEncode(_controller.document.toDelta().toJson());
    if (widget.question == null) {
      ref.read(editorStateProvider.notifier).addQuestion(
        widget.sectionId, 
        text, 
        type: _type,
        marks: _marks,
        options: _options,
      );
    } else {
      ref.read(editorStateProvider.notifier).updateQuestion(
        widget.sectionId,
        widget.question!.id,
        text: text,
        type: _type,
        marks: _marks,
        options: _options,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive = keyboardState.isVisible && keyboardState.type == KeyboardType.math;
    _controller.readOnly = isMathActive;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.question == null ? 'Add Question' : 'Edit Question',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            DropdownButtonFormField<QuestionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Question Type'),
              items: QuestionType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.name.toUpperCase()),
              )).toList(),
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _marks.toString(),
              decoration: const InputDecoration(labelText: 'Marks'),
              keyboardType: TextInputType.number,
              onChanged: (val) => _marks = double.tryParse(val) ?? 1.0,
            ),
            const SizedBox(height: 16),
            const Text('Question Text:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            QuillSimpleToolbar(
              controller: _controller,
              config: const QuillSimpleToolbarConfig(),
            ),
            MathKeyboardField(
              controller: _controller,
              builder: (context, fieldFocusNode, isMathActive) => Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QuillEditor(
                  controller: _controller,
                  focusNode: fieldFocusNode,
                  scrollController: ScrollController(),
                  config: const QuillEditorConfig(
                    placeholder: 'Enter question text...',
                  ),
                ),
              ),
            ),
            if (_type == QuestionType.mcq) ...[
              const SizedBox(height: 16),
              const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                return Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: opt.isCorrect,
                      onChanged: (val) {
                        setState(() {
                          _options = _options.asMap().entries.map((e) {
                            return e.value.copyWith(isCorrect: e.key == idx);
                          }).toList();
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: opt.text,
                        onChanged: (val) => _options[idx] = opt.copyWith(text: val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _options.removeAt(idx)),
                    ),
                  ],
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _options.add(QuestionOption(id: const Uuid().v4(), text: ''))),
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
