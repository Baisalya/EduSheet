import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../editor/domain/models/paper_model.dart';
import '../../domain/models/question_bank_model.dart';
import '../providers/question_bank_provider.dart';

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
  }

  @override
  void dispose() {
    _textController.dispose();
    _subjectController.dispose();
    _chapterController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final id = widget.question?.question.id ?? const Uuid().v4();
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.question == null ? 'Add Question' : 'Edit Question'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Question Text', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _chapterController,
                    decoration: const InputDecoration(labelText: 'Chapter', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Difficulty>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
              items: Difficulty.values.map((d) => DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Tags (comma separated)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<QuestionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Question Type', border: OutlineInputBorder()),
              items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() {
                _type = v!;
                if (_type == QuestionType.mcq && _options.isEmpty) {
                  _options = List.generate(4, (i) => QuestionOption(id: const Uuid().v4(), text: 'Option ${i + 1}'));
                }
              }),
            ),
            if (_type == QuestionType.mcq) ...[
              const SizedBox(height: 24),
              const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ..._options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: opt.isCorrect,
                        onChanged: (v) => setState(() {
                          _options = _options.asMap().entries.map((e) => e.value.copyWith(isCorrect: e.key == i)).toList();
                        }),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: opt.text,
                          decoration: InputDecoration(labelText: 'Option ${i + 1}'),
                          onChanged: (v) => _options[i] = opt.copyWith(text: v),
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
    );
  }
}
