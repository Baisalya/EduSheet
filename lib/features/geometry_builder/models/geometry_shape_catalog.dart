import 'package:flutter/material.dart';

import 'geometry_shape.dart';

enum GeometryShapeCategory {
  lines,
  triangles,
  quadrilaterals,
  polygons,
  circles,
  coordinate,
  solids,
}

extension GeometryShapeCategoryLabel on GeometryShapeCategory {
  String get label {
    switch (this) {
      case GeometryShapeCategory.lines:
        return 'Lines';
      case GeometryShapeCategory.triangles:
        return 'Triangles';
      case GeometryShapeCategory.quadrilaterals:
        return '4-sided';
      case GeometryShapeCategory.polygons:
        return 'Polygons';
      case GeometryShapeCategory.circles:
        return 'Circles';
      case GeometryShapeCategory.coordinate:
        return 'Graphs';
      case GeometryShapeCategory.solids:
        return '3D';
    }
  }
}

class GeometryShapeCatalogEntry {
  final GeometryShapeType type;
  final GeometryShapeCategory category;
  final String label;
  final String description;
  final IconData icon;

  const GeometryShapeCatalogEntry({
    required this.type,
    required this.category,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class GeometryShapeCatalog {
  const GeometryShapeCatalog._();

  static const all = <GeometryShapeCatalogEntry>[
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.line,
      category: GeometryShapeCategory.lines,
      label: 'Line',
      description: 'Straight line segment',
      icon: Icons.horizontal_rule_rounded,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.arrow,
      category: GeometryShapeCategory.lines,
      label: 'Arrow',
      description: 'Directed line / vector',
      icon: Icons.arrow_forward_rounded,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.triangle,
      category: GeometryShapeCategory.triangles,
      label: 'Triangle',
      description: 'General triangle with A, B, C points',
      icon: Icons.change_history_rounded,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.rightTriangle,
      category: GeometryShapeCategory.triangles,
      label: 'Right triangle',
      description: 'Triangle with a right-angle mark',
      icon: Icons.signal_cellular_4_bar,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.square,
      category: GeometryShapeCategory.quadrilaterals,
      label: 'Square',
      description: 'Four equal sides',
      icon: Icons.crop_square,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.rectangle,
      category: GeometryShapeCategory.quadrilaterals,
      label: 'Rectangle',
      description: 'Rectangular figure',
      icon: Icons.rectangle_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.parallelogram,
      category: GeometryShapeCategory.quadrilaterals,
      label: 'Parallelogram',
      description: 'Opposite sides parallel',
      icon: Icons.view_agenda_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.trapezium,
      category: GeometryShapeCategory.quadrilaterals,
      label: 'Trapezium',
      description: 'One pair of parallel sides',
      icon: Icons.filter_none,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.rhombus,
      category: GeometryShapeCategory.quadrilaterals,
      label: 'Rhombus',
      description: 'Diamond-shaped quadrilateral',
      icon: Icons.diamond_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.pentagon,
      category: GeometryShapeCategory.polygons,
      label: 'Pentagon',
      description: 'Five-sided polygon',
      icon: Icons.pentagon_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.hexagon,
      category: GeometryShapeCategory.polygons,
      label: 'Hexagon',
      description: 'Six-sided polygon',
      icon: Icons.hexagon_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.polygon,
      category: GeometryShapeCategory.polygons,
      label: 'Polygon',
      description: 'Editable polygon starting shape',
      icon: Icons.gesture,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.circle,
      category: GeometryShapeCategory.circles,
      label: 'Circle',
      description: 'Circle with editable radius points',
      icon: Icons.circle_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.semicircle,
      category: GeometryShapeCategory.circles,
      label: 'Semicircle',
      description: 'Half-circle figure',
      icon: Icons.timelapse,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.coordinateAxes,
      category: GeometryShapeCategory.coordinate,
      label: 'Coordinate axes',
      description: 'X and Y axes for graph questions',
      icon: Icons.add,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.numberLine,
      category: GeometryShapeCategory.coordinate,
      label: 'Number line',
      description: 'Horizontal number-line base',
      icon: Icons.linear_scale,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.cube,
      category: GeometryShapeCategory.solids,
      label: 'Cube',
      description: '3D cube diagram',
      icon: Icons.view_in_ar,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.cuboid,
      category: GeometryShapeCategory.solids,
      label: 'Cuboid',
      description: 'Rectangular 3D solid',
      icon: Icons.inventory_2_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.cylinder,
      category: GeometryShapeCategory.solids,
      label: 'Cylinder',
      description: 'Cylindrical solid',
      icon: Icons.view_column_outlined,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.cone,
      category: GeometryShapeCategory.solids,
      label: 'Cone',
      description: 'Conical solid',
      icon: Icons.change_history_rounded,
    ),
    GeometryShapeCatalogEntry(
      type: GeometryShapeType.sphere,
      category: GeometryShapeCategory.solids,
      label: 'Sphere',
      description: 'Spherical solid',
      icon: Icons.language,
    ),
  ];

  static List<GeometryShapeCatalogEntry> inCategory(
    GeometryShapeCategory category,
  ) {
    return all.where((item) => item.category == category).toList();
  }

  static GeometryShapeCatalogEntry byType(GeometryShapeType type) {
    return all.firstWhere((item) => item.type == type);
  }
}
