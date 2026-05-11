import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../editor/domain/models/paper_model.dart';
import '../../domain/models/question_bank_model.dart';
import '../providers/question_bank_provider.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/ocr/presentation/screens/ocr_screen.dart';

class AddEditQuestionScreen extends ConsumerStatefulWidget {
  final QuestionBankQuestion? question;

  const AddEditQuestionScreen({super.key, this.question});

  @override
  ConsumerState<AddEditQuestionScreen> createState() => _AddEditQuestionScreenState();
}

class _AddEditQuestionScreenState extends ConsumerState<AddEditQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _textController;
  late TextEditingController _subjectController;
  late TextEditingController _chapterController;
  late TextEditingController _tagsController;
  final List<TextEditingController> _optionControllers = [];
  Difficulty _difficulty = Difficulty.medium;
  QuestionType _type = QuestionType.mcq;
  List<QuestionOption> _options = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question?.question.text ?? '');
    _subjectController = TextEditingController(text: widget.question?.subject ?? '');
    _chapterController = TextEditingController(text: widget.question?.chapter ?? '');
    _tagsController = TextEditingController(text: widget.question?.tags.join(', ') ?? '');
    _difficulty = widget.question?.difficulty ?? Difficulty.medium;
    _type = widget.question?.question.type ?? QuestionType.mcq;
    _options = widget.question?.question.options.map((o) => o.copyWith()).toList() ?? [];
    
    if (_options.isEmpty && _type == QuestionType.mcq) {
      _options = List.generate(4, (i) => QuestionOption(id: const Uuid().v4(), text: 'Option ${i + 1}'));
    }

    for (final opt in _options) {
      _optionControllers.add(TextEditingController(text: opt.text));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _subjectController.dispose();
    _chapterController.dispose();
    _tagsController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save({bool addNext = false}) {
    if (_formKey.currentState!.validate()) {
      final id = widget.question?.question.id ?? const Uuid().v4();
      
      if (_type == QuestionType.mcq) {
        for (int i = 0; i < _options.length; i++) {
          _options[i] = _options[i].copyWith(text: _optionControllers[i].text);
        }
      }

      final q = QuestionBankQuestion(
        question: Question(
          id: id,
          text: _textController.text,
          type: _type,
          options: _type == QuestionType.mcq ? _options : [],
          marks: 1.0,
        ),
        subject: _subjectController.text,
        chapter: _chapterController.text,
        difficulty: _difficulty,
        tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        isFavorite: widget.question?.isFavorite ?? false,
      );

      if (widget.question == null) {
        ref.read(questionBankProvider.notifier).addQuestion(q);
      } else {
        ref.read(questionBankProvider.notifier).updateQuestion(q);
      }

      if (addNext) {
        setState(() {
          _textController.clear();
          _tagsController.clear();
          if (_type == QuestionType.mcq) {
            _options = List.generate(4, (i) => QuestionOption(id: const Uuid().v4(), text: 'Option ${i + 1}'));
            for (int i = 0; i < _optionControllers.length; i++) {
              if (i < 4) {
                _optionControllers[i].text = 'Option ${i + 1}';
              } else {
                _optionControllers[i].dispose();
              }
            }
            if (_optionControllers.length > 4) {
              _optionControllers.removeRange(4, _optionControllers.length);
            }
            _options = _options.map((o) => o.copyWith(isCorrect: false)).toList();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question saved. Add next one!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          widget.question == null ? 'Add Question' : 'Edit Question',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.question == null)
            TextButton(
              onPressed: () => _save(addNext: true),
              child: const Text('SAVE & NEXT', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 28),
            onPressed: () => _save(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _FormSection(
              title: 'Content',
              icon: Icons.edit_note_rounded,
              color: Colors.blue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Question Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      TextButton.icon(
                        onPressed: () async {
                          final text = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (context) => const OCRScreen()),
                          );
                          if (text != null && mounted) {
                            final currentText = _textController.text;
                            final selection = _textController.selection;
                            if (selection.isValid) {
                              final newText = currentText.replaceRange(selection.start, selection.end, text);
                              _textController.text = newText;
                              _textController.selection = TextSelection.collapsed(offset: selection.start + text.length);
                            } else {
                              _textController.text = currentText + text;
                            }
                          }
                        },
                        icon: const Icon(Icons.document_scanner_outlined, size: 18),
                        label: const Text('Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MathKeyboardField(
                    controller: _textController,
                    builder: (context, fieldFocusNode, isMathActive) => TextFormField(
                      controller: _textController,
                      focusNode: fieldFocusNode,
                      maxLines: 4,
                      keyboardType: isMathActive ? TextInputType.none : TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Type or scan your question here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Categorization',
              icon: Icons.category_outlined,
              color: Colors.purple,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _chapterController,
                          decoration: InputDecoration(
                            labelText: 'Chapter',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Difficulty>(
                    value: _difficulty,
                    decoration: InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: Difficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tags (comma separated)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Question Type & Options',
              icon: Icons.list_rounded,
              color: Colors.orange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<QuestionType>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() {
                      _type = v!;
                      if (_type == QuestionType.mcq && _options.isEmpty) {
                        _options = List.generate(4, (i) => QuestionOption(id: const Uuid().v4(), text: 'Option ${i + 1}'));
                        for (final opt in _options) {
                          _optionControllers.add(TextEditingController(text: opt.text));
                        }
                      }
                    }),
                  ),
                  if (_type == QuestionType.mcq) ...[
                    const SizedBox(height: 24),
                    const Text('Configure Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    ..._options.asMap().entries.map((entry) {
                      final i = entry.key;
                      final opt = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: opt.isCorrect,
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() {
                                _options = _options.asMap().entries.map((e) => e.value.copyWith(isCorrect: e.key == i)).toList();
                              }),
                            ),
                            Expanded(
                              child: MathKeyboardField(
                                controller: _optionControllers[i],
                                builder: (context, fieldFocusNode, isMathActive) => TextFormField(
                                  controller: _optionControllers[i],
                                  focusNode: fieldFocusNode,
                                  keyboardType: isMathActive ? TextInputType.none : TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: opt.isCorrect ? Colors.green.withOpacity(0.05) : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _FormSection({
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
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
