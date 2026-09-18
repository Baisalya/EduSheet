import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_object_editor_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 3 floating text box overlays normal document flow', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'textbox',
        kind: WordShapeKind.textBox,
        x: 0.12,
        y: 0.16,
        width: 0.42,
        height: 0.24,
        text: 'Floating note',
        wrapMode: WordTextWrapMode.inFrontOfText,
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
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(
                  height: 260,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text('Normal paragraph stays in document flow.'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Normal paragraph stays in document flow.'), findsOneWidget);
    expect(find.text('Floating note'), findsOneWidget);
    expect(find.byKey(const Key('word-object-editor-layer')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-object-textbox')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 4 selection exposes resize and manipulation toolbar', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'shape',
        kind: WordShapeKind.rectangle,
        x: 0.10,
        y: 0.10,
        width: 0.30,
        height: 0.24,
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
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 260, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-shape')));
    await tester.pump();

    expect(find.byKey(const Key('word-object-selection-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-object-resize-shape')), findsOneWidget);
    expect(find.byKey(const Key('word-object-duplicate')), findsOneWidget);
    expect(find.byKey(const Key('word-object-lock')), findsOneWidget);
    expect(find.byKey(const Key('word-object-front')), findsOneWidget);
    expect(find.byKey(const Key('word-object-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('word-object-duplicate')));
    await tester.pump();
    expect(shapes, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked object remains selectable but hides resize handle', (
    tester,
  ) async {
    var shapes = const [
      WordShapeObject(
        id: 'locked',
        kind: WordShapeKind.textBox,
        text: 'Locked',
        locked: true,
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
                onShapesChanged: (value) => setState(() => shapes = value),
                child: const SizedBox(height: 220, child: Text('Body')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('word-object-locked')));
    await tester.pump();

    expect(find.byKey(const Key('word-object-selection-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-object-resize-locked')), findsNothing);
    expect(
      find.byKey(const ValueKey('word-object-lock-indicator-locked')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
