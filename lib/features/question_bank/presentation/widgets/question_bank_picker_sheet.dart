import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/providers/question_bank_provider.dart';
import 'package:edusheet/features/question_bank/presentation/screens/add_edit_question_screen.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Teacher-first multi-select Question Bank picker used by Paper Composer.
class QuestionBankPickerSheet extends ConsumerStatefulWidget {
  final String initialSubject;
  final String initialGrade;
  final double currentPaperMarks;
  final double? maximumMarks;

  const QuestionBankPickerSheet({
    super.key,
    this.initialSubject = '',
    this.initialGrade = '',
    this.currentPaperMarks = 0,
    this.maximumMarks,
  });

  static Future<List<QuestionBankQuestion>?> show(
    BuildContext context, {
    String initialSubject = '',
    String initialGrade = '',
    double currentPaperMarks = 0,
    double? maximumMarks,
  }) {
    final picker = QuestionBankPickerSheet(
      initialSubject: initialSubject,
      initialGrade: initialGrade,
      currentPaperMarks: currentPaperMarks,
      maximumMarks: maximumMarks,
    );
    if (MediaQuery.sizeOf(context).width >= 800) {
      return showDialog<List<QuestionBankQuestion>>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
            child: picker,
          ),
        ),
      );
    }
    return showAdaptiveModalBottomSheet<List<QuestionBankQuestion>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) =>
          FractionallySizedBox(heightFactor: 0.92, child: picker),
    );
  }

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
  String? _chapter;
  Difficulty? _difficulty;
  QuestionType? _type;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    final subject = widget.initialSubject.trim();
    _subject = subject.isEmpty ? null : subject;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionBankProvider);
    final theme = Theme.of(context);
    final subjects =
        state.questions
            .map((entry) => entry.subject.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final requestedSubject = _subject?.trim().toLowerCase();
    final effectiveSubject = requestedSubject == null
        ? null
        : subjects.cast<String?>().firstWhere(
            (subject) => subject?.toLowerCase() == requestedSubject,
            orElse: () => null,
          );
    final chapters =
        state.questions
            .where(
              (entry) =>
                  effectiveSubject == null || entry.subject == effectiveSubject,
            )
            .map((entry) => entry.chapter.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final effectiveChapter = _chapter != null && chapters.contains(_chapter)
        ? _chapter
        : null;
    final initialGrade = widget.initialGrade.trim().toLowerCase();
    final query = _query.trim().toLowerCase();

    final questions =
        state.questions.where((entry) {
          final question = entry.question;
          final searchable = [
            question.plainTextAccessibility,
            entry.subject,
            entry.chapter,
            question.grade,
            question.topic,
            ...entry.tags,
          ].join(' ').toLowerCase();
          return (effectiveSubject == null ||
                  entry.subject == effectiveSubject) &&
              (effectiveChapter == null || entry.chapter == effectiveChapter) &&
              (_difficulty == null || entry.difficulty == _difficulty) &&
              (_type == null || question.type == _type) &&
              (!_favoritesOnly || entry.isFavorite) &&
              (query.isEmpty || searchable.contains(query));
        }).toList()..sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          if (initialGrade.isNotEmpty) {
            final aGradeMatch =
                a.question.grade.trim().toLowerCase() == initialGrade;
            final bGradeMatch =
                b.question.grade.trim().toLowerCase() == initialGrade;
            if (aGradeMatch != bGradeMatch) {
              return aGradeMatch ? -1 : 1;
            }
          }
          return b.createdAt.compareTo(a.createdAt);
        });

    final selected = state.questions
        .where((entry) => _selectedIds.contains(entry.question.id))
        .toList();
    final selectedMarks = selected.fold<double>(
      0,
      (sum, entry) => sum + entry.question.marks,
    );
    final projectedMarks = widget.currentPaperMarks + selectedMarks;
    final exceedsMaximum =
        widget.maximumMarks != null &&
        projectedMarks > widget.maximumMarks! + 0.0001;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose from Question Bank',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Select reusable questions. Each one becomes an independent copy in this paper.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search question, chapter, topic or tag',
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
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        scrollDirection: Axis.horizontal,
                        children: [
                          FilterChip(
                            label: const Text('All subjects'),
                            selected: effectiveSubject == null,
                            onSelected: (_) => setState(() {
                              _subject = null;
                              _chapter = null;
                            }),
                          ),
                          for (final subject in subjects) ...[
                            const SizedBox(width: 6),
                            FilterChip(
                              label: Text(subject),
                              selected: effectiveSubject == subject,
                              onSelected: (_) => setState(() {
                                _subject = subject;
                                _chapter = null;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _FilterMenu<String>(
                            label: 'Chapter',
                            value: effectiveChapter,
                            values: chapters,
                            labelOf: (value) => value,
                            onChanged: (value) =>
                                setState(() => _chapter = value),
                          ),
                          _FilterMenu<Difficulty>(
                            label: 'Difficulty',
                            value: _difficulty,
                            values: Difficulty.values,
                            labelOf: (value) => value.name.toUpperCase(),
                            onChanged: (value) =>
                                setState(() => _difficulty = value),
                          ),
                          _FilterMenu<QuestionType>(
                            label: 'Type',
                            value: _type,
                            values: QuestionType.values,
                            labelOf: (value) => value.label,
                            onChanged: (value) => setState(() => _type = value),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.star_rounded, size: 16),
                            label: const Text('Favorites'),
                            selected: _favoritesOnly,
                            onSelected: (value) =>
                                setState(() => _favoritesOnly = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        '${questions.length} question${questions.length == 1 ? '' : 's'} • ${_selectedIds.length} selected • ${_marks(selectedMarks)} marks',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (state.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (questions.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyBank(
                        hasAnyQuestions: state.questions.isNotEmpty,
                        onClearFilters: _clearFilters,
                        onCreateQuestion: () async {
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (context) =>
                                  const AddEditQuestionScreen(),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 8);
                          }
                          final questionIndex = index ~/ 2;
                          final entry = questions[questionIndex];
                          return _BankPickCard(
                            entry: entry,
                            selected: _selectedIds.contains(entry.question.id),
                            onToggle: () => setState(() {
                              final id = entry.question.id;
                              if (!_selectedIds.add(id)) {
                                _selectedIds.remove(id);
                              }
                            }),
                          );
                        }, childCount: questions.length * 2 - 1),
                      ),
                    ),
                  if (exceedsMaximum)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'These questions would make the paper ${_marks(projectedMarks - widget.maximumMarks!)} marks above the declared maximum. You can still add them.',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasVisibleQuestions = questions.isNotEmpty;
                  final addSelected = FilledButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, selected),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'Add ${selected.length} • ${_marks(selectedMarks)} marks',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );

                  TextButton buildSelectVisibleButton() => TextButton(
                    onPressed: () => _toggleVisibleQuestions(questions),
                    child: const Text('Select visible'),
                  );

                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasVisibleQuestions) ...[
                          buildSelectVisibleButton(),
                          const SizedBox(height: 6),
                        ],
                        addSelected,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (hasVisibleQuestions) buildSelectVisibleButton(),
                      const Spacer(),
                      Flexible(child: addSelected),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVisibleQuestions(List<QuestionBankQuestion> questions) {
    setState(() {
      final visibleIds = questions.map((entry) => entry.question.id).toSet();
      final allSelected = visibleIds.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _subject = null;
      _chapter = null;
      _difficulty = null;
      _type = null;
      _favoritesOnly = false;
    });
  }

  static String _marks(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _BankPickCard extends StatelessWidget {
  final QuestionBankQuestion entry;
  final bool selected;
  final VoidCallback onToggle;

  const _BankPickCard({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionRichTextPreview(
                      question: entry.question,
                      maxHeight: 112,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Meta(label: entry.subject),
                        if (entry.chapter.trim().isNotEmpty)
                          _Meta(label: entry.chapter),
                        _Meta(label: entry.question.type.label),
                        _Meta(label: entry.difficulty.name),
                        _Meta(
                          label:
                              '${_QuestionBankPickerSheetState._marks(entry.question.marks)} marks',
                        ),
                        if (entry.isFavorite)
                          const _Meta(
                            label: 'Favorite',
                            icon: Icons.star_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _Meta({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 3)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;

  const _FilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final targetWidth = compact ? 128.0 : 156.0;

    return SizedBox(
      width: targetWidth,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    isExpanded: true,
                    value: value,
                    hint: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      for (final item in values)
                        DropdownMenuItem<T>(
                          value: item,
                          child: Text(
                            labelOf(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
              if (value != null)
                SizedBox.square(
                  dimension: 34,
                  child: IconButton(
                    tooltip: 'Clear $label filter',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBank extends StatelessWidget {
  final bool hasAnyQuestions;
  final VoidCallback onClearFilters;
  final VoidCallback onCreateQuestion;

  const _EmptyBank({
    required this.hasAnyQuestions,
    required this.onClearFilters,
    required this.onCreateQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyQuestions
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              hasAnyQuestions
                  ? 'No questions match these filters.'
                  : 'Your Question Bank is empty.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              hasAnyQuestions
                  ? 'Clear the filters to see the rest of your reusable questions.'
                  : 'Create a reusable question here, or save one from a paper.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (hasAnyQuestions)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              )
            else
              FilledButton.icon(
                onPressed: onCreateQuestion,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create bank question'),
              ),
          ],
        ),
      ),
    );
  }
}
