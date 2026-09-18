import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_object_editor_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixed-page selection exposes page intent and overflow recovery', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'fixed',
        kind: WordShapeKind.rectangle,
        x: 0.72,
        y: 0.12,
        width: 0.36,
        height: 0.24,
        anchorMode: WordObjectAnchorMode.fixedOnPage,
        fixedPageIndex: 2,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 520,
              child: WordObjectEditorLayer(
                shapes: shapes,
                compact: false,
                ownerPageIndex: 2,
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 260, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-fixed')));
    await tester.pump();

    expect(find.byKey(const ValueKey('word-object-fixed-page-fixed')), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
    expect(find.byKey(const Key('word-object-overflow-warning')), findsOneWidget);

    await tester.tap(find.byKey(const Key('word-object-fit-inside')));
    await tester.pump();
    expect(shapes.single.exceedsNormalizedBounds, isFalse);
    expect(find.byKey(const Key('word-object-overflow-warning')), findsNothing);
  });

  testWidgets('floating geometry exposes Geometry Studio edit action', (
    tester,
  ) async {
    var edited = false;
    const diagram = GeometryDiagram(id: 'g', name: 'Diagram');
    const shape = WordShapeObject(
      id: 'geometry',
      kind: WordShapeKind.geometry,
      geometryDiagram: diagram,
      borderVisible: false,
      aspectRatioLocked: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: WordObjectEditorLayer(
              shapes: const [shape],
              compact: false,
              onShapesChanged: (_) {},
              onEditGeometry: (_) async => edited = true,
              child: const SizedBox(height: 260, child: Text('Body')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-geometry')));
    await tester.pump();
    final edit = find.byKey(const ValueKey('word-object-edit-geometry-geometry'));
    expect(edit, findsOneWidget);
    await tester.tap(edit);
    await tester.pump();
    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop geometry double-click edit is timer-free', (tester) async {
    var edits = 0;
    const diagram = GeometryDiagram(id: 'double-g', name: 'Diagram');
    const shape = WordShapeObject(
      id: 'double-geometry',
      kind: WordShapeKind.geometry,
      geometryDiagram: diagram,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: WordObjectEditorLayer(
              shapes: const [shape],
              compact: false,
              onShapesChanged: (_) {},
              onEditGeometry: (_) async => edits += 1,
              child: const SizedBox(height: 260, child: Text('Body')),
            ),
          ),
        ),
      ),
    );

    final object = find.byKey(const ValueKey('word-object-double-geometry'));
    await tester.tap(object);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(object);
    await tester.pump();

    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed-page object reports reflow mismatch and can be re-pinned', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'pinned',
        kind: WordShapeKind.textBox,
        text: 'Pinned note',
        anchorMode: WordObjectAnchorMode.fixedOnPage,
        fixedPageIndex: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 520,
              child: WordObjectEditorLayer(
                shapes: shapes,
                compact: false,
                ownerPageIndex: 2,
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 260, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-pinned')));
    await tester.pump();

    expect(find.byKey(const Key('word-object-page-mismatch')), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('word-object-repin-page')));
    await tester.pump();

    expect(shapes.single.fixedPageIndex, 2);
    expect(find.byKey(const Key('word-object-page-mismatch')), findsNothing);
    expect(find.text('Page 3'), findsOneWidget);
  });

}
