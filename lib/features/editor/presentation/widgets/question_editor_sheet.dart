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
  final ScrollController _sheetScrollController = ScrollController();
  final ScrollController _questionScrollController = ScrollController();
  late QuestionType _type;
  late double _marks;
  late bool _isOptional;
  late List<QuestionOption> _options;
  final Map<String, TextEditingController> _optionControllers = {};
  String? _questionError;
  String? _marksError;
  String? _optionsError;

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

    if (_type == QuestionType.mcq && _options.isEmpty) {
      _options = _emptyMcqOptions();
    }
    _syncOptionControllers();
  }

  void _save() {
    if (!_validate()) return;

    final text = jsonEncode(_controller.document.toDelta().toJson());
    final options = _type == QuestionType.mcq
        ? _options
              .where((option) => _optionText(option).trim().isNotEmpty)
              .map(
                (option) => option.copyWith(text: _optionText(option).trim()),
              )
              .toList()
        : <QuestionOption>[];
    if (widget.question == null) {
      ref
          .read(editorStateProvider.notifier)
          .addQuestion(
            widget.sectionId,
            text,
            type: _type,
            marks: _marks,
            options: options,
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
            options: options,
            isOptional: _isOptional,
          );
    }
    Navigator.pop(context);
  }

  bool _validate() {
    final questionText = _controller.document.toPlainText().trim();
    final mcqOptionCount = _options
        .where((option) => _optionText(option).trim().isNotEmpty)
        .length;

    setState(() {
      _questionError = questionText.isEmpty ? 'Write the question first' : null;
      _marksError = _marks <= 0 ? 'Marks must be more than 0' : null;
      _optionsError = _type == QuestionType.mcq && mcqOptionCount < 2
          ? 'Add at least two options'
          : null;
    });

    return _questionError == null &&
        _marksError == null &&
        _optionsError == null;
  }

  void _setType(QuestionType type) {
    setState(() {
      _type = type;
      if (_type == QuestionType.mcq && _options.isEmpty) {
        _options = _emptyMcqOptions();
      }
      _syncOptionControllers();
      _optionsError = null;
    });
  }

  List<QuestionOption> _emptyMcqOptions() {
    return List.generate(
      4,
      (_) => QuestionOption(id: const Uuid().v4(), text: ''),
    );
  }

  void _syncOptionControllers() {
    final activeIds = _options.map((option) => option.id).toSet();
    for (final entry in _optionControllers.entries.toList()) {
      if (!activeIds.contains(entry.key)) {
        entry.value.dispose();
        _optionControllers.remove(entry.key);
      }
    }

    for (final option in _options) {
      if (_optionControllers.containsKey(option.id)) continue;

      final controller = TextEditingController(text: option.text);
      controller.addListener(() => _setOptionText(option.id, controller.text));
      _optionControllers[option.id] = controller;
    }
  }

  TextEditingController _optionController(QuestionOption option) {
    _syncOptionControllers();
    return _optionControllers[option.id]!;
  }

  String _optionText(QuestionOption option) {
    return _optionControllers[option.id]?.text ?? option.text;
  }

  void _setOptionText(String optionId, String text) {
    final index = _options.indexWhere((option) => option.id == optionId);
    if (index == -1 || _options[index].text == text) return;

    _options[index] = _options[index].copyWith(text: text);
  }

  void _addOption() {
    setState(() {
      _options.add(QuestionOption(id: const Uuid().v4(), text: ''));
      _syncOptionControllers();
    });
  }

  void _removeOptionAt(int index) {
    final removed = _options[index];
    setState(() {
      _options.removeAt(index);
      _optionControllers.remove(removed.id)?.dispose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sheetScrollController.dispose();
    _questionScrollController.dispose();
    for (final controller in _optionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math;
    final mathKeyboardInset = isMathActive ? keyboardState.height : 0.0;
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
        bottom: MediaQuery.of(context).viewInsets.bottom + mathKeyboardInset,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        controller: _sheetScrollController,
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
            Text(
              'Question type',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuestionTypeChip(
                  label: 'Descriptive',
                  icon: Icons.short_text_rounded,
                  selected: _type == QuestionType.descriptive,
                  onTap: () => _setType(QuestionType.descriptive),
                ),
                _QuestionTypeChip(
                  label: 'MCQ',
                  icon: Icons.check_circle_outline_rounded,
                  selected: _type == QuestionType.mcq,
                  onTap: () => _setType(QuestionType.mcq),
                ),
                _QuestionTypeChip(
                  label: 'Fill blanks',
                  icon: Icons.edit_note_rounded,
                  selected: _type == QuestionType.fillInTheBlanks,
                  onTap: () => _setType(QuestionType.fillInTheBlanks),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _marks.toString(),
              decoration: InputDecoration(
                labelText: 'Marks',
                hintText: 'Example: 2',
                errorText: _marksError,
                prefixIcon: const Icon(Icons.score_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (val) {
                _marks = double.tryParse(val) ?? 0;
                if (_marksError != null && _marks > 0) {
                  setState(() => _marksError = null);
                }
              },
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
                  color: _questionError == null
                      ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
                      : Colors.redAccent,
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
                            scrollController: _questionScrollController,
                            config: const QuillEditorConfig(
                              placeholder: 'Start typing the question...',
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            if (_questionError != null) ...[
              const SizedBox(height: 6),
              Text(
                _questionError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
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
                    onPressed: _addOption,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Add Option',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_optionsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _optionsError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
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
                            child: MathKeyboardField(
                              controller: _optionController(opt),
                              builder: (context, fieldFocusNode, isMathActive) {
                                final controller = _optionController(opt);
                                return TextField(
                                  controller: controller,
                                  focusNode: fieldFocusNode,
                                  keyboardType: isMathActive
                                      ? TextInputType.none
                                      : TextInputType.text,
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
                                  onChanged: (val) {
                                    _setOptionText(opt.id, val);
                                    if (_optionsError != null) {
                                      setState(() => _optionsError = null);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            onPressed: () => _removeOptionAt(idx),
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

class _QuestionTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _QuestionTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.blueGrey,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : null,
      ),
      selectedColor: Colors.blue,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
