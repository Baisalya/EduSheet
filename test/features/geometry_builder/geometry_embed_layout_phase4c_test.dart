import 'dart:convert';

import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_svg_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 4C geometry embed placement survives encode/decode', () {
    final diagram = _diagram();
    final original = GeometryEmbedLayout(
      id: diagram.id,
      diagram: diagram,
      height: 248,
      widthFactor: 0.64,
      alignmentX: -0.7,
      marginTop: 6,
      marginBottom: 18,
      wrapMode: GeometryEmbedWrapMode.squareLeft,
    );

    final restored = GeometryEmbedLayout.fromData(original.encode());
    expect(restored.id, diagram.id);
    expect(restored.height, 248);
    expect(restored.widthFactor, 0.64);
    expect(restored.marginTop, 6);
    expect(restored.marginBottom, 18);
    expect(restored.wrapMode, GeometryEmbedWrapMode.squareLeft);
    expect(restored.effectiveAlignmentX, -1);
    expect(restored.diagram?.toJson(), diagram.toJson());
  });

  test('legacy geometry embed payload keeps compatible defaults', () {
    final legacy = jsonEncode({
      'id': 'legacy-diagram',
      'height': 180,
      'widthFactor': 0.75,
      'alignmentX': 1,
    });
    final restored = GeometryEmbedLayout.fromData(legacy);

    expect(restored.id, 'legacy-diagram');
    expect(restored.height, 180);
    expect(restored.widthFactor, 0.75);
    expect(restored.alignmentX, 1);
    expect(restored.wrapMode, GeometryEmbedWrapMode.topAndBottom);
    expect(restored.marginTop, GeometryEmbedLayout.defaultMargin);
    expect(restored.marginBottom, GeometryEmbedLayout.defaultMargin);
  });

  test('Quill geometry extraction keeps canonical document order', () {
    final first = GeometryEmbedLayout.forDiagram(_diagram(id: 'g1')).encode();
    final second = GeometryEmbedLayout(
      id: 'g2',
      diagram: _diagram(id: 'g2'),
      wrapMode: GeometryEmbedWrapMode.squareRight,
    ).encode();
    final richText = jsonEncode([
      {'insert': 'Before\n'},
      {
        'insert': {'geometry': first},
      },
      {'insert': '\nMiddle\n'},
      {
        'insert': {'geometry': second},
      },
      {'insert': '\nAfter\n'},
    ]);

    final embeds = geometryEmbedsFromQuillText(richText);
    expect(embeds.map((item) => item.id), ['g1', 'g2']);
    expect(embeds.last.wrapMode, GeometryEmbedWrapMode.squareRight);
  });

  test('SVG export includes free-form axes number line and angle arc', () {
    final svg = GeometrySvgService().toSvg(_diagram());
    expect(svg, contains('<svg'));
    expect(svg, contains('<line'));
    expect(svg, contains('<path'));
    expect(svg, contains('>A</text>'));
    expect(svg, contains('>x</text>'));
    expect(svg, isNot(contains('[diagram]')));
  });
}

GeometryDiagram _diagram({String id = 'phase4c-diagram'}) {
  const a = GeometryPoint(id: 'a', label: 'A', position: Offset(120, 120));
  const b = GeometryPoint(id: 'b', label: 'B', position: Offset(200, 120));
  const c = GeometryPoint(id: 'c', label: 'C', position: Offset(120, 40));
  const top = GeometryPoint(id: 'top', label: '', position: Offset(260, 30));
  const bottom = GeometryPoint(
    id: 'bottom',
    label: '',
    position: Offset(260, 190),
  );
  const left = GeometryPoint(id: 'left', label: '', position: Offset(190, 110));
  const right = GeometryPoint(
    id: 'right',
    label: '',
    position: Offset(330, 110),
  );
  const n1 = GeometryPoint(id: 'n1', label: '', position: Offset(30, 210));
  const n2 = GeometryPoint(id: 'n2', label: '', position: Offset(330, 210));
  return GeometryDiagram(
    id: id,
    points: const [a, b, c, top, bottom, left, right, n1, n2],
    shapes: const [
      GeometryShape(
        id: 'ab',
        type: GeometryShapeType.line,
        pointIds: ['a', 'b'],
      ),
      GeometryShape(
        id: 'ac',
        type: GeometryShapeType.line,
        pointIds: ['a', 'c'],
      ),
      GeometryShape(
        id: 'axes',
        type: GeometryShapeType.coordinateAxes,
        pointIds: ['top', 'bottom', 'left', 'right'],
      ),
      GeometryShape(
        id: 'number-line',
        type: GeometryShapeType.numberLine,
        pointIds: ['n1', 'n2'],
      ),
    ],
    marks: const [
      GeometryMark(
        id: 'angle',
        type: GeometryMarkType.angleArc,
        pointIds: ['a', 'b', 'c'],
        position: Offset(120, 120),
      ),
    ],
  );
}
