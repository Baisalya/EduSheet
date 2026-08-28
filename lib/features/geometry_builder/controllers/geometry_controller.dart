import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../application/geometry_recipe_factory.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';

/// Owns only the persisted geometry document and its undo/redo history.
///
/// Teacher-facing intent, selection semantics and smart commands live in
/// the editor-session layer. This controller deliberately owns only document
/// mutation/history while the Studio uses higher-level teacher commands.
class GeometryController extends ChangeNotifier {
  GeometryDiagram _diagram;
  final List<GeometryDiagram> _undoStack = [];
  final List<GeometryDiagram> _redoStack = [];
  String? _selectedLabelId;
  String? _selectedPointId;

  GeometryController({GeometryDiagram? initialDiagram})
    : _diagram =
          initialDiagram ??
          GeometryDiagram(id: const Uuid().v4(), name: 'Geometry Diagram');

  GeometryDiagram get diagram => _diagram;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  String? get selectedLabelId => _selectedLabelId;
  String? get selectedPointId => _selectedPointId;

  GeometryLabel? get selectedLabel {
    for (final label in _diagram.labels) {
      if (label.id == _selectedLabelId) return label;
    }
    return null;
  }

  GeometryPoint? get selectedPoint {
    for (final point in _diagram.points) {
      if (point.id == _selectedPointId) return point;
    }
    return null;
  }

  /// Applies one document-level edit as one undo transaction.
  void updateDiagram(
    GeometryDiagram Function(GeometryDiagram current) transform, {
    bool clearSelection = false,
  }) {
    _commit();
    _diagram = transform(_diagram);
    if (clearSelection) {
      _selectedLabelId = null;
      _selectedPointId = null;
    }
    notifyListeners();
  }

  void replaceDiagram(GeometryDiagram diagram, {bool clearSelection = true}) {
    _commit();
    _diagram = diagram;
    if (clearSelection) {
      _selectedLabelId = null;
      _selectedPointId = null;
    }
    notifyListeners();
  }

  void loadTemplate(GeometryShapeType type) {
    final current = _diagram;
    final generated = const GeometryRecipeFactory().buildShape(
      type,
      diagramId: current.id,
      canvasSize: current.canvasSize,
    );
    replaceDiagram(
      generated.copyWith(
        showGrid: current.showGrid,
        snapToGrid: current.snapToGrid,
        examMode: current.examMode,
        transparentBackground: current.transparentBackground,
      ),
    );
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
    _selectedLabelId = null;
    _selectedPointId = points.last.id;
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
    _selectedPointId = pointId;
    _selectedLabelId = null;
    notifyListeners();
  }

  /// Call once at drag start. Subsequent move calls intentionally do not add
  /// history entries, so one drag becomes one undo step.
  void beginDrag() => _commit();

  void addLabel(
    GeometryLabelType type,
    String text, {
    Offset? position,
    double fontSize = 14,
    double rotation = 0,
    bool isBold = true,
  }) {
    _commit();
    final id = const Uuid().v4();
    final safePosition = _clampToCanvas(
      position ?? Offset(_diagram.canvasSize.width / 2 - 35, 32),
    );
    _diagram = _diagram.copyWith(
      labels: [
        ..._diagram.labels,
        GeometryLabel(
          id: id,
          type: type,
          text: text,
          position: safePosition,
          fontSize: fontSize.clamp(8.0, 42.0).toDouble(),
          rotation: rotation,
          isBold: isBold,
        ),
      ],
    );
    _selectedLabelId = id;
    _selectedPointId = null;
    notifyListeners();
  }

  void moveLabel(String labelId, Offset position) {
    _diagram = _diagram.copyWith(
      labels: _diagram.labels
          .map(
            (label) => label.id == labelId
                ? label.copyWith(position: _clampToCanvas(position))
                : label,
          )
          .toList(),
    );
    _selectedLabelId = labelId;
    _selectedPointId = null;
    notifyListeners();
  }

  void selectLabel(String? labelId) {
    if (_selectedLabelId == labelId && _selectedPointId == null) return;
    _selectedLabelId = labelId;
    _selectedPointId = null;
    notifyListeners();
  }

