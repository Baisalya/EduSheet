import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

import '../application/geometry_recipe.dart';
import '../models/geometry_shape.dart';

class GeometryAddSheet extends StatefulWidget {
  const GeometryAddSheet({super.key});

  static Future<GeometryRecipe?> show(BuildContext context) {
    return showAdaptiveModalBottomSheet<GeometryRecipe>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.84,
        child: GeometryAddSheet(),
      ),
    );
  }

  @override
  State<GeometryAddSheet> createState() => _GeometryAddSheetState();
}

class _GeometryAddSheetState extends State<GeometryAddSheet> {
  final _searchController = TextEditingController();
  GeometryRecipeCategory? _category;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipes = _visibleRecipes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add to diagram',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose what you mean. EduSheet handles the points and marks.',
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search: right triangle, radius, parallel, cube…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'All',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final category in GeometryRecipeCategory.values)
                _CategoryChip(
                  label: _categoryLabel(category),
                  selected: _category == category,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: recipes.isEmpty
              ? Center(
                  child: Text(
                    'No geometry tool matches “$_query”.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisExtent: 118,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return _RecipeCard(
                      recipe: recipe,
                      onTap: () => Navigator.pop(context, recipe),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<GeometryRecipe> _visibleRecipes() {
    var recipes = GeometryRecipeCatalog.search(_query);
    final category = _category;
    if (category != null) {
      final allowedIds = GeometryRecipeCatalog.inCategory(
        category,
      ).map((recipe) => recipe.id).toSet();
      recipes = recipes
          .where((recipe) => allowedIds.contains(recipe.id))
          .toList();
    }
    final seen = <String>{};
    return [
      for (final recipe in recipes)
        if (seen.add(recipe.id)) recipe,
    ];
  }

  String _categoryLabel(GeometryRecipeCategory category) {
    return switch (category) {
      GeometryRecipeCategory.quick => 'Quick',
      GeometryRecipeCategory.lines => 'Lines & angles',
      GeometryRecipeCategory.triangles => 'Triangles',
      GeometryRecipeCategory.quadrilaterals => '4-sided',
      GeometryRecipeCategory.circles => 'Circles',
      GeometryRecipeCategory.coordinate => 'Graphs',
      GeometryRecipeCategory.solids => '3D',
      GeometryRecipeCategory.polygons => 'Polygons',
    };
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final GeometryRecipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(recipe),
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const Spacer(),
              Text(
                recipe.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                recipe.description,
                maxLines: 2,
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

  IconData _iconFor(GeometryRecipe recipe) {
    switch (recipe.id) {
      case 'angle':
        return Icons.architecture_rounded;
      case 'parallel_lines':
        return Icons.drag_handle_rounded;
      case 'circle_radius':
      case 'circle_diameter':
      case 'circle_chord':
      case 'circle_tangent':
        return Icons.circle_outlined;
    }
    return switch (recipe.baseShape) {
      GeometryShapeType.line => Icons.horizontal_rule_rounded,
      GeometryShapeType.arrow => Icons.arrow_forward_rounded,
      GeometryShapeType.triangle ||
      GeometryShapeType.rightTriangle => Icons.change_history_rounded,
      GeometryShapeType.square => Icons.crop_square,
      GeometryShapeType.rectangle ||
      GeometryShapeType.parallelogram ||
      GeometryShapeType.trapezium ||
      GeometryShapeType.rhombus => Icons.rectangle_outlined,
      GeometryShapeType.pentagon => Icons.pentagon_outlined,
      GeometryShapeType.hexagon => Icons.hexagon_outlined,
      GeometryShapeType.polygon => Icons.gesture_rounded,
      GeometryShapeType.circle ||
      GeometryShapeType.semicircle ||
      GeometryShapeType.sphere => Icons.circle_outlined,
      GeometryShapeType.coordinateAxes => Icons.add_rounded,
      GeometryShapeType.numberLine => Icons.linear_scale_rounded,
      GeometryShapeType.cube ||
      GeometryShapeType.cuboid => Icons.view_in_ar_rounded,
      GeometryShapeType.cylinder => Icons.view_column_outlined,
      GeometryShapeType.cone => Icons.change_history_rounded,
      null => Icons.auto_awesome_rounded,
    };
  }
}
