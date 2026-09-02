import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';
import 'geometry_editor_commands.dart';
import 'geometry_hit_tester.dart';
import 'geometry_freeform_tool.dart';
import 'geometry_recipe.dart';
import 'geometry_recipe_factory.dart';
import 'geometry_selection.dart';

export 'geometry_editor_commands.dart' show GeometryEditOutcome;

/// Transient teacher-facing state for one Geometry Studio session.
///
/// Persisted geometry lives in [GeometryController]. Semantic edits live in
/// [GeometryEditorCommands]. This class only coordinates selection, dragging,
/// recipes and UI-facing state, keeping transient editor concepts out of JSON.
class GeometryEditorSession extends ChangeNotifier {
  final GeometryController document;
  final GeometryHitTester hitTester;
  final GeometryRecipeFactory recipeFactory;
  late final GeometryEditorCommands commands;
  late final String _baselineJson;
  GeometrySelection _selection = const GeometrySelection.none();
  String? _dragPointId;
  String? _dragLabelId;
  String? _dragPointLabelId;
  GeometryFreeformTool _freeformTool = GeometryFreeformTool.select;
  Offset? _drawStart;
  Offset? _drawCurrent;
  final List<Offset> _angleDraft = [];

  GeometryEditorSession({
    GeometryDiagram? initialDiagram,
    GeometryHitTester? hitTester,
    GeometryRecipeFactory? recipeFactory,
  }) : document = GeometryController(initialDiagram: initialDiagram),
       hitTester = hitTester ?? const GeometryHitTester(),
       recipeFactory = recipeFactory ?? const GeometryRecipeFactory() {
    commands = GeometryEditorCommands(document);
    _baselineJson = jsonEncode(document.diagram.toJson());
    document.addListener(_onDocumentChanged);
  }

  GeometryDiagram get diagram => document.diagram;
  GeometrySelection get selection => _selection;
  bool get canUndo => document.canUndo;
  bool get canRedo => document.canRedo;
  bool get isEmpty => diagram.shapes.isEmpty && diagram.points.isEmpty;
  bool get isDirty => jsonEncode(diagram.toJson()) != _baselineJson;
  GeometryFreeformTool get freeformTool => _freeformTool;
  bool get isSelectionTool => _freeformTool == GeometryFreeformTool.select;
  Offset? get freeformDrawStart => _drawStart;
  Offset? get freeformDrawCurrent => _drawCurrent;
  List<Offset> get freeformAngleDraft => List.unmodifiable(_angleDraft);
  String get freeformHint {
    if (_freeformTool == GeometryFreeformTool.angle && _angleDraft.isNotEmpty) {
      return switch (_angleDraft.length) {
        1 => 'Angle: vertex set. Tap a point on the first ray.',
        2 => 'Angle: first ray set. Tap a point on the second ray.',
        _ => _freeformTool.hint,
      };
    }
    return _freeformTool.hint;
  }

  @override
  void dispose() {
    document.removeListener(_onDocumentChanged);
    document.dispose();
    super.dispose();
  }

  void _onDocumentChanged() => notifyListeners();

  void undo() {
    document.undo();
    clearSelection();
  }

  void redo() {
    document.redo();
    clearSelection();
  }

  void toggleGrid() => document.toggleGrid();
  void toggleSnap() => document.toggleSnap();

  void setFreeformTool(GeometryFreeformTool tool) {
    if (_freeformTool == tool) return;
    _freeformTool = tool;
    _drawStart = null;
    _drawCurrent = null;
    _angleDraft.clear();
    if (tool != GeometryFreeformTool.select &&
        _selection.kind != GeometrySelectionKind.none) {
      clearSelection();
    } else {
      notifyListeners();
    }
  }

  void tapCanvas(Offset position) {
    final point = _normalizeCanvasPosition(position);
    switch (_freeformTool) {
      case GeometryFreeformTool.select:
        selectAt(point);
      case GeometryFreeformTool.point:
        _addFreeformPoint(point);
      case GeometryFreeformTool.angle:
        _addAngleDraftPoint(point);
      case GeometryFreeformTool.line:
      case GeometryFreeformTool.arrow:
      case GeometryFreeformTool.circle:
      case GeometryFreeformTool.coordinateAxes:
      case GeometryFreeformTool.numberLine:
        break;
    }
  }

  void beginCanvasGesture(Offset position) {
    if (isSelectionTool) {
      beginDragAt(position);
      return;
    }
    if (_freeformTool == GeometryFreeformTool.point ||
        _freeformTool == GeometryFreeformTool.angle) {
      return;
    }
    _drawStart = _normalizeCanvasPosition(position);
    _drawCurrent = _drawStart;
    notifyListeners();
  }

