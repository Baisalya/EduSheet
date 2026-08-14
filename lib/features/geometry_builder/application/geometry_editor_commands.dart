import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';
import 'geometry_selection.dart';

class GeometryEditOutcome {
  final bool success;
  final String? message;
  final GeometrySelection? nextSelection;

  const GeometryEditOutcome.success([this.message, this.nextSelection])
    : success = true;

  const GeometryEditOutcome.failure(this.message)
    : success = false,
      nextSelection = null;
}

/// Executes teacher-facing geometry edits against the persisted document.
///
/// This service deliberately has no UI state. It translates semantic actions
/// such as "mark this side equal" into the existing point/shape/mark model so
/// the editor session and widgets never need to manipulate raw point lists.
class GeometryEditorCommands {
  final GeometryController document;

  const GeometryEditorCommands(this.document);

  GeometryDiagram get diagram => document.diagram;

  GeometryEditOutcome addSideMeasurement(
    GeometrySelection selection,
    String text,
  ) {
    final side = _selectedSidePoints(selection);
    if (side == null) {
      return const GeometryEditOutcome.failure('Tap the side you want to label.');
    }
    final value = text.trim();
    if (value.isEmpty) {
      return const GeometryEditOutcome.failure('Enter a side label first.');
    }

    final a = side.$1;
    final b = side.$2;
    final midpoint = (a.position + b.position) / 2;
    final direction = b.position - a.position;
    final length = direction.distance;
    final normal = length == 0
        ? const Offset(0, -1)
        : Offset(-direction.dy / length, direction.dx / length);
    final id = const Uuid().v4();
    final label = GeometryLabel(
      id: id,
      type: GeometryLabelType.side,
      text: value,
      position: _clamp(midpoint + normal * 18),
      fontSize: 14,
      isBold: true,
    );
    document.updateDiagram(
      (current) => current.copyWith(labels: [...current.labels, label]),
    );
    return GeometryEditOutcome.success(
      null,
      GeometrySelection.label(label.id),
    );
  }

  GeometryEditOutcome addAngleMeasurement(
    GeometrySelection selection,
    String text,
  ) {
    final context = _selectedVertexContext(selection);
    if (context == null) {
      return const GeometryEditOutcome.failure(
        'Tap a polygon corner before adding an angle.',
      );
    }
    final value = text.trim();
    if (value.isEmpty) {
      return const GeometryEditOutcome.failure('Enter an angle label first.');
    }

    final vertex = context.$1;
    final previous = context.$2;
    final next = context.$3;
    final p1 = _unit(previous.position - vertex.position);
    final p2 = _unit(next.position - vertex.position);
    var direction = p1 + p2;
    if (direction.distance < 0.001) direction = const Offset(0, -1);
    direction = _unit(direction);

    final label = GeometryLabel(
      id: const Uuid().v4(),
      type: GeometryLabelType.angle,
      text: value,
      position: _clamp(vertex.position + direction * 34),
      fontSize: 13,
    );
    final mark = GeometryMark(
      id: const Uuid().v4(),
      type: GeometryMarkType.angleArc,
      pointIds: [vertex.id, previous.id, next.id],
      position: vertex.position,
    );
    document.updateDiagram(
      (current) => current.copyWith(
        labels: [...current.labels, label],
        marks: [...current.marks, mark],
      ),
    );
    return GeometryEditOutcome.success(
      null,
      GeometrySelection.label(label.id),
    );
  }

  GeometryEditOutcome markSelectedSideEqual(GeometrySelection selection) {
    final side = _selectedSidePoints(selection);
    if (side == null) {
      return const GeometryEditOutcome.failure('Tap a side first.');
    }
    _addSegmentMark(GeometryMarkType.equalSideTick, side.$1, side.$2);
    return const GeometryEditOutcome.success('Equal-side mark added.');
  }

  GeometryEditOutcome markSelectedSideParallel(GeometrySelection selection) {
    final side = _selectedSidePoints(selection);
    if (side == null) {
      return const GeometryEditOutcome.failure('Tap a side first.');
    }
    _addSegmentMark(GeometryMarkType.parallelLine, side.$1, side.$2);
    return const GeometryEditOutcome.success('Parallel mark added.');
  }

