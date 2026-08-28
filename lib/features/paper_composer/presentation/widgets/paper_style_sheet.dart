import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/application/paper_template_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_editor_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_style_preview.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _StyleFilter {
  recommended,
  school,
  board,
  college,
  coaching,
  primary,
  custom,
}

class PaperStyleSheet extends ConsumerStatefulWidget {
  final String selectedTemplateId;

  const PaperStyleSheet({super.key, required this.selectedTemplateId});

  static Future<void> show(
    BuildContext context, {
    required String selectedTemplateId,
  }) async {
    await showAdaptiveModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PaperStyleSheet(selectedTemplateId: selectedTemplateId),
      ),
    );
  }

  @override
  ConsumerState<PaperStyleSheet> createState() => _PaperStyleSheetState();
}

class _PaperStyleSheetState extends ConsumerState<PaperStyleSheet> {
  _StyleFilter _filter = _StyleFilter.recommended;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templateProvider);
    final all = state.all;
    final selectable = state.selectable;
    final selected = PaperTemplateResolver.resolve(
      widget.selectedTemplateId,
      all,
    );
    final visible = selectable.where(_matchesFilter).toList(growable: false);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paper appearance',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose by purpose. Your questions and paper details stay unchanged.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final createdId = await PaperStyleEditorSheet.show(
                    context,
                    selected,
                  );
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
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            children: [
              for (final filter in _StyleFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? _EmptyFilter(filter: _filter)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 284,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final template = visible[index];
                    final isSelected = template.id == selected.id;
                    final preset = PaperStyleCatalog.presetForId(template.id);
                    return _PaperStyleCard(
                      template: template,
                      selected: isSelected,
                      description:
                          preset?.description ??
                          'Your saved custom paper style.',
                      bestFor: preset?.bestFor ?? 'Custom printing preferences',
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

  bool _matchesFilter(PaperTemplate template) {
    final preset = PaperStyleCatalog.presetForId(template.id);
    switch (_filter) {
      case _StyleFilter.recommended:
        return preset?.recommended == true ||
            template.id == widget.selectedTemplateId;
      case _StyleFilter.school:
        return preset?.category == PaperStyleCategory.school;
      case _StyleFilter.board:
        return preset?.category == PaperStyleCategory.board;
      case _StyleFilter.college:
        return preset?.category == PaperStyleCategory.college;
      case _StyleFilter.coaching:
        return preset?.category == PaperStyleCategory.coaching;
      case _StyleFilter.primary:
        return preset?.category == PaperStyleCategory.primary;
      case _StyleFilter.custom:
        return preset == null;
    }
  }

  static String _filterLabel(_StyleFilter filter) {
    switch (filter) {
      case _StyleFilter.recommended:
        return 'Recommended';
      case _StyleFilter.school:
        return 'School';
      case _StyleFilter.board:
        return 'Board-style';
      case _StyleFilter.college:
        return 'College';
      case _StyleFilter.coaching:
        return 'Mock test';
      case _StyleFilter.primary:
        return 'Primary';
      case _StyleFilter.custom:
        return 'My styles';
    }
  }
}

class _PaperStyleCard extends StatelessWidget {
  final PaperTemplate template;
  final bool selected;
  final String description;
  final String bestFor;
  final VoidCallback onTap;

  const _PaperStyleCard({
    required this.template,
    required this.selected,
    required this.description,
    required this.bestFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
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
              Stack(
                children: [
                  PaperStylePreview(template: template, height: 156),
                  if (selected)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    template.paperSize.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                bestFor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final _StyleFilter filter;

  const _EmptyFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          filter == _StyleFilter.custom
              ? 'No custom styles yet. Choose a style and tap Customize to save one.'
              : 'No styles are available in this category.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
