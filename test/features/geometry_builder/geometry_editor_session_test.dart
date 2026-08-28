import 'package:edusheet/features/geometry_builder/application/geometry_editor_session.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_recipe.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_selection.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('side commands target the side the teacher selected', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.triangle);
    final shape = session.diagram.shapes.single;

    session.setSelection(GeometrySelection.side(shape.id, 1));
    final ids = session.selection.sidePointIds(session.diagram);
    final outcome = session.markSelectedSideEqual();

    expect(outcome.success, isTrue);
    final mark = session.diagram.marks.last;
    expect(mark.type, GeometryMarkType.equalSideTick);
    expect(mark.pointIds, ids);
  });

  test('right-angle command uses the selected vertex and its two rays', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.triangle);
    final shape = session.diagram.shapes.single;
    final vertexId = shape.pointIds[1];

    session.setSelection(GeometrySelection.point(vertexId));
    final outcome = session.markSelectedVertexRightAngle();

    expect(outcome.success, isTrue);
    final mark = session.diagram.marks.last;
    expect(mark.type, GeometryMarkType.rightAngle);
    expect(mark.pointIds.first, vertexId);
    expect(mark.pointIds.toSet(), shape.pointIds.toSet());
  });

  test(
    'height projects the selected triangle vertex onto the opposite side',
    () {
      final session = GeometryEditorSession();
      addTearDown(session.dispose);
      session.useRecipe(GeometryRecipeCatalog.triangle);
      final shape = session.diagram.shapes.single;
      final vertex = session.diagram.pointMap[shape.pointIds[0]]!;
      final a = session.diagram.pointMap[shape.pointIds[1]]!;
      final b = session.diagram.pointMap[shape.pointIds[2]]!;

      session.setSelection(GeometrySelection.point(vertex.id));
      final outcome = session.addHeightFromSelectedVertex();

      expect(outcome.success, isTrue);
      final height = session.diagram.marks.firstWhere(
        (mark) => mark.type == GeometryMarkType.dashedHeightLine,
      );
      final foot = session.diagram.pointMap[height.pointIds[1]]!;
      final ab = b.position - a.position;
      final af = foot.position - a.position;
      final cross = ab.dx * af.dy - ab.dy * af.dx;
      expect(cross.abs(), lessThan(0.001));
      expect(
        session.diagram.marks.any(
          (mark) => mark.type == GeometryMarkType.rightAngle,
        ),
        isTrue,
      );
    },
  );

  test('shape-owned point cannot be deleted independently', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.triangle);
    final shape = session.diagram.shapes.single;
    session.setSelection(GeometrySelection.point(shape.pointIds.first));

    final outcome = session.deleteSelected();

    expect(outcome.success, isFalse);
    expect(session.diagram.shapes, hasLength(1));
    expect(session.diagram.points, hasLength(3));
  });

  test('coordinate point maps values onto existing coordinate axes', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.coordinateAxes);
    final axes = session.diagram.shapes.single;
    session.setSelection(GeometrySelection.shape(axes.id));

    final outcome = session.addCoordinatePoint(x: 2, y: 3, label: 'P');

    expect(outcome.success, isTrue);
    final point = session.diagram.points.last;
    expect(point.label, 'P');
    expect(point.position.dx, closeTo(220, 0.001));
    expect(point.position.dy, closeTo(66, 0.001));
    expect(
      session.diagram.marks.any(
        (mark) =>
            mark.type == GeometryMarkType.centerPoint &&
            mark.pointIds.contains(point.id),
      ),
      isTrue,
    );
  });

  test('smart diagram remains compatible with existing JSON model', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.equilateralTriangle);
    final restored = GeometryDiagram.fromJson(session.diagram.toJson());

    expect(restored.shapes.single.type, GeometryShapeType.triangle);
    expect(restored.points.length, 3);
    expect(restored.marks.length, 3);
  });

  test('a visible side mark can be selected instead of the side under it', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.triangle);
    final shape = session.diagram.shapes.single;
    session.setSelection(GeometrySelection.side(shape.id, 0));
    expect(session.markSelectedSideEqual().success, isTrue);

    final mark = session.diagram.marks.last;
    final selected = session.selectAt(mark.position);

    expect(selected.kind, GeometrySelectionKind.mark);
    expect(selected.markId, mark.id);
  });

  test('right-angle mark is hit-tested at the visible vertex anchor', () {
    final session = GeometryEditorSession();
    addTearDown(session.dispose);
    session.useRecipe(GeometryRecipeCatalog.rightTriangle);
    final mark = session.diagram.marks.firstWhere(
      (item) => item.type == GeometryMarkType.rightAngle,
    );

    final selected = session.selectAt(mark.position);

    // Points intentionally have first priority when the exact vertex itself is
    // tapped. A small offset inside the visible corner selects the mark.
    final nearby = session.selectAt(mark.position + const Offset(10, -10));
    expect(selected.kind, GeometrySelectionKind.point);
    expect(nearby.kind, GeometrySelectionKind.mark);
    expect(nearby.markId, mark.id);
  });
}
