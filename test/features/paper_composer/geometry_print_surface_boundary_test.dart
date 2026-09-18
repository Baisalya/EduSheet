import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_rich_text_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('read-only question preview renders geometry content without editor chrome', (
    tester,
  ) async {
    const diagram = GeometryDiagram(
      id: 'preview-rectangle',
      name: 'Rectangle',
      showGrid: false,
    );
    final layout = GeometryEmbedLayout(
      id: diagram.id,
      diagram: diagram,
      height: 240,
      wrapMode: GeometryEmbedWrapMode.topAndBottom,
    );
    final question = Question(
      id: 'q1',
      text: jsonEncode([
        {'insert': 'Study the diagram.\n'},
        {
          'insert': {'geometry': layout.encode()},
        },
        {'insert': '\nAnswer the question.\n'},
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: QuestionRichTextPreview(
              question: question,
              maxHeight: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final printable = find.byKey(
      const ValueKey('geometry-printable-preview-rectangle'),
    );
    expect(printable, findsOneWidget);
    expect(tester.getSize(printable).height, 240);
    expect(find.text('Rectangle • Top & bottom'), findsNothing);
    expect(
      find.text(
        'Drag sideways to position • drag corner to resize • double-tap to edit',
      ),
      findsNothing,
    );
  });
}
