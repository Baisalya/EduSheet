import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_object_editor_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('touch mode exposes 48px selection affordances and property sheet', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'touch',
        kind: WordShapeKind.textBox,
        text: 'Touch note',
        x: 0.10,
        y: 0.10,
        width: 0.32,
        height: 0.24,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: WordObjectEditorLayer(
                shapes: shapes,
                compact: true,
                desktopInteractions: false,
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 240, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-touch')));
    await tester.pump();

    expect(find.byKey(const Key('word-object-mobile-action-bar')), findsOneWidget);
    final handle = find.byKey(const ValueKey('word-object-resize-touch'));
    expect(handle, findsOneWidget);
    expect(tester.getSize(handle).width, greaterThanOrEqualTo(40));
    expect(tester.getSize(handle).height, greaterThanOrEqualTo(40));

    await tester.tap(find.byKey(const Key('word-object-mobile-more')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('word-object-mobile-properties-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('word-object-mobile-edit-text-touch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch long press adds an object to multi-selection', (tester) async {
    var shapes = const [
      WordShapeObject(
        id: 'one',
        kind: WordShapeKind.rectangle,
        x: 0.05,
        y: 0.08,
        width: 0.30,
        height: 0.22,
      ),
      WordShapeObject(
        id: 'two',
        kind: WordShapeKind.rectangle,
        x: 0.58,
        y: 0.08,
        width: 0.30,
        height: 0.22,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: WordObjectEditorLayer(
                shapes: shapes,
                compact: true,
                desktopInteractions: false,
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 240, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-one')));
    await tester.pump();
    await tester.longPress(find.byKey(const ValueKey('word-object-two')));
    await tester.pump();

    expect(find.text('2 objects'), findsOneWidget);
    expect(find.byKey(const Key('word-object-mobile-action-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact desktop keeps mouse double-click semantics and precise handle', (
    tester,
  ) async {
    var edits = 0;
    const diagram = GeometryDiagram(id: 'desktop-geometry', name: 'Geometry');
    const shape = WordShapeObject(
      id: 'desktop',
      kind: WordShapeKind.geometry,
      geometryDiagram: diagram,
      x: 0.12,
      y: 0.12,
      width: 0.32,
      height: 0.24,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: WordObjectEditorLayer(
              shapes: const [shape],
              compact: true,
              desktopInteractions: true,
              onShapesChanged: (_) {},
              onEditGeometry: (_) async => edits += 1,
              child: const SizedBox(height: 240, child: Text('Body')),
            ),
          ),
        ),
      ),
    );

    final object = find.byKey(const ValueKey('word-object-desktop'));
    await tester.tap(object);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('word-object-mobile-action-bar')), findsOneWidget);
    final handle = find.byKey(const ValueKey('word-object-resize-desktop'));
    expect(tester.getSize(handle).width, closeTo(22, 0.1));

    await tester.tap(object);
    await tester.pump();

    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keyboard nudges selected object and Escape clears selection', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'keyboard',
        kind: WordShapeKind.rectangle,
        x: 0.20,
        y: 0.20,
        width: 0.25,
        height: 0.20,
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
                desktopInteractions: true,
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 260, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-keyboard')));
    await tester.pump();
    final before = shapes.single.x;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(shapes.single.x, greaterThan(before));
    expect(find.byKey(const Key('word-object-selection-toolbar')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(shapes.single.locked, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byKey(const Key('word-object-selection-toolbar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
