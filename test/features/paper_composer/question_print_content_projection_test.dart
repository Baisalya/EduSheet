import 'dart:convert';

import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/application/question_print_content_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('print projection separates printable geometry from editor metadata', () {
    const diagram = GeometryDiagram(
      id: 'rect-1',
      name: 'Rectangle',
      showGrid: false,
    );
    final layout = GeometryEmbedLayout(
      id: diagram.id,
      diagram: diagram,
      height: 260,
      widthFactor: 0.72,
      wrapMode: GeometryEmbedWrapMode.topAndBottom,
    );
    final richText = jsonEncode([
      {'insert': 'Find the area.\n'},
      {
        'insert': {'geometry': layout.encode()},
      },
      {'insert': '\nShow all working.\n'},
    ]);

    final projection = QuestionPrintContentProjection.fromRichText(richText);

    expect(projection.isStructuredRichText, isTrue);
    expect(
      projection.objects.map((object) => object.kind),
      [
        QuestionPrintContentKind.richText,
        QuestionPrintContentKind.geometry,
        QuestionPrintContentKind.richText,
      ],
    );
    expect(projection.geometryEmbeds.single.id, 'rect-1');
    expect(projection.geometryEmbeds.single.height, 260);
    expect(projection.accessibleText, 'Find the area. [diagram] Show all working.');
    expect(projection.accessibleText, isNot(contains('Rectangle')));
    expect(projection.accessibleText, isNot(contains('Top & bottom')));
  });

  test('malformed math embed becomes a printable fallback instead of throwing', () {
    final richText = jsonEncode([
      {'insert': 'Solve '},
      {
        'insert': {'edusheetMath': 'not-json'},
      },
      {'insert': ' now.'},
    ]);

    final projection = QuestionPrintContentProjection.fromRichText(richText);

    expect(projection.isStructuredRichText, isTrue);
    expect(projection.accessibleText, contains('Solve'));
    expect(projection.accessibleText, contains('now.'));
  });
}
