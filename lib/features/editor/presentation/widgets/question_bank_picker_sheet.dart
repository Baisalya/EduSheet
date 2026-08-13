import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/providers/question_bank_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuestionBankPickerSheet extends ConsumerStatefulWidget {
  const QuestionBankPickerSheet({super.key});

  @override
  ConsumerState<QuestionBankPickerSheet> createState() =>
      _QuestionBankPickerSheetState();
}

class _QuestionBankPickerSheetState
    extends ConsumerState<QuestionBankPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String _query = '';
  String? _subject;
  Difficulty? _difficulty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _plainText(Question question) {
    try {
      if (question.text.startsWith('[') || question.text.startsWith('{')) {
        final decoded = jsonDecode(question.text);
        if (decoded is List) {
          return quill.Document.fromJson(
            decoded.cast<Map<String, dynamic>>(),
          ).toPlainText().trim();
        }
      }
    } catch (_) {}
    return question.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionBankProvider);
    final theme = Theme.of(context);
    final subjects = state.questions.map((q) => q.subject).toSet().toList()
      ..sort();
    final query = _query.trim().toLowerCase();
    final questions = state.questions.where((entry) {
      final text = _plainText(entry.question).toLowerCase();
      final tags = entry.tags.join(' ').toLowerCase();
      return (_subject == null || entry.subject == _subject) &&
          (_difficulty == null || entry.difficulty == _difficulty) &&
          (query.isEmpty ||
              text.contains(query) ||
              entry.chapter.toLowerCase().contains(query) ||
              tags.contains(query));
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add from question bank',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Select several questions and insert them together.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search question, chapter or tag',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      label: const Text('All subjects'),
                      selected: _subject == null,
                      onSelected: (_) => setState(() => _subject = null),
                    ),
                  ),
                  for (final subject in subjects)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: FilterChip(
                        label: Text(subject),
                        selected: _subject == subject,
                        onSelected: (_) => setState(() => _subject = subject),
                      ),
                    ),
                  for (final difficulty in Difficulty.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: FilterChip(
                        label: Text(difficulty.name.toUpperCase()),
                        selected: _difficulty == difficulty,
                        onSelected: (selected) => setState(
                          () => _difficulty = selected ? difficulty : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${questions.length} questions • ${_selectedIds.length} selected',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : questions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.questions.isEmpty
                              ? 'Your question bank is empty. Save reusable questions from the Question Bank screen first.'
                              : 'No question matches these filters.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = questions[index];
                        final id = entry.question.id;
                        final selected = _selectedIds.contains(id);
                        return Material(
                          color: selected
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.55,
                                )
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: (_) => setState(() {
                              selected
                                  ? _selectedIds.remove(id)
                                  : _selectedIds.add(id);
                            }),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: Text(
                              _plainText(entry.question),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${entry.subject} • ${entry.chapter} • ${entry.difficulty.name} • ${entry.question.marks.toStringAsFixed(entry.question.marks % 1 == 0 ? 0 : 1)} marks',
                              ),
                            ),
                            secondary: entry.isFavorite
                                ? const Icon(Icons.star_rounded, color: Colors.amber)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (questions.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      final visibleIds = questions.map((q) => q.question.id);
                      final allSelected = visibleIds.every(_selectedIds.contains);
                      if (allSelected) {
                        _selectedIds.removeAll(visibleIds);
                      } else {
                        _selectedIds.addAll(visibleIds);
                      }
                    }),
                    child: const Text('Select visible'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final selected = state.questions
                              .where(
                                (entry) =>
                                    _selectedIds.contains(entry.question.id),
                              )
                              .map((entry) => entry.question)
                              .toList();
                          Navigator.pop(context, selected);
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Add ${_selectedIds.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
