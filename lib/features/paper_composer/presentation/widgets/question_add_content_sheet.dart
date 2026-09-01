import 'package:edusheet/features/paper_composer/application/question_insertion_anchor.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

enum QuestionAddContentAction {
  math,
  geometry,
  blank,
  subQuestion,
  orDivider,
  answerOptions,
  stimulus,
  wordBank,
  table,
  image,
  structuredPart,
  internalChoice,
  answerSpace,
  instruction,
  scanText,
  quickStart,
}

class QuestionAddContentSheet {
  const QuestionAddContentSheet._();

  static Future<QuestionAddContentAction?> show(
    BuildContext context, {
    required QuestionInsertionAnchor insertionAnchor,
  }) {
    return showAdaptiveModalBottomSheet<QuestionAddContentAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) =>
          _QuestionAddContentBody(insertionAnchor: insertionAnchor),
    );
  }
}

class _QuestionAddContentBody extends StatelessWidget {
  final QuestionInsertionAnchor insertionAnchor;

  const _QuestionAddContentBody({required this.insertionAnchor});

  @override
  Widget build(BuildContext context) {
    // Keep the most common paper-authoring helpers first. Math and geometry
    // already have dedicated actions on the composer toolbar, while blanks,
    // parts and answer choices otherwise require opening this sheet.
    final items = <_AddContentItem>[
      const _AddContentItem(
        action: QuestionAddContentAction.blank,
        icon: Icons.space_bar_rounded,
        title: 'Blank line',
        subtitle: 'Useful for fill-in-the-blank questions',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.subQuestion,
        icon: Icons.subdirectory_arrow_right_rounded,
        title: 'Sub-question',
        subtitle: 'Insert the next (a), (b), (c)… label',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.answerOptions,
        icon: Icons.checklist_rounded,
        title: 'Answer options',
        subtitle: 'Add editable choices without locking the layout',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.orDivider,
        icon: Icons.compare_arrows_rounded,
        title: 'OR separator',
        subtitle: 'Insert an editable OR line in the paper text',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.stimulus,
        icon: Icons.menu_book_outlined,
        title: 'Passage / poem / case study',
        subtitle: 'Add source material with the question prompt',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.wordBank,
        icon: Icons.view_module_outlined,
        title: 'Word bank',
        subtitle: 'Add a printable word or phrase box',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.table,
        icon: Icons.table_chart_outlined,
        title: 'Table / data',
        subtitle: 'Build rows and columns without manual spacing',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.image,
        icon: Icons.image_outlined,
        title: 'Image / chart / map',
        subtitle: 'Attach an image with optional caption and description',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.structuredPart,
        icon: Icons.account_tree_outlined,
        title: 'Structured question part',
        subtitle: 'Add an editable (a), (b), (c)… child question',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.internalChoice,
        icon: Icons.compare_arrows_rounded,
        title: 'Internal OR choice',
        subtitle: 'Add full alternative questions with marks validation',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.answerSpace,
        icon: Icons.border_bottom_rounded,
        title: 'Answer space',
        subtitle: 'Set blank, ruled, box or graph space for this question',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.instruction,
        icon: Icons.info_outline_rounded,
        title: 'Instruction line',
        subtitle: 'Insert editable instruction text',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.math,
        icon: Icons.functions_rounded,
        title: 'Math formula',
        subtitle: 'Insert exactly at the blinking cursor',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.geometry,
        icon: Icons.category_outlined,
        title: 'Geometry / diagram',
        subtitle: 'Build and place a diagram in the question',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.scanText,
        icon: Icons.document_scanner_outlined,
        title: 'Scan text',
        subtitle: 'Insert scanned text at the current cursor',
      ),
      const _AddContentItem(
        action: QuestionAddContentAction.quickStart,
        icon: Icons.auto_awesome_outlined,
        title: 'Quick start helper',
        subtitle: 'MCQ, fill blank, numerical and more — optional',
      ),
    ];

    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Add to question',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Everything stays editable. Add only the helper you need.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insertionAnchor.actionLabel,
                            key: const ValueKey('add-content-insertion-anchor'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insertionAnchor.contextLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            // There are only a handful of helpers, so mount them eagerly.
            // This keeps accessibility/search semantics complete and avoids
            // common actions disappearing from the widget tree on short
            // phones while still allowing the sheet itself to scroll.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Column(
                children: [
                  for (final item in items)
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: ListTile(
                        minTileHeight: 64,
                        leading: Icon(item.icon),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(item.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, item.action),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContentItem {
  final QuestionAddContentAction action;
  final IconData icon;
  final String title;
  final String subtitle;

  const _AddContentItem({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
