import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';

enum GeometrySelectionKind { none, point, label, shape, side, mark }

class GeometrySelection {
  final GeometrySelectionKind kind;
  final String? pointId;
  final String? labelId;
  final String? shapeId;
  final String? markId;
  final int? sideIndex;

  const GeometrySelection._({
    required this.kind,
    this.pointId,
    this.labelId,
    this.shapeId,
    this.markId,
    this.sideIndex,
  });

  const GeometrySelection.none() : this._(kind: GeometrySelectionKind.none);

  const GeometrySelection.point(String pointId)
    : this._(kind: GeometrySelectionKind.point, pointId: pointId);

  const GeometrySelection.label(String labelId)
    : this._(kind: GeometrySelectionKind.label, labelId: labelId);

  const GeometrySelection.shape(String shapeId)
    : this._(kind: GeometrySelectionKind.shape, shapeId: shapeId);

  const GeometrySelection.side(String shapeId, int sideIndex)
    : this._(
        kind: GeometrySelectionKind.side,
        shapeId: shapeId,
        sideIndex: sideIndex,
      );

  const GeometrySelection.mark(String markId)
    : this._(kind: GeometrySelectionKind.mark, markId: markId);

  GeometryPoint? point(GeometryDiagram diagram) {
    final id = pointId;
    if (id == null) return null;
    for (final point in diagram.points) {
      if (point.id == id) return point;
    }
    return null;
  }

  GeometryLabel? label(GeometryDiagram diagram) {
    final id = labelId;
    if (id == null) return null;
    for (final label in diagram.labels) {
      if (label.id == id) return label;
    }
    return null;
  }

  GeometryShape? shape(GeometryDiagram diagram) {
    final id = shapeId;
    if (id == null) return null;
    for (final shape in diagram.shapes) {
      if (shape.id == id) return shape;
    }
    return null;
  }

  GeometryMark? mark(GeometryDiagram diagram) {
    final id = markId;
    if (id == null) return null;
    for (final mark in diagram.marks) {
      if (mark.id == id) return mark;
    }
    return null;
  }

  List<String> sidePointIds(GeometryDiagram diagram) {
    if (kind != GeometrySelectionKind.side) return const [];
    final selectedShape = shape(diagram);
    final index = sideIndex;
    if (selectedShape == null || index == null) return const [];
    return GeometrySelection.sidePointIdsFor(selectedShape, index);
  }

  static List<String> sidePointIdsFor(GeometryShape shape, int index) {
    final ids = shape.pointIds;
    if (ids.length < 2) return const [];
    final segments = _segmentsForShape(shape);
    if (index < 0 || index >= segments.length) return const [];
    final pair = segments[index];
    return [ids[pair.$1], ids[pair.$2]];
  }

  static List<(int, int)> _segmentsForShape(GeometryShape shape) {
    final count = shape.pointIds.length;
    if (count < 2) return const [];
    switch (shape.type) {
      case GeometryShapeType.line:
      case GeometryShapeType.arrow:
      case GeometryShapeType.numberLine:
        return const [(0, 1)];
      case GeometryShapeType.coordinateAxes:
        return count >= 4 ? const [(1, 0), (2, 3)] : const [];
      case GeometryShapeType.circle:
      case GeometryShapeType.semicircle:
      case GeometryShapeType.sphere:
      case GeometryShapeType.cone:
        return const [];
      case GeometryShapeType.cube:
        if (count < 8) return const [];
        return const [
          (0, 1),
          (1, 2),
          (2, 3),
          (3, 0),
          (4, 5),
          (5, 6),
          (6, 7),
          (7, 4),
          (0, 4),
          (1, 5),
          (2, 6),
          (3, 7),
        ];
      case GeometryShapeType.cuboid:
      case GeometryShapeType.cylinder:
        if (count < 4) return const [];
        return const [(0, 1), (1, 2), (2, 3), (3, 0)];
      case GeometryShapeType.triangle:
      case GeometryShapeType.rightTriangle:
      case GeometryShapeType.square:
      case GeometryShapeType.rectangle:
      case GeometryShapeType.parallelogram:
      case GeometryShapeType.trapezium:
      case GeometryShapeType.rhombus:
      case GeometryShapeType.pentagon:
      case GeometryShapeType.hexagon:
      case GeometryShapeType.polygon:
        return [for (var i = 0; i < count; i++) (i, (i + 1) % count)];
    }
  }
}
