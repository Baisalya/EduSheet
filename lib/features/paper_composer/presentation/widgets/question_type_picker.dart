import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:flutter/material.dart';

class QuestionTypePicker {
  const QuestionTypePicker._();

  static const primary = <QuestionType>[
    QuestionType.mcq,
    QuestionType.shortAnswer,
    QuestionType.longAnswer,
    QuestionType.fillInTheBlanks,
    QuestionType.numerical,
  ];

  /// Types the focused composer can create without losing required structure.
  /// Existing papers may still contain every persisted [QuestionType].
  static const authorable = <QuestionType>[
    QuestionType.mcq,
    QuestionType.descriptive,
    QuestionType.fillInTheBlanks,
    QuestionType.multipleSelect,
    QuestionType.trueFalse,
    QuestionType.oneWord,
    QuestionType.shortAnswer,
    QuestionType.longAnswer,
    QuestionType.numerical,
    QuestionType.mathematicalExpression,
    QuestionType.assertionReason,
    QuestionType.imageOrDiagram,
    QuestionType.custom,
  ];

  static Future<QuestionType?> show(
    BuildContext context, {
    required QuestionType selected,
  }) {
    var query = '';
    return showModalBottomSheet<QuestionType>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final available = <QuestionType>[
            ...authorable,
            if (!authorable.contains(selected)) selected,
          ];
          final types = available.where((type) {
            return normalized.isEmpty ||
                type.label.toLowerCase().contains(normalized);
          }).toList();

          return FractionallySizedBox(
            heightFactor: 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question type',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Focused types only. Existing advanced question structures remain compatible.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search types',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      final active = type == selected;
                      return Card(
                        elevation: 0,
                        color: active
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        child: ListTile(
                          minTileHeight: 58,
                          leading: Icon(type.composerIcon),
                          title: Text(
                            type.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: type.usesOptions
                              ? Text(
                                  type.allowsMultipleCorrect
                                      ? 'Answer choices · multiple correct supported'
                                      : 'Answer choices',
                                )
                              : null,
                          trailing: active
                              ? const Icon(Icons.check_circle_rounded)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(context, type),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
