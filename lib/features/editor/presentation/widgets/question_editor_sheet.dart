import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';

import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/ocr/presentation/screens/ocr_screen.dart';

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
  ConsumerState<QuestionEditorSheet> createState() =>
      _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends ConsumerState<QuestionEditorSheet> {
  late QuillController _controller;
  late QuestionType _type;
  late double _marks;
  late bool _isOptional;
  late List<QuestionOption> _options;

  @override
  void initState() {
    super.initState();
    _type = widget.question?.type ?? QuestionType.descriptive;
    _marks = widget.question?.marks ?? 1.0;
    _isOptional = widget.question?.isOptional ?? false;
    _options = widget.question?.options.map((o) => o.copyWith()).toList() ?? [];

    if (widget.question != null) {
      // For now, let's assume 'text' is a Delta JSON string
      try {
        // Simple heuristic: if it looks like JSON, parse as Delta
        if (widget.question!.text.startsWith('[') ||
            widget.question!.text.startsWith('{')) {
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
      ref
          .read(editorStateProvider.notifier)
          .addQuestion(
            widget.sectionId,
            text,
            type: _type,
            marks: _marks,
            options: _options,
            isOptional: _isOptional,
          );
    } else {
      ref
          .read(editorStateProvider.notifier)
          .updateQuestion(
            widget.sectionId,
            widget.question!.id,
            text: text,
            type: _type,
            marks: _marks,
            options: _options,
            isOptional: _isOptional,
          );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math;
    _controller.readOnly = isMathActive;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.question == null ? 'Add Question' : 'Edit Question',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<QuestionType>(
                    isExpanded: true,
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: 'Question Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: QuestionType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.name.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _type = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _marks.toString(),
                    decoration: InputDecoration(
                      labelText: 'Marks',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _marks = double.tryParse(val) ?? 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Optional Question',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Does not count towards total marks',
                  style: TextStyle(fontSize: 11),
                ),
                value: _isOptional,
                onChanged: (val) => setState(() => _isOptional = val),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question Content',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final text = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OCRScreen(),
                      ),
                    );
                    if (text != null && mounted) {
                      _controller.document.insert(
                        _controller.selection.baseOffset,
                        text,
                      );
                    }
                  },
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text(
                    'Scan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
                borderRadius: BorderRadius.circular(16),
                color: isDark ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QuillSimpleToolbar(
                    controller: _controller,
                    config: const QuillSimpleToolbarConfig(
                      showFontFamily: false,
                      showFontSize: false,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showColorButton: true,
                      showAlignmentButtons: true,
                    ),
                  ),
                  const Divider(height: 1),
                  MathKeyboardField(
                    controller: _controller,
                    builder: (context, fieldFocusNode, isMathActive) =>
                        Container(
                          height: 180,
                          padding: const EdgeInsets.all(12),
                          child: QuillEditor(
                            controller: _controller,
                            focusNode: fieldFocusNode,
                            scrollController: ScrollController(),
                            config: const QuillEditorConfig(
                              placeholder: 'Start typing the question...',
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            if (_type == QuestionType.mcq) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Options',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _options.add(
                        QuestionOption(id: const Uuid().v4(), text: ''),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Add Option',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _options.indexWhere((option) => option.isCorrect),
                onChanged: (idx) {
                  if (idx == null) return;
                  setState(() {
                    _options = _options.asMap().entries.map((entry) {
                      return entry.value.copyWith(isCorrect: entry.key == idx);
                    }).toList();
                  });
                },
                child: Column(
                  children: _options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final opt = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Radio<int>(value: idx, activeColor: Colors.green),
                          Expanded(
                            child: TextFormField(
                              initialValue: opt.text,
                              decoration: InputDecoration(
                                hintText:
                                    'Option ${String.fromCharCode(65 + idx)}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                fillColor: opt.isCorrect
                                    ? Colors.green.withValues(
                                        alpha: isDark ? 0.1 : 0.05,
                                      )
                                    : null,
                              ),
                              onChanged: (val) =>
                                  _options[idx] = opt.copyWith(text: val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            onPressed: () =>
                                setState(() => _options.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Question',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
