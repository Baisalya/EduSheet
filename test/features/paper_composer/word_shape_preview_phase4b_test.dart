import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/word_shape_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 4B shape flow renders square, overlay and text shapes', (
    tester,
  ) async {
    final shapes = [
      const WordShapeObject(
        id: 'left',
        kind: WordShapeKind.rectangle,
        wrapMode: WordTextWrapMode.squareLeft,
        width: 0.30,
        height: 0.30,
      ),
      const WordShapeObject(
        id: 'behind',
        kind: WordShapeKind.ellipse,
        wrapMode: WordTextWrapMode.behindText,
        x: 0.55,
        y: 0.05,
        width: 0.25,
        height: 0.30,
        zIndex: -2,
      ),
      const WordShapeObject(
        id: 'front',
        kind: WordShapeKind.callout,
        wrapMode: WordTextWrapMode.inFrontOfText,
        x: 0.58,
        y: 0.38,
        width: 0.30,
        height: 0.34,
        zIndex: 3,
        text: 'Check this',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: WordShapeFlowPreview(
              shapes: shapes,
              child: const Text('Question text remains readable.'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Question text remains readable.'), findsOneWidget);
    expect(find.text('Check this'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all Phase 4B shape kinds render on a narrow phone width', (
    tester,
  ) async {
    final shapes = [
      for (final entry in WordShapeKind.values.indexed)
        WordShapeObject(
          id: 'shape-${entry.$1}',
          kind: entry.$2,
          x: (entry.$1 % 4) * 0.22,
          y: (entry.$1 ~/ 4) * 0.42,
          width: 0.20,
          height: 0.32,
          wrapMode: WordTextWrapMode.topAndBottom,
          text: entry.$2 == WordShapeKind.textBox ? 'Text' : '',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: WordShapeFlowPreview(
              shapes: shapes,
              child: const Text('Body'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
