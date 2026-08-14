import 'package:flutter/material.dart';

class QuestionBankSaveMetadata {
  final String subject;
  final String chapter;
  final String grade;

  const QuestionBankSaveMetadata({
    required this.subject,
    required this.chapter,
    required this.grade,
  });
}

/// Compact metadata prompt shown only when a paper question is missing reusable
/// Question Bank classification.
class SaveToQuestionBankSheet extends StatefulWidget {
  final String subject;
  final String chapter;
  final String grade;

  const SaveToQuestionBankSheet({
    super.key,
    this.subject = '',
    this.chapter = '',
    this.grade = '',
  });

  static Future<QuestionBankSaveMetadata?> show(
    BuildContext context, {
    String subject = '',
    String chapter = '',
    String grade = '',
  }) {
    return showModalBottomSheet<QuestionBankSaveMetadata>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SaveToQuestionBankSheet(
        subject: subject,
        chapter: chapter,
        grade: grade,
      ),
    );
  }

  @override
  State<SaveToQuestionBankSheet> createState() =>
      _SaveToQuestionBankSheetState();
}

class _SaveToQuestionBankSheetState extends State<SaveToQuestionBankSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _chapter;
  late final TextEditingController _grade;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.subject);
    _chapter = TextEditingController(text: widget.chapter);
    _grade = TextEditingController(text: widget.grade);
  }

  @override
  void dispose() {
    _subject.dispose();
    _chapter.dispose();
    _grade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Save to Question Bank',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            'Add reusable classification now. The question itself is copied independently.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _subject,
            autofocus: widget.subject.trim().isEmpty,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Subject',
              hintText: 'e.g. Mathematics',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _chapter,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Chapter / unit',
              hintText: 'Optional — General if left blank',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _grade,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Class / grade',
              hintText: 'Optional',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save reusable copy'),
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.pop(
      context,
      QuestionBankSaveMetadata(
        subject: _subject.text.trim(),
        chapter: _chapter.text.trim(),
        grade: _grade.text.trim(),
      ),
    );
  }
}