  void updateCanvasGesture(Offset position) {
    if (isSelectionTool) {
      dragTo(position);
      return;
    }
    if (_drawStart == null) return;
    _drawCurrent = _normalizeCanvasPosition(position);
    notifyListeners();
  }

  void endCanvasGesture() {
    if (isSelectionTool) {
      endDrag();
      return;
    }
    final start = _drawStart;
    final end = _drawCurrent;
    _drawStart = null;
    _drawCurrent = null;
    if (start == null || end == null || (end - start).distance < 8) {
      notifyListeners();
      return;
    }
    switch (_freeformTool) {
      case GeometryFreeformTool.line:
        _addFreeformSegment(start, end, GeometryShapeType.line);
      case GeometryFreeformTool.arrow:
        _addFreeformSegment(start, end, GeometryShapeType.arrow);
      case GeometryFreeformTool.circle:
        _addFreeformCircle(start, end);
      case GeometryFreeformTool.coordinateAxes:
        _addFreeformAxes(start, end);
      case GeometryFreeformTool.numberLine:
        _addFreeformSegment(start, end, GeometryShapeType.numberLine);
      case GeometryFreeformTool.select:
      case GeometryFreeformTool.point:
      case GeometryFreeformTool.angle:
        notifyListeners();
    }
  }

  void cancelFreeformDraft() {
    if (isSelectionTool) {
      endDrag();
      return;
    }
    _drawStart = null;
    _drawCurrent = null;
    _angleDraft.clear();
    notifyListeners();
  }

  void _addFreeformPoint(Offset position) {
    final id = const Uuid().v4();
    final point = GeometryPoint(
      id: id,
      label: _nextPointLabel(),
      position: position,
    );
    document.updateDiagram(
      (current) => current.copyWith(points: [...current.points, point]),
    );
    setSelection(GeometrySelection.point(id));
  }

