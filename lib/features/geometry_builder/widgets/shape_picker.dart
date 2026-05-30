import 'package:flutter/material.dart';

import '../models/geometry_shape.dart';

class ShapePicker extends StatelessWidget {
  final ValueChanged<GeometryShapeType> onSelected;

  const ShapePicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final shapes = <_ShapeChoice>[
      _ShapeChoice('Line', Icons.horizontal_rule, GeometryShapeType.line),
      _ShapeChoice('Arrow', Icons.arrow_forward, GeometryShapeType.arrow),
      _ShapeChoice(
        'Triangle',
        Icons.change_history,
        GeometryShapeType.triangle,
      ),
      _ShapeChoice(
        'Right tri.',
        Icons.signal_cellular_4_bar,
        GeometryShapeType.rightTriangle,
      ),
      _ShapeChoice('Square', Icons.crop_square, GeometryShapeType.square),
      _ShapeChoice(
        'Rectangle',
        Icons.rectangle_outlined,
        GeometryShapeType.rectangle,
      ),
      _ShapeChoice('Circle', Icons.circle_outlined, GeometryShapeType.circle),
      _ShapeChoice('Semi', Icons.timelapse, GeometryShapeType.semicircle),
      _ShapeChoice(
        'Parallelogram',
        Icons.view_agenda_outlined,
        GeometryShapeType.parallelogram,
      ),
      _ShapeChoice('Trapezium', Icons.filter_none, GeometryShapeType.trapezium),
      _ShapeChoice(
        'Rhombus',
        Icons.diamond_outlined,
        GeometryShapeType.rhombus,
      ),
      _ShapeChoice(
        'Pentagon',
        Icons.pentagon_outlined,
        GeometryShapeType.pentagon,
      ),
      _ShapeChoice(
        'Hexagon',
        Icons.hexagon_outlined,
        GeometryShapeType.hexagon,
      ),
      _ShapeChoice('Axes', Icons.add, GeometryShapeType.coordinateAxes),
      _ShapeChoice(
        'Number line',
        Icons.linear_scale,
        GeometryShapeType.numberLine,
      ),
      _ShapeChoice('Cube', Icons.view_in_ar, GeometryShapeType.cube),
      _ShapeChoice(
        'Cuboid',
        Icons.inventory_2_outlined,
        GeometryShapeType.cuboid,
      ),
      _ShapeChoice(
        'Cylinder',
        Icons.view_column_outlined,
        GeometryShapeType.cylinder,
      ),
      _ShapeChoice('Cone', Icons.change_history, GeometryShapeType.cone),
      _ShapeChoice('Sphere', Icons.language, GeometryShapeType.sphere),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 680
            ? 6
            : width >= 520
            ? 5
            : width >= 360
            ? 4
            : 3;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: width < 360 ? 0.98 : 1.08,
          ),
          itemCount: shapes.length,
          itemBuilder: (context, index) {
            final shape = shapes[index];
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(shape.type),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      shape.icon,
                      size: width < 360 ? 20 : 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        shape.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: width < 360 ? 10 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ShapeChoice {
  final String label;
  final IconData icon;
  final GeometryShapeType type;

  const _ShapeChoice(this.label, this.icon, this.type);
}
