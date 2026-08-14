import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calculation_history_entry.dart';
import '../../domain/models/calculator_mode.dart';
import '../providers/calculator_provider.dart';

class CalculatorHistoryDrawer extends ConsumerWidget {
  final bool dialogMode;

  const CalculatorHistoryDrawer({
    super.key,
    this.dialogMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(calculatorProvider).history;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: dialogMode
              ? BorderRadius.circular(20)
              : const BorderRadius.vertical(top: Radius.circular(24)),
          border: dialogMode
              ? Border.all(color: theme.colorScheme.outlineVariant)
              : null,
        ),
        child: Column(
          children: [
            if (!dialogMode) ...[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Calculation History',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (history.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(calculatorProvider.notifier).clearHistory(),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  if (dialogMode)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.isEmpty
                  ? _EmptyHistory(theme: theme)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      itemCount: history.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = history[history.length - 1 - index];
                        return _HistoryTile(
                          entry: entry,
                          onReuse: () {
                            ref
                                .read(calculatorProvider.notifier)
                                .reuseHistory(entry);
                            Navigator.maybePop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CalculationHistoryEntry entry;
  final VoidCallback onReuse;

  const _HistoryTile({required this.entry, required this.onReuse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onReuse,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _AngleBadge(angleUnit: entry.angleUnit),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.expression,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '= ${entry.result}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reuse expression',
                onPressed: onReuse,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AngleBadge extends StatelessWidget {
  final AngleUnit angleUnit;

  const _AngleBadge({required this.angleUnit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final ThemeData theme;

  const _EmptyHistory({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 42,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: 10),
            Text(
              'No calculations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed calculations will appear here with their results.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
