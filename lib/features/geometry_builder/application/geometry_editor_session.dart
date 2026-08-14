import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_diagram.dart';
import '../models/geometry_label.dart';
import '../models/geometry_shape.dart';
import 'geometry_editor_commands.dart';
import 'geometry_hit_tester.dart';
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
        .map((point) => point.copyWith(position: _clamp(point.position + offset)))
        .toList();
    final shiftedLabels = addition.labels
        .map((label) => label.copyWith(position: _clamp(label.position + offset)))
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
        return point == null || point.label.isEmpty ? 'Point' : 'Point ${point.label}';
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
