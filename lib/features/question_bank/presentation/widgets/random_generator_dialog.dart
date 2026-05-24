import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/question_bank_model.dart';
import '../providers/question_bank_provider.dart';

class RandomGeneratorDialog extends ConsumerStatefulWidget {
  const RandomGeneratorDialog({super.key});

  @override
  ConsumerState<RandomGeneratorDialog> createState() =>
      _RandomGeneratorDialogState();
}

class _RandomGeneratorDialogState extends ConsumerState<RandomGeneratorDialog> {
  int _count = 10;
  String? _subject;
  Difficulty? _difficulty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionBankProvider);

    return AlertDialog(
      title: const Text('Generate Random Questions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _count.toString(),
              decoration: const InputDecoration(
                labelText: 'Number of Questions',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _count = int.tryParse(v) ?? 10,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject (Optional)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any Subject')),
                ...state.subjects.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: (v) => setState(() => _subject = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Difficulty>(
              initialValue: _difficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty (Optional)',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Any Difficulty'),
                ),
                ...Difficulty.values.map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name.toUpperCase()),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _difficulty = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final filtered = state.questions.where((q) {
              final matchesSubject = _subject == null || q.subject == _subject;
              final matchesDifficulty =
                  _difficulty == null || q.difficulty == _difficulty;
              return matchesSubject && matchesDifficulty;
            }).toList();

            if (filtered.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No questions match the criteria.'),
                ),
              );
              return;
            }

            final random = Random();
            final selectionCount = min(_count, filtered.length);
            final result = <QuestionBankQuestion>[];
            final pool = List<QuestionBankQuestion>.from(filtered);

            for (var i = 0; i < selectionCount; i++) {
              final index = random.nextInt(pool.length);
              result.add(pool.removeAt(index));
            }

            Navigator.pop(context);
            _showResults(context, result);
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }

  void _showResults(BuildContext context, List<QuestionBankQuestion> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generated ${result.length} Questions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: result.length,
            itemBuilder: (context, index) => ListTile(
              leading: Text('${index + 1}.'),
              title: Text(
                result[index].question.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, we'd add these to a paper editor.
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Questions could be added to a new paper.'),
                ),
              );
            },
            child: const Text('Use in Paper'),
          ),
        ],
      ),
    );
  }
}