  void _addFreeformSegment(Offset start, Offset end, GeometryShapeType type) {
    final startPoint = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: start,
    );
    final endPoint = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: end,
    );
    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: type,
      pointIds: [startPoint.id, endPoint.id],
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, startPoint, endPoint],
        shapes: [...current.shapes, shape],
      ),
    );
    setSelection(GeometrySelection.shape(shape.id));
  }

  void _addFreeformCircle(Offset center, Offset edge) {
    final centerPoint = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: center,
    );
    final edgePoint = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: edge,
    );
    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: GeometryShapeType.circle,
      pointIds: [centerPoint.id, edgePoint.id],
      radius: (edge - center).distance,
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, centerPoint, edgePoint],
        shapes: [...current.shapes, shape],
      ),
    );
    setSelection(GeometrySelection.shape(shape.id));
  }

  void _addFreeformAxes(Offset origin, Offset edge) {
    final horizontal = math.max(40.0, (edge.dx - origin.dx).abs());
    final vertical = math.max(40.0, (edge.dy - origin.dy).abs());
    final top = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: _normalizeCanvasPosition(
        Offset(origin.dx, origin.dy - vertical),
      ),
    );
    final bottom = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: _normalizeCanvasPosition(
        Offset(origin.dx, origin.dy + vertical),
      ),
    );
    final left = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: _normalizeCanvasPosition(
        Offset(origin.dx - horizontal, origin.dy),
      ),
    );
    final right = GeometryPoint(
      id: const Uuid().v4(),
      label: '',
      position: _normalizeCanvasPosition(
        Offset(origin.dx + horizontal, origin.dy),
      ),
    );
    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: GeometryShapeType.coordinateAxes,
      pointIds: [top.id, bottom.id, left.id, right.id],
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, top, bottom, left, right],
        shapes: [...current.shapes, shape],
      ),
    );
    setSelection(GeometrySelection.shape(shape.id));
  }

  void _addAngleDraftPoint(Offset point) {
    _angleDraft.add(point);
    if (_angleDraft.length < 3) {
      notifyListeners();
      return;
    }

    final vertex = GeometryPoint(
      id: const Uuid().v4(),
      label: _nextPointLabel(),
      position: _angleDraft[0],
    );
    final firstRay = GeometryPoint(
      id: const Uuid().v4(),
      label: _nextPointLabel(offset: 1),
      position: _angleDraft[1],
    );
    final secondRay = GeometryPoint(
      id: const Uuid().v4(),
      label: _nextPointLabel(offset: 2),
      position: _angleDraft[2],
    );
    final firstLine = GeometryShape(
      id: const Uuid().v4(),
      type: GeometryShapeType.line,
      pointIds: [vertex.id, firstRay.id],
    );
    final secondLine = GeometryShape(
      id: const Uuid().v4(),
      type: GeometryShapeType.line,
      pointIds: [vertex.id, secondRay.id],
    );
    final mark = GeometryMark(
      id: const Uuid().v4(),
      type: GeometryMarkType.angleArc,
      pointIds: [vertex.id, firstRay.id, secondRay.id],
      position: vertex.position,
    );
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, vertex, firstRay, secondRay],
        shapes: [...current.shapes, firstLine, secondLine],
        marks: [...current.marks, mark],
      ),
    );
    _angleDraft.clear();
    setSelection(GeometrySelection.mark(mark.id));
  }

  Offset _normalizeCanvasPosition(Offset position) {
    var result = Offset(
      position.dx.clamp(0.0, diagram.canvasSize.width).toDouble(),
      position.dy.clamp(0.0, diagram.canvasSize.height).toDouble(),
    );
    if (diagram.snapToGrid) {
      const grid = 20.0;
      result = Offset(
        (result.dx / grid).round() * grid,
        (result.dy / grid).round() * grid,
      );
    }
    return Offset(
      result.dx.clamp(0.0, diagram.canvasSize.width).toDouble(),
      result.dy.clamp(0.0, diagram.canvasSize.height).toDouble(),
    );
  }

  String _nextPointLabel({int offset = 0}) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final used = diagram.points.where((point) => point.label.isNotEmpty).length;
    final index = used + offset;
    if (index < letters.length) return letters[index];
    return 'P${index + 1}';
  }

  void clearSelection() => setSelection(const GeometrySelection.none());

  void setSelection(GeometrySelection selection) {
    if (_sameSelection(_selection, selection)) return;
    _selection = selection;
    switch (selection.kind) {
      case GeometrySelectionKind.point:
        document.selectPoint(selection.pointId);
      case GeometrySelectionKind.label:
        document.selectLabel(selection.labelId);
      case GeometrySelectionKind.none:
      case GeometrySelectionKind.shape:
      case GeometrySelectionKind.side:
      case GeometrySelectionKind.mark:
        document.clearSelection();
    }
    notifyListeners();
  }

  GeometrySelection selectAt(Offset position) {
    final hit = hitTester.hit(diagram, position);
    setSelection(hit);
    return hit;
  }

  GeometrySelection? beginDragAt(Offset position) {
    _dragPointId = hitTester.hitPoint(diagram, position);
    _dragLabelId = _dragPointId == null
        ? hitTester.hitLabel(diagram, position)
        : null;
    _dragPointLabelId = _dragPointId == null && _dragLabelId == null
        ? hitTester.hitPointLabel(diagram, position)
        : null;

    if (_dragPointId != null) {
      setSelection(GeometrySelection.point(_dragPointId!));
    } else if (_dragLabelId != null) {
      setSelection(GeometrySelection.label(_dragLabelId!));
    } else if (_dragPointLabelId != null) {
      setSelection(GeometrySelection.point(_dragPointLabelId!));
    } else {
      return null;
    }

    document.beginDrag();
    return _selection;
  }

  void dragTo(Offset position) {
    if (_dragPointId != null) {
      document.movePoint(_dragPointId!, position);
    } else if (_dragLabelId != null) {
      document.moveLabel(_dragLabelId!, position);
    } else if (_dragPointLabelId != null) {
      document.movePointLabel(_dragPointLabelId!, position);
    }
  }

  void endDrag() {
    _dragPointId = null;
    _dragLabelId = null;
    _dragPointLabelId = null;
  }

  void useRecipe(GeometryRecipe recipe, {bool replace = false}) {
    final generated = recipeFactory.build(
      recipe,
      diagramId: isEmpty || replace ? diagram.id : null,
      canvasSize: diagram.canvasSize,
    );
    if (isEmpty || replace) {
      final current = diagram;
      document.replaceDiagram(
        generated.copyWith(
          showGrid: current.showGrid,
          snapToGrid: current.snapToGrid,
          examMode: current.examMode,
          transparentBackground: current.transparentBackground,
        ),
      );
    } else {
      _appendDiagram(generated);
    }
    clearSelection();
  }

  void addShape(GeometryShapeType type) {
    final generated = recipeFactory.buildShape(
      type,
      canvasSize: diagram.canvasSize,
    );
    if (isEmpty) {
      final current = diagram;
      document.replaceDiagram(
        generated.copyWith(
          showGrid: current.showGrid,
          snapToGrid: current.snapToGrid,
          examMode: current.examMode,
          transparentBackground: current.transparentBackground,
        ),
      );
    } else {
      _appendDiagram(generated);
    }
    clearSelection();
  }

  void _appendDiagram(GeometryDiagram addition) {
    final offsetAmount = 12.0 + ((diagram.shapes.length % 3) * 10.0);
    final offset = Offset(offsetAmount, offsetAmount);
    final shiftedPoints = addition.points
        .map(
          (point) => point.copyWith(position: _clamp(point.position + offset)),
        )
        .toList();
    final shiftedLabels = addition.labels
        .map(
          (label) => label.copyWith(position: _clamp(label.position + offset)),
        )
        .toList();
    final shiftedMarks = addition.marks
        .map((mark) => mark.copyWith(position: _clamp(mark.position + offset)))
        .toList();
    document.updateDiagram(
      (current) => current.copyWith(
        points: [...current.points, ...shiftedPoints],
        shapes: [...current.shapes, ...addition.shapes],
        labels: [...current.labels, ...shiftedLabels],
        marks: [...current.marks, ...shiftedMarks],
      ),
    );
  }

  GeometryEditOutcome renameSelectedPoint(String text) {
    final point = selection.point(diagram);
    if (point == null) {
      return const GeometryEditOutcome.failure('Select a point first.');
    }
    document.updatePointLabel(point.id, text: text.trim());
    setSelection(GeometrySelection.point(point.id));
    return const GeometryEditOutcome.success();
  }

  GeometryEditOutcome updateSelectedLabel(String text) {
    final label = selection.label(diagram);
    if (label == null) {
      return const GeometryEditOutcome.failure('Select a label first.');
    }
    document.updateLabel(label.id, text: text.trim());
    setSelection(GeometrySelection.label(label.id));
    return const GeometryEditOutcome.success();
  }

  GeometryEditOutcome addSideMeasurement(String text) =>
      _apply(commands.addSideMeasurement(selection, text));

  GeometryEditOutcome addAngleMeasurement(String text) =>
      _apply(commands.addAngleMeasurement(selection, text));

  GeometryEditOutcome markSelectedSideEqual() =>
      _apply(commands.markSelectedSideEqual(selection));

  GeometryEditOutcome markSelectedSideParallel() =>
      _apply(commands.markSelectedSideParallel(selection));

  GeometryEditOutcome markSelectedVertexRightAngle() =>
      _apply(commands.markSelectedVertexRightAngle(selection));

  GeometryEditOutcome addHeightFromSelectedVertex() =>
      _apply(commands.addHeightFromSelectedVertex(selection));

  GeometryEditOutcome addRadiusToSelectedCircle() =>
      _apply(commands.addRadiusToSelectedCircle(selection));

  GeometryEditOutcome addCoordinatePoint({
    required double x,
    required double y,
    required String label,
  }) => _apply(commands.addCoordinatePoint(x: x, y: y, label: label));

  void addCustomLabel(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    document.addLabel(
      GeometryLabelType.custom,
      value,
      position: Offset(diagram.canvasSize.width / 2 - 30, 28),
    );
    final id = document.selectedLabelId;
    if (id != null) setSelection(GeometrySelection.label(id));
  }

  GeometryEditOutcome duplicateSelectedShape() =>
      _apply(commands.duplicateSelectedShape(selection));

  GeometryEditOutcome deleteSelected() =>
      _apply(commands.deleteSelected(selection));

  GeometryEditOutcome _apply(GeometryEditOutcome outcome) {
    final nextSelection = outcome.nextSelection;
    if (outcome.success && nextSelection != null) {
      setSelection(nextSelection);
    }
    return outcome;
  }

  String get selectionLabel {
    switch (selection.kind) {
      case GeometrySelectionKind.none:
        return 'Nothing selected';
      case GeometrySelectionKind.point:
        final point = selection.point(diagram);
        return point == null || point.label.isEmpty
            ? 'Point'
            : 'Point ${point.label}';
      case GeometrySelectionKind.label:
        return 'Text label';
      case GeometrySelectionKind.shape:
        final shape = selection.shape(diagram);
        return shape == null ? 'Shape' : _pretty(shape.type.name);
      case GeometrySelectionKind.side:
        return 'Side';
      case GeometrySelectionKind.mark:
        final mark = selection.mark(diagram);
        return mark == null ? 'Mark' : _pretty(mark.type.name);
    }
  }

  Offset _clamp(Offset position) => Offset(
    position.dx
        .clamp(8.0, math.max(8.0, diagram.canvasSize.width - 8))
        .toDouble(),
    position.dy
        .clamp(8.0, math.max(8.0, diagram.canvasSize.height - 8))
        .toDouble(),
  );

  String _pretty(String camelCase) {
    final words = camelCase.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  bool _sameSelection(GeometrySelection a, GeometrySelection b) =>
      a.kind == b.kind &&
      a.pointId == b.pointId &&
      a.labelId == b.labelId &&
      a.shapeId == b.shapeId &&
      a.markId == b.markId &&
      a.sideIndex == b.sideIndex;
}
