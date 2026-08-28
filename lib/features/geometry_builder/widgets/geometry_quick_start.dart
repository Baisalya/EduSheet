import 'package:flutter/material.dart';

import '../application/geometry_recipe.dart';

class GeometryQuickStart extends StatelessWidget {
  final ValueChanged<GeometryRecipe> onRecipe;
  final VoidCallback onBrowseAll;
  final bool compact;

  const GeometryQuickStart({
    super.key,
    required this.onRecipe,
    required this.onBrowseAll,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipes = GeometryRecipeCatalog.quick;
    if (compact) {
      return SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: recipes.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            if (index == recipes.length) {
              return ActionChip(
                avatar: const Icon(Icons.apps_rounded, size: 18),
                label: const Text('All'),
                onPressed: onBrowseAll,
              );
            }
            final recipe = recipes[index];
            return ActionChip(
              avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(recipe.label),
              onPressed: () => onRecipe(recipe),
            );
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'Quick start',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Start with a teacher-ready construction, then edit it directly.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final recipe in recipes)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.auto_awesome_rounded, size: 20),
                title: Text(
                  recipe.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onRecipe(recipe),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onBrowseAll,
          icon: const Icon(Icons.apps_rounded),
          label: const Text('Browse all geometry'),
        ),
      ],
    );
  }
}
