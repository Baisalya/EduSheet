import 'package:edusheet/features/geometry_builder/application/geometry_editor_session.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_freeform_tool.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free-form line and arrow use canonical geometry primitives', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);

    session.setFreeformTool(GeometryFreeformTool.line);
    session.beginCanvasGesture(const Offset(41, 39));
    session.updateCanvasGesture(const Offset(181, 101));
    session.endCanvasGesture();

    session.setFreeformTool(GeometryFreeformTool.arrow);
    session.beginCanvasGesture(const Offset(60, 160));
    session.updateCanvasGesture(const Offset(240, 160));
    session.endCanvasGesture();

    expect(session.diagram.shapes, hasLength(2));
    expect(session.diagram.shapes[0].type, GeometryShapeType.line);
    expect(session.diagram.shapes[1].type, GeometryShapeType.arrow);
    expect(session.diagram.points, hasLength(4));

    final restored = GeometryDiagram.fromJson(session.diagram.toJson());
    expect(restored.shapes.map((shape) => shape.type), [
      GeometryShapeType.line,
      GeometryShapeType.arrow,
    ]);
  });

  test('free-form circle persists center and radius edge', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);

    session.setFreeformTool(GeometryFreeformTool.circle);
    session.beginCanvasGesture(const Offset(120, 120));
    session.updateCanvasGesture(const Offset(180, 120));
    session.endCanvasGesture();

    final circle = session.diagram.shapes.single;
    expect(circle.type, GeometryShapeType.circle);
    expect(circle.pointIds, hasLength(2));
    expect(circle.radius, closeTo(60, 0.001));
  });

  test('free-form angle uses three taps and stays editable', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);

    session.setFreeformTool(GeometryFreeformTool.angle);
    session.tapCanvas(const Offset(120, 120));
    expect(session.freeformAngleDraft, hasLength(1));
    session.tapCanvas(const Offset(200, 120));
    expect(session.freeformAngleDraft, hasLength(2));
    session.tapCanvas(const Offset(120, 40));

    expect(session.freeformAngleDraft, isEmpty);
    expect(session.diagram.points, hasLength(3));
    expect(session.diagram.points.map((point) => point.label), ['A', 'B', 'C']);
    expect(session.diagram.shapes, hasLength(2));
    expect(session.diagram.marks, hasLength(1));
    expect(session.diagram.marks.single.type, GeometryMarkType.angleArc);
  });

  test('point tool honors grid snap and adds teacher-editable labels', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);

    session.setFreeformTool(GeometryFreeformTool.point);
    session.tapCanvas(const Offset(47, 73));
    session.tapCanvas(const Offset(111, 129));

    expect(session.diagram.points.map((point) => point.label), ['A', 'B']);
    expect(session.diagram.points[0].position, const Offset(40, 80));
    expect(session.diagram.points[1].position, const Offset(120, 120));
  });
  test('free-form axes and number line use canonical helper shapes', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);

    session.setFreeformTool(GeometryFreeformTool.coordinateAxes);
    session.beginCanvasGesture(const Offset(180, 120));
    session.updateCanvasGesture(const Offset(280, 200));
    session.endCanvasGesture();

    session.setFreeformTool(GeometryFreeformTool.numberLine);
    session.beginCanvasGesture(const Offset(60, 220));
    session.updateCanvasGesture(const Offset(300, 220));
    session.endCanvasGesture();

    expect(session.diagram.shapes, hasLength(2));
    expect(session.diagram.shapes[0].type, GeometryShapeType.coordinateAxes);
    expect(session.diagram.shapes[0].pointIds, hasLength(4));
    expect(session.diagram.shapes[1].type, GeometryShapeType.numberLine);
    expect(session.diagram.shapes[1].pointIds, hasLength(2));

    final restored = GeometryDiagram.fromJson(session.diagram.toJson());
    expect(restored.shapes.map((shape) => shape.type), [
      GeometryShapeType.coordinateAxes,
      GeometryShapeType.numberLine,
    ]);
  });
}
