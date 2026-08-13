import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaperStyleSheet extends ConsumerWidget {
  final String selectedTemplateId;

  const PaperStyleSheet({super.key, required this.selectedTemplateId});

  static Future<void> show(
    BuildContext context, {
    required String selectedTemplateId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: PaperStyleSheet(selectedTemplateId: selectedTemplateId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateProvider);
    final templates = state.all;

    return Column(
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
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Paper style',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (templates.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final base = templates.firstWhere(
                      (item) => item.id == selectedTemplateId,
                      orElse: () => templates.first,
                    );
                    final createdId = await PaperStyleEditorSheet.show(context, base);
                    if (createdId != null && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Customize'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Choose the printed look. This does not change your questions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 126,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final selected = template.id == selectedTemplateId;
              return _PaperStyleCard(
                template: template,
                selected: selected,
                onTap: () {
                  ref
                      .read(editorStateProvider.notifier)
                      .updateTemplate(template.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PaperStyleCard extends StatelessWidget {
  final PaperTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const _PaperStyleCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(template.type)),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${_typeLabel(template.type)} · ${template.paperSize.name.toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(TemplateType type) {
    switch (type) {
      case TemplateType.school:
        return Icons.school_outlined;
      case TemplateType.college:
        return Icons.account_balance_outlined;
      case TemplateType.coaching:
        return Icons.menu_book_outlined;
      case TemplateType.kids:
        return Icons.child_care_rounded;
      case TemplateType.board:
        return Icons.workspace_premium_outlined;
    }
  }

  String _typeLabel(TemplateType type) {
    switch (type) {
      case TemplateType.school:
        return 'School';
      case TemplateType.college:
        return 'College';
      case TemplateType.coaching:
        return 'Coaching';
      case TemplateType.kids:
        return 'Kids';
      case TemplateType.board:
        return 'Board exam';
    }
  }
}
