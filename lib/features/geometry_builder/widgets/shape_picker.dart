import 'package:flutter/material.dart';

import '../models/geometry_shape.dart';
import '../models/geometry_shape_catalog.dart';

class ShapePicker extends StatefulWidget {
  final ValueChanged<GeometryShapeType> onSelected;

  const ShapePicker({super.key, required this.onSelected});

  @override
  State<ShapePicker> createState() => _ShapePickerState();
}

class _ShapePickerState extends State<ShapePicker> {
  GeometryShapeCategory? _category;

  @override
  Widget build(BuildContext context) {
    final entries = _category == null
        ? GeometryShapeCatalog.all
        : GeometryShapeCatalog.inCategory(_category!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final category in GeometryShapeCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 760
                  ? 5
                  : width >= 520
                      ? 4
                      : width >= 340
                          ? 3
                          : 2;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: width < 380 ? 1.1 : 1.25,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _ShapeCard(
                    entry: entry,
                    onTap: () => widget.onSelected(entry.type),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShapeCard extends StatelessWidget {
  final GeometryShapeCatalogEntry entry;
  final VoidCallback onTap;

  const _ShapeCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                entry.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.description,
                maxLines: 2,
                textAlign: TextAlign.center,
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
