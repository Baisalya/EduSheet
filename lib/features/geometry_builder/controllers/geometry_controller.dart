import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';

enum GeometryBuilderMode { shapes, draw, labels, marks, export }

class GeometryController extends ChangeNotifier {
  GeometryDiagram _diagram;
  GeometryBuilderMode _mode = GeometryBuilderMode.shapes;
  final List<GeometryDiagram> _undoStack = [];
  final List<GeometryDiagram> _redoStack = [];

  GeometryController({GeometryDiagram? initialDiagram})
    : _diagram =
          initialDiagram ??
          GeometryDiagram(id: const Uuid().v4(), name: 'Geometry Diagram');

  GeometryDiagram get diagram => _diagram;
  GeometryBuilderMode get mode => _mode;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  set mode(GeometryBuilderMode value) {
    _mode = value;
    notifyListeners();
  }

  void loadTemplate(GeometryShapeType type) {
    _commit();
    final generated = _template(type);
    _diagram = _diagram.copyWith(
      name: _shapeTitle(type),
      points: generated.points,
      shapes: generated.shapes,
      labels: generated.labels,
      marks: generated.marks,
    );
    notifyListeners();
  }

  void addPoint(Offset position) {
    _commit();
    final points = [..._diagram.points];
    final snapped = _diagram.snapToGrid ? _snap(position) : position;
    points.add(
      GeometryPoint(
        id: const Uuid().v4(),
        label: _labelForIndex(points.length),
        position: snapped,
      ),
    );

    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: points.length == 2
          ? GeometryShapeType.line
          : points.length == 3
          ? GeometryShapeType.triangle
          : GeometryShapeType.polygon,
      pointIds: points.map((point) => point.id).toList(),
    );