  GeometryEditOutcome markSelectedVertexRightAngle(
    GeometrySelection selection,
  ) {
    final context = _selectedVertexContext(selection);
    if (context == null) {
      return const GeometryEditOutcome.failure(
        'Tap a polygon corner before marking a right angle.',
      );
    }
    final vertex = context.$1;
    final previous = context.$2;
    final next = context.$3;
    document.updateDiagram(
      (current) => current.copyWith(
        marks: [
          ...current.marks,
          GeometryMark(
            id: const Uuid().v4(),
            type: GeometryMarkType.rightAngle,
            pointIds: [vertex.id, previous.id, next.id],
            position: vertex.position,
          ),
        ],
      ),
    );
    return const GeometryEditOutcome.success('Right-angle mark added.');
  }

  GeometryEditOutcome addHeightFromSelectedVertex(
    GeometrySelection selection,
  ) {
    final point = selection.point(diagram);
    if (point == null) {
      return const GeometryEditOutcome.failure('Tap a triangle vertex first.');
    }

    GeometryShape? triangle;
    for (final shape in diagram.shapes) {
      if ((shape.type == GeometryShapeType.triangle ||
              shape.type == GeometryShapeType.rightTriangle) &&
          shape.pointIds.length == 3 &&
          shape.pointIds.contains(point.id)) {
        triangle = shape;
        break;
      }
    }
    if (triangle == null) {
      return const GeometryEditOutcome.failure(
        'Height is available after selecting a triangle vertex.',
      );
    }

    final otherIds = triangle.pointIds.where((id) => id != point.id).toList();
    final a = diagram.pointMap[otherIds[0]];
    final b = diagram.pointMap[otherIds[1]];
    if (a == null || b == null) {
      return const GeometryEditOutcome.failure('Triangle points are incomplete.');
    }

    final footPosition = _project(point.position, a.position, b.position);
    final foot = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: footPosition,
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, foot],
        marks: [
          ...current.marks,
          GeometryMark(
            id: const Uuid().v4(),
            type: GeometryMarkType.dashedHeightLine,
            pointIds: [point.id, foot.id],
            position: (point.position + footPosition) / 2,
          ),
          GeometryMark(
            id: const Uuid().v4(),
            type: GeometryMarkType.rightAngle,
            pointIds: [foot.id, point.id, a.id],
            position: footPosition,
          ),
        ],
      ),
    );
    return const GeometryEditOutcome.success('Perpendicular height added.');
  }

  GeometryEditOutcome addRadiusToSelectedCircle(GeometrySelection selection) {
    final shape = selection.shape(diagram);
    if (shape == null ||
        shape.type != GeometryShapeType.circle ||
        shape.pointIds.length < 2) {
      return const GeometryEditOutcome.failure('Select a circle first.');
    }
    final center = diagram.pointMap[shape.pointIds[0]];
    final edge = diagram.pointMap[shape.pointIds[1]];
    if (center == null || edge == null) {
      return const GeometryEditOutcome.failure('Circle points are incomplete.');
    }
    _addSegmentMark(GeometryMarkType.radiusLine, center, edge);
    return const GeometryEditOutcome.success('Radius line added.');
  }

  GeometryEditOutcome addCoordinatePoint({
    required double x,
    required double y,
    required String label,
  }) {
    GeometryShape? axes;
    for (final shape in diagram.shapes) {
      if (shape.type == GeometryShapeType.coordinateAxes &&
          shape.pointIds.length >= 4) {
        axes = shape;
        break;
      }
    }
    if (axes == null) {
      return const GeometryEditOutcome.failure('Add coordinate axes first.');
    }

    final points = axes.pointIds.map((id) => diagram.pointMap[id]).toList();
    if (points.any((point) => point == null)) {
      return const GeometryEditOutcome.failure('Coordinate axes are incomplete.');
    }
    final top = points[0]!.position;
    final bottom = points[1]!.position;
    final left = points[2]!.position;
    final right = points[3]!.position;
    final origin = Offset(top.dx, left.dy);
    const units = 20.0;
    final position = origin + Offset(x * units, -y * units);
    final minX = math.min(left.dx, right.dx);
    final maxX = math.max(left.dx, right.dx);
    final minY = math.min(top.dy, bottom.dy);
    final maxY = math.max(top.dy, bottom.dy);
    if (position.dx < minX ||
        position.dx > maxX ||
        position.dy < minY ||
        position.dy > maxY) {
      return const GeometryEditOutcome.failure(
        'That coordinate is outside the visible axes. Use a smaller value.',
      );
    }

    final point = GeometryPoint(
      id: const Uuid().v4(),
      label: label.trim().isEmpty ? 'P' : label.trim(),
      position: position,
    );
    final mark = GeometryMark(
      id: const Uuid().v4(),
      type: GeometryMarkType.centerPoint,
      pointIds: [point.id],
      position: position,
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, point],
        marks: [...current.marks, mark],
      ),
    );
    return GeometryEditOutcome.success(
      'Point ${point.label} added at ($x, $y).',
      GeometrySelection.point(point.id),
    );
  }

  GeometryEditOutcome duplicateSelectedShape(GeometrySelection selection) {
    final shape = selection.shape(diagram);
    if (shape == null) {
      return const GeometryEditOutcome.failure('Select a shape first.');
    }

    final pointMap = diagram.pointMap;
    final idMap = <String, String>{};
    final newPoints = <GeometryPoint>[];
    for (final pointId in shape.pointIds) {
      final point = pointMap[pointId];
      if (point == null) continue;
      final id = const Uuid().v4();
      idMap[point.id] = id;
      newPoints.add(
        GeometryPoint(
          id: id,
          label: point.label,
          position: _clamp(point.position + const Offset(24, 24)),
          labelOffset: point.labelOffset,
          labelFontSize: point.labelFontSize,
          labelRotation: point.labelRotation,
          labelBold: point.labelBold,
        ),
      );
    }

    if (newPoints.length != shape.pointIds.length) {
      return const GeometryEditOutcome.failure(
        'This shape has missing points and cannot be duplicated safely.',
      );
    }

    final newShape = GeometryShape(
      id: const Uuid().v4(),
      type: shape.type,
      pointIds: shape.pointIds.map((id) => idMap[id]!).toList(),
      radius: shape.radius,
    );
    final copiedMarks = <GeometryMark>[];
    for (final mark in diagram.marks) {
      if (mark.pointIds.isEmpty || !mark.pointIds.every(idMap.containsKey)) {
        continue;
      }
      copiedMarks.add(
        GeometryMark(
          id: const Uuid().v4(),
          type: mark.type,
          pointIds: mark.pointIds.map((id) => idMap[id]!).toList(),
          position: _clamp(mark.position + const Offset(24, 24)),
        ),
      );
    }
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, ...newPoints],
        shapes: [...current.shapes, newShape],
        marks: [...current.marks, ...copiedMarks],
      ),
    );
    return GeometryEditOutcome.success(
      'Shape duplicated.',
      GeometrySelection.shape(newShape.id),
    );
  }

  GeometryEditOutcome deleteSelected(GeometrySelection selection) {
    switch (selection.kind) {
      case GeometrySelectionKind.none:
        return const GeometryEditOutcome.failure('Select something to delete.');
      case GeometrySelectionKind.label:
        final id = selection.labelId!;
        document.updateDiagram(
          (current) => current.copyWith(
            labels: current.labels.where((label) => label.id != id).toList(),
          ),
          clearSelection: true,
        );
      case GeometrySelectionKind.mark:
        final id = selection.markId!;
        document.updateDiagram(
          (current) => current.copyWith(
            marks: current.marks.where((mark) => mark.id != id).toList(),
          ),
          clearSelection: true,
        );
      case GeometrySelectionKind.side:
        return const GeometryEditOutcome.failure(
          'A side belongs to its shape. Select the whole shape to delete it.',
        );
      case GeometrySelectionKind.point:
        final id = selection.pointId!;
        if (diagram.shapes.any((shape) => shape.pointIds.contains(id))) {
          return const GeometryEditOutcome.failure(
            'This point is part of a shape. Delete the shape instead.',
          );
        }
        document.updateDiagram(
          (current) => current.copyWith(
            points: current.points.where((point) => point.id != id).toList(),
            marks: current.marks
                .where((mark) => !mark.pointIds.contains(id))
                .toList(),
          ),
          clearSelection: true,
        );
      case GeometrySelectionKind.shape:
        final shape = selection.shape(diagram);
        if (shape == null) {
          return const GeometryEditOutcome.failure('Shape no longer exists.');
        }
        final pointIds = shape.pointIds.toSet();
        final pointsUsedElsewhere = <String>{};
        for (final other in diagram.shapes) {
          if (other.id == shape.id) continue;
          pointsUsedElsewhere.addAll(other.pointIds);
        }
        final removablePoints = pointIds.difference(pointsUsedElsewhere);
        document.updateDiagram(
          (current) => current.copyWith(
            shapes: current.shapes.where((item) => item.id != shape.id).toList(),
            points: current.points
                .where((point) => !removablePoints.contains(point.id))
                .toList(),
            marks: current.marks
                .where((mark) => !mark.pointIds.any(removablePoints.contains))
                .toList(),
          ),
          clearSelection: true,
        );
    }
    return const GeometryEditOutcome.success(
      'Deleted.',
      GeometrySelection.none(),
    );
  }

  (GeometryPoint, GeometryPoint)? _selectedSidePoints(
    GeometrySelection selection,
  ) {
    final ids = selection.sidePointIds(diagram);
    if (ids.length != 2) return null;
    final a = diagram.pointMap[ids[0]];
    final b = diagram.pointMap[ids[1]];
    if (a == null || b == null) return null;
    return (a, b);
  }

  (GeometryPoint, GeometryPoint, GeometryPoint)? _selectedVertexContext(
    GeometrySelection selection,
  ) {
    final vertex = selection.point(diagram);
    if (vertex == null) return null;

    for (final shape in diagram.shapes) {
      final ids = shape.pointIds;
      if (ids.length < 3 || !ids.contains(vertex.id)) continue;
      if (shape.type == GeometryShapeType.circle ||
          shape.type == GeometryShapeType.semicircle ||
          shape.type == GeometryShapeType.sphere ||
          shape.type == GeometryShapeType.cone ||
          shape.type == GeometryShapeType.coordinateAxes ||
          shape.type == GeometryShapeType.cylinder ||
          shape.type == GeometryShapeType.cuboid ||
          shape.type == GeometryShapeType.cube) {
        continue;
      }
      final index = ids.indexOf(vertex.id);
      final previous = diagram.pointMap[ids[(index - 1 + ids.length) % ids.length]];
      final next = diagram.pointMap[ids[(index + 1) % ids.length]];
      if (previous != null && next != null) return (vertex, previous, next);
    }

    final neighbours = <GeometryPoint>[];
    for (final shape in diagram.shapes) {
      if (shape.pointIds.length != 2 || !shape.pointIds.contains(vertex.id)) {
        continue;
      }
      final otherId = shape.pointIds.firstWhere((id) => id != vertex.id);
      final other = diagram.pointMap[otherId];
      if (other != null && neighbours.every((item) => item.id != other.id)) {
        neighbours.add(other);
      }
    }
    if (neighbours.length >= 2) return (vertex, neighbours[0], neighbours[1]);
    return null;
  }

  void _addSegmentMark(
    GeometryMarkType type,
    GeometryPoint a,
    GeometryPoint b,
  ) {
    document.updateDiagram(
      (current) => current.copyWith(
        marks: [
          ...current.marks,
          GeometryMark(
            id: const Uuid().v4(),
            type: type,
            pointIds: [a.id, b.id],
            position: (a.position + b.position) / 2,
          ),
        ],
      ),
    );
  }

  Offset _project(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return a;
    final ap = p - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared;
    return a + ab * t;
  }

  Offset _unit(Offset value) {
    final length = value.distance;
    if (length == 0) return Offset.zero;
    return value / length;
  }

  Offset _clamp(Offset position) => Offset(
    position.dx
        .clamp(8.0, math.max(8.0, diagram.canvasSize.width - 8))
        .toDouble(),
    position.dy
        .clamp(8.0, math.max(8.0, diagram.canvasSize.height - 8))
        .toDouble(),
  );
}
