import 'dart:math' as math;
import 'dart:ui';

import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_shape.dart';
import 'geometry_selection.dart';

class GeometryHitTester {
  const GeometryHitTester();

  GeometrySelection hit(GeometryDiagram diagram, Offset position) {
    final labelId = _hitLabel(diagram, position);
    if (labelId != null) return GeometrySelection.label(labelId);

    // A very small point core keeps the actual vertex easy to select while
    // leaving the visible area around that vertex available to angle/right-
    // angle marks. Dragging still uses the wider `_hitPoint` target below.
    final pointCoreId = _hitPoint(diagram, position, radius: 8);
    if (pointCoreId != null) return GeometrySelection.point(pointCoreId);

    // Marks are visual objects and may overlap point-label touch rectangles
    // (especially a right-angle square near labels such as A/B/C). Test them
    // before point labels and the wider point target so teachers can tap the
    // mark they can actually see.
    final markId = _hitMark(diagram, position);
    if (markId != null) return GeometrySelection.mark(markId);

    final pointLabelId = _hitPointLabel(diagram, position);
    if (pointLabelId != null) return GeometrySelection.point(pointLabelId);

    final pointId = _hitPoint(diagram, position);
    if (pointId != null) return GeometrySelection.point(pointId);

    final side = _hitSide(diagram, position);
    if (side != null) return side;

    final shapeId = _hitShape(diagram, position);
    if (shapeId != null) return GeometrySelection.shape(shapeId);

    return const GeometrySelection.none();
  }

  String? hitPoint(GeometryDiagram diagram, Offset position) =>
      _hitPoint(diagram, position);

  String? hitLabel(GeometryDiagram diagram, Offset position) =>
      _hitLabel(diagram, position);

  String? hitPointLabel(GeometryDiagram diagram, Offset position) =>
      _hitPointLabel(diagram, position);

  String? _hitPoint(
    GeometryDiagram diagram,
    Offset position, {
    double radius = 14,
  }) {
    for (final point in diagram.points.reversed) {
      if ((point.position - position).distance <= radius) return point.id;
    }
    return null;
  }

  String? _hitPointLabel(GeometryDiagram diagram, Offset position) {
    for (final point in diagram.points.reversed) {
      if (point.label.isEmpty) continue;
      final width = (point.label.length * point.labelFontSize * 0.68)
          .clamp(18.0, 120.0)
          .toDouble();
      final rect = Rect.fromLTWH(
        point.labelPosition.dx - 9,
        point.labelPosition.dy - 8,
        width + 18,
        point.labelFontSize * 1.7 + 16,
      );
      if (rect.contains(position)) return point.id;
    }
    return null;
  }

  String? _hitLabel(GeometryDiagram diagram, Offset position) {
    for (final label in diagram.labels.reversed) {
      final height = label.fontSize * 1.75;
      final rect = Rect.fromLTWH(
        label.position.dx - 10,
        label.position.dy - 10,
        _labelWidth(label) + 20,
        height + 20,
      );
      if (rect.contains(position)) return label.id;
    }
    return null;
  }

  GeometrySelection? _hitSide(GeometryDiagram diagram, Offset position) {
    final pointMap = diagram.pointMap;
    for (final shape in diagram.shapes.reversed) {
      for (var index = 0; ; index++) {
        final ids = GeometrySelection.sidePointIdsFor(shape, index);
        if (ids.length != 2) break;
        final a = pointMap[ids[0]]?.position;
        final b = pointMap[ids[1]]?.position;
        if (a == null || b == null) continue;
        if (_distanceToSegment(position, a, b) <= 10) {
          return GeometrySelection.side(shape.id, index);
        }
      }
    }
    return null;
  }

  String? _hitMark(GeometryDiagram diagram, Offset position) {
    final pointMap = diagram.pointMap;
    for (final mark in diagram.marks.reversed) {
      // `position` is the persisted visual anchor for marks created by the
      // existing model (vertex for angles, midpoint for segment marks, etc.).
      // Older data may contain Offset.zero, so only then derive a fallback.
      var anchor = mark.position;
      if (anchor == Offset.zero && mark.pointIds.isNotEmpty) {
        final points = mark.pointIds
            .map((id) => pointMap[id]?.position)
            .whereType<Offset>()
            .toList();
        if (points.isNotEmpty) {
          anchor = points.reduce((a, b) => a + b) / points.length.toDouble();
        }
      }
      if ((anchor - position).distance <= 16) return mark.id;
    }
    return null;
  }

  String? _hitShape(GeometryDiagram diagram, Offset position) {
    final pointMap = diagram.pointMap;
    for (final shape in diagram.shapes.reversed) {
      final points = shape.pointIds
          .map((id) => pointMap[id]?.position)
          .whereType<Offset>()
          .toList();
      if (points.isEmpty) continue;
      switch (shape.type) {
        case GeometryShapeType.circle:
        case GeometryShapeType.sphere:
        case GeometryShapeType.semicircle:
        case GeometryShapeType.cone:
          final radius = points.length >= 2
              ? (points[1] - points[0]).distance
              : shape.radius;
          if ((position - points.first).distance <= radius + 10) return shape.id;
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
          if (points.length >= 3) {
            final path = Path()..moveTo(points.first.dx, points.first.dy);
            for (final point in points.skip(1)) {
              path.lineTo(point.dx, point.dy);
            }
            path.close();
            if (path.contains(position)) return shape.id;
          }
        case GeometryShapeType.line:
        case GeometryShapeType.arrow:
        case GeometryShapeType.numberLine:
        case GeometryShapeType.coordinateAxes:
        case GeometryShapeType.cube:
        case GeometryShapeType.cuboid:
        case GeometryShapeType.cylinder:
          final bounds = _bounds(points).inflate(14);
          if (bounds.contains(position)) return shape.id;
      }
    }
    return null;
  }

  Rect _bounds(List<Offset> points) {
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0);
    final projection = a + ab * t;
    return (p - projection).distance;
  }

  double _labelWidth(GeometryLabel label) {
    return (label.text.length * label.fontSize * 0.62)
        .clamp(34, 260)
        .toDouble();
  }
}