    _diagram = _diagram.copyWith(points: points, shapes: [shape]);
    notifyListeners();
  }

  void movePoint(String pointId, Offset position) {
    final snapped = _diagram.snapToGrid ? _snap(position) : position;
    _diagram = _diagram.copyWith(
      points: _diagram.points
          .map(
            (point) =>
                point.id == pointId ? point.copyWith(position: snapped) : point,
          )
          .toList(),
    );
    notifyListeners();
  }

  void beginDrag() {
    _commit();
  }

  void addLabel(GeometryLabelType type, String text, {Offset? position}) {
    _commit();
    final labels = [
      ..._diagram.labels,
      GeometryLabel(
        id: const Uuid().v4(),
        type: type,
        text: text,
        position: position ?? const Offset(170, 120),
      ),
    ];
    _diagram = _diagram.copyWith(labels: labels);
    notifyListeners();
  }

  void moveLabel(String labelId, Offset position) {
    _diagram = _diagram.copyWith(
      labels: _diagram.labels
          .map(
            (label) => label.id == labelId
                ? label.copyWith(position: position)
                : label,
          )
          .toList(),
    );
    notifyListeners();
  }

  void addMark(GeometryMarkType type) {
    _commit();
    final mark = GeometryMark(
      id: const Uuid().v4(),
      type: type,
      pointIds: _diagram.points.take(3).map((point) => point.id).toList(),
      position: _diagram.points.isNotEmpty
          ? _diagram.points.first.position
          : const Offset(170, 120),
    );
    _diagram = _diagram.copyWith(marks: [..._diagram.marks, mark]);
    notifyListeners();
  }

  void duplicate() {
    _commit();
    final duplicatedPoints = <GeometryPoint>[];
    final idMap = <String, String>{};
    for (final point in _diagram.points) {
      final id = const Uuid().v4();
      idMap[point.id] = id;
      duplicatedPoints.add(
        GeometryPoint(
          id: id,
          label: point.label,
          position: point.position + const Offset(18, 18),
        ),
      );
    }
    final duplicatedShapes = _diagram.shapes
        .map(
          (shape) => GeometryShape(
            id: const Uuid().v4(),
            type: shape.type,
            pointIds: shape.pointIds.map((id) => idMap[id] ?? id).toList(),
            radius: shape.radius,
          ),
        )
        .toList();
    final duplicatedLabels = _diagram.labels
        .map(
          (label) => GeometryLabel(
            id: const Uuid().v4(),
            type: label.type,
            text: label.text,
            position: label.position + const Offset(18, 18),
          ),
        )
        .toList();
    _diagram = _diagram.copyWith(
      points: [..._diagram.points, ...duplicatedPoints],
      shapes: [..._diagram.shapes, ...duplicatedShapes],
      labels: [..._diagram.labels, ...duplicatedLabels],
    );
    notifyListeners();
  }

  void clear() {
    _commit();
    _diagram = _diagram.copyWith(points: [], shapes: [], labels: [], marks: []);
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_diagram);
    _diagram = _undoStack.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_diagram);
    _diagram = _redoStack.removeLast();
    notifyListeners();
  }

  void toggleGrid() {
    _commit();
    _diagram = _diagram.copyWith(showGrid: !_diagram.showGrid);
    notifyListeners();
  }

  void toggleSnap() {
    _commit();
    _diagram = _diagram.copyWith(snapToGrid: !_diagram.snapToGrid);
    notifyListeners();
  }

  void toggleTransparentBackground() {
    _commit();
    _diagram = _diagram.copyWith(
      transparentBackground: !_diagram.transparentBackground,
    );
    notifyListeners();
  }

  void _commit() {
    _undoStack.add(_diagram);
    _redoStack.clear();
  }

  Offset _snap(Offset position) {
    const grid = 20.0;
    return Offset(
      (position.dx / grid).round() * grid,
      (position.dy / grid).round() * grid,
    );
  }

  GeometryDiagram _template(GeometryShapeType type) {
    final points = _templatePoints(type);
    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: type,
      pointIds: points.map((point) => point.id).toList(),
      radius: type == GeometryShapeType.sphere ? 62 : 56,
    );
    final marks = type == GeometryShapeType.rightTriangle
        ? [
            GeometryMark(
              id: const Uuid().v4(),
              type: GeometryMarkType.rightAngle,
              pointIds: points.take(3).map((point) => point.id).toList(),
              position: points.first.position,
            ),
          ]
        : <GeometryMark>[];
    return _diagram.copyWith(
      points: points,
      shapes: [shape],
      labels: _autoLabels(type, points),
      marks: marks,
    );
  }

  List<GeometryPoint> _templatePoints(GeometryShapeType type) {
    final coords = switch (type) {
      GeometryShapeType.line ||
      GeometryShapeType.arrow ||
      GeometryShapeType.numberLine => const [Offset(80, 120), Offset(280, 120)],
      GeometryShapeType.triangle => const [
        Offset(180, 48),
        Offset(72, 196),
        Offset(292, 196),
      ],
      GeometryShapeType.rightTriangle => const [
        Offset(84, 196),
        Offset(84, 68),
        Offset(280, 196),
      ],
      GeometryShapeType.square => const [
        Offset(104, 64),
        Offset(256, 64),
        Offset(256, 216),
        Offset(104, 216),
      ],
      GeometryShapeType.rectangle ||
      GeometryShapeType.cuboid ||
      GeometryShapeType.cylinder => const [
        Offset(76, 76),
        Offset(284, 76),
        Offset(284, 196),
        Offset(76, 196),
      ],
      GeometryShapeType.circle ||
      GeometryShapeType.semicircle ||
      GeometryShapeType.cone ||
      GeometryShapeType.sphere => const [Offset(180, 128), Offset(236, 128)],
      GeometryShapeType.parallelogram => const [
        Offset(116, 76),
        Offset(288, 76),
        Offset(244, 196),
        Offset(72, 196),
      ],
      GeometryShapeType.trapezium => const [
        Offset(132, 76),
        Offset(228, 76),
        Offset(292, 196),
        Offset(68, 196),
      ],
      GeometryShapeType.rhombus => const [
        Offset(180, 48),
        Offset(292, 132),
        Offset(180, 216),
        Offset(68, 132),
      ],
      GeometryShapeType.pentagon => _regularPolygon(5),
      GeometryShapeType.hexagon => _regularPolygon(6),
      GeometryShapeType.coordinateAxes => const [
        Offset(180, 32),
        Offset(180, 220),
        Offset(42, 126),
        Offset(318, 126),
      ],
      GeometryShapeType.cube => const [
        Offset(88, 92),
        Offset(220, 92),
        Offset(220, 216),
        Offset(88, 216),
        Offset(140, 48),
        Offset(272, 48),
        Offset(272, 172),
        Offset(140, 172),
      ],
      GeometryShapeType.polygon => _regularPolygon(5),
    };

    return [
      for (var i = 0; i < coords.length; i++)
        GeometryPoint(
          id: const Uuid().v4(),
          label: _labelForIndex(i),
          position: coords[i],
        ),
    ];
  }

  List<GeometryLabel> _autoLabels(
    GeometryShapeType type,
    List<GeometryPoint> points,
  ) {
    if (points.isEmpty) return const [];
    final labels = <GeometryLabel>[];
    if (points.length >= 2) {
      labels.add(
        GeometryLabel(
          id: const Uuid().v4(),
          type: GeometryLabelType.side,
          text: '${points[0].label}${points[1].label} = 5 cm',
          position:
              (points[0].position + points[1].position) / 2 +
              const Offset(0, -18),
        ),
      );
    }
    if (type == GeometryShapeType.circle || type == GeometryShapeType.sphere) {
      labels.add(
        GeometryLabel(
          id: const Uuid().v4(),
          type: GeometryLabelType.radius,
          text: 'r = 4 cm',
          position: points.first.position + const Offset(20, -52),
        ),
      );
    }
    if (type == GeometryShapeType.triangle ||
        type == GeometryShapeType.rightTriangle) {
      labels.add(
        GeometryLabel(
          id: const Uuid().v4(),
          type: GeometryLabelType.angle,
          text: 'angle A = 60 deg',
          position: points.first.position + const Offset(8, -8),
        ),
      );
    }
    return labels;
  }

  List<Offset> _regularPolygon(int sides) {
    const center = Offset(180, 132);
    const radius = 86.0;
    return [
      for (var i = 0; i < sides; i++)
        Offset(
          center.dx +
              math.cos(-math.pi / 2 + (math.pi * 2 * i / sides)) * radius,
          center.dy +
              math.sin(-math.pi / 2 + (math.pi * 2 * i / sides)) * radius,
        ),
    ];
  }

  String _labelForIndex(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < letters.length) return letters[index];
    return 'P${index + 1}';
  }

  String _shapeTitle(GeometryShapeType type) {
    final words = type.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