  void selectPoint(String? pointId) {
    if (_selectedPointId == pointId && _selectedLabelId == null) return;
    _selectedPointId = pointId;
    _selectedLabelId = null;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedLabelId == null && _selectedPointId == null) return;
    _selectedLabelId = null;
    _selectedPointId = null;
    notifyListeners();
  }

  void updatePointLabel(
    String pointId, {
    String? text,
    double? fontSize,
    double? rotation,
    bool? isBold,
  }) {
    _commit();
    _diagram = _diagram.copyWith(
      points: _diagram.points.map((point) {
        if (point.id != pointId) return point;
        return point.copyWith(
          label: text,
          labelFontSize: fontSize?.clamp(8.0, 42.0).toDouble(),
          labelRotation: rotation,
          labelBold: isBold,
        );
      }).toList(),
    );
    _selectedPointId = pointId;
    _selectedLabelId = null;
    notifyListeners();
  }

  void movePointLabel(String pointId, Offset absolutePosition) {
    _diagram = _diagram.copyWith(
      points: _diagram.points.map((point) {
        if (point.id != pointId) return point;
        final clamped = _clampToCanvas(absolutePosition);
        return point.copyWith(labelOffset: clamped - point.position);
      }).toList(),
    );
    _selectedPointId = pointId;
    _selectedLabelId = null;
    notifyListeners();
  }

  void nudgeSelectedPointLabel(Offset delta) {
    final point = selectedPoint;
    if (point == null) return;
    _commit();
    movePointLabel(point.id, point.labelPosition + delta);
  }

  void resizeSelectedPointLabel(double delta) {
    final point = selectedPoint;
    if (point == null) return;
    updatePointLabel(
      point.id,
      fontSize: (point.labelFontSize + delta).clamp(8.0, 42.0).toDouble(),
    );
  }

  void updateLabel(
    String labelId, {
    String? text,
    double? fontSize,
    double? rotation,
    bool? isBold,
  }) {
    _commit();
    _diagram = _diagram.copyWith(
      labels: _diagram.labels.map((label) {
        if (label.id != labelId) return label;
        return label.copyWith(
          text: text,
          fontSize: fontSize?.clamp(8.0, 42.0).toDouble(),
          rotation: rotation,
          isBold: isBold,
        );
      }).toList(),
    );
    _selectedLabelId = labelId;
    _selectedPointId = null;
    notifyListeners();
  }

  void nudgeSelectedLabel(Offset delta) {
    final label = selectedLabel;
    if (label == null) return;
    _commit();
    moveLabel(label.id, label.position + delta);
  }

  void resizeSelectedLabel(double delta) {
    final label = selectedLabel;
    if (label == null) return;
    updateLabel(
      label.id,
      fontSize: (label.fontSize + delta).clamp(8.0, 42.0).toDouble(),
    );
  }

  void removeSelectedLabel() {
    final id = _selectedLabelId;
    if (id == null) return;
    updateDiagram(
      (diagram) => diagram.copyWith(
        labels: diagram.labels.where((label) => label.id != id).toList(),
      ),
      clearSelection: true,
    );
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
          labelOffset: point.labelOffset,
          labelFontSize: point.labelFontSize,
          labelRotation: point.labelRotation,
          labelBold: point.labelBold,
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
            fontSize: label.fontSize,
            rotation: label.rotation,
            isBold: label.isBold,
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
    updateDiagram(
      (diagram) =>
          diagram.copyWith(points: [], shapes: [], labels: [], marks: []),
      clearSelection: true,
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_diagram);
    _diagram = _undoStack.removeLast();
    _selectedLabelId = null;
    _selectedPointId = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_diagram);
    _diagram = _redoStack.removeLast();
    _selectedLabelId = null;
    _selectedPointId = null;
    notifyListeners();
  }

  void toggleGrid() {
    updateDiagram((diagram) => diagram.copyWith(showGrid: !diagram.showGrid));
  }

  void toggleSnap() {
    updateDiagram(
      (diagram) => diagram.copyWith(snapToGrid: !diagram.snapToGrid),
    );
  }

  void toggleTransparentBackground() {
    updateDiagram(
      (diagram) => diagram.copyWith(
        transparentBackground: !diagram.transparentBackground,
      ),
    );
  }

  void _commit() {
    _undoStack.add(_diagram);
    _redoStack.clear();
  }

  Offset _clampToCanvas(Offset position) {
    return Offset(
      position.dx
          .clamp(0.0, math.max(0.0, _diagram.canvasSize.width - 24.0))
          .toDouble(),
      position.dy
          .clamp(0.0, math.max(0.0, _diagram.canvasSize.height - 20.0))
          .toDouble(),
    );
  }

  Offset _snap(Offset position) {
    const grid = 20.0;
    return Offset(
      (position.dx / grid).round() * grid,
      (position.dy / grid).round() * grid,
    );
  }

  String _labelForIndex(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < letters.length) return letters[index];
    return 'P${index + 1}';
  }
}
