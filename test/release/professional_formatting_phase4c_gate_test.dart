import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Phase 4C canonical paper preserves geometry placement and free-form drawing',
    () {
      final diagram = _diagram();
      final layout = GeometryEmbedLayout(
        id: diagram.id,
        diagram: diagram,
        height: 236,
        widthFactor: 0.7,
        alignmentX: 1,
        marginTop: 6,
        marginBottom: 18,
        wrapMode: GeometryEmbedWrapMode.squareRight,
      );
      var question = Question(
        id: 'q1',
        text: jsonEncode([
          {'insert': 'Study the construction below.\n'},
          {
            'insert': {'geometry': layout.encode()},
          },
          {'insert': '\nFind the angle and read the number line.\n'},
        ]),
        marks: 5,
      );
      question = WordShapeService.append(
        question,
        const WordShapeObject(
          id: 'phase4c-callout',
          kind: WordShapeKind.callout,
          text: 'Show working',
          wrapMode: WordTextWrapMode.squareLeft,
        ),
      );

      final paper = Paper(
        id: 'phase4c',
        title: 'Phase 4C Gate',
        createdAt: DateTime.utc(2026, 9, 2),
        sections: [
          PaperSection(id: 's1', title: 'Section A', questions: [question]),
        ],
      );

      final restored = Paper.fromJson(paper.toJson());
      final restoredQuestion = restored.sections.single.questions.single;
      final embeds = geometryEmbedsFromQuillText(restoredQuestion.text);

      expect(restored.totalMarks, 5);
      expect(embeds, hasLength(1));
      expect(embeds.single.wrapMode, GeometryEmbedWrapMode.squareRight);
      expect(embeds.single.marginTop, 6);
      expect(embeds.single.marginBottom, 18);
      expect(embeds.single.diagram?.toJson(), diagram.toJson());
      expect(restoredQuestion.plainTextAccessibility, contains('[diagram]'));
      expect(WordShapeService.shapesOf(restoredQuestion), hasLength(1));
    },
  );

  test(
    'Phase 4C free-form helper diagram remains ordinary assessment content',
    () {
      final layout = GeometryEmbedLayout.forDiagram(_diagram());
      final question = Question(
        id: 'q-helper',
        text: jsonEncode([
          {'insert': 'Plot and label.\n'},
          {
            'insert': {'geometry': layout.encode()},
          },
          {'insert': '\n'},
        ]),
        marks: 3,
      );
      final paper = Paper(
        id: 'helper',
        title: 'Helper',
        createdAt: DateTime.utc(2026, 9, 2),
        sections: [
          PaperSection(id: 's1', title: 'A', questions: [question]),
        ],
      );

      expect(question.isWordContentBlock, isFalse);
      expect(paper.totalMarks, 3);
      expect(
        geometryEmbedsFromQuillText(question.text).single.diagram,
        isNotNull,
      );
    },
  );
}

GeometryDiagram _diagram() {
  return const GeometryDiagram(
    id: 'release-geometry',
    points: [
      GeometryPoint(id: 'a', label: 'A', position: Offset(100, 120)),
      GeometryPoint(id: 'b', label: 'B', position: Offset(190, 120)),
      GeometryPoint(id: 'c', label: 'C', position: Offset(100, 40)),
      GeometryPoint(id: 'top', label: '', position: Offset(260, 30)),
      GeometryPoint(id: 'bottom', label: '', position: Offset(260, 190)),
      GeometryPoint(id: 'left', label: '', position: Offset(190, 110)),
      GeometryPoint(id: 'right', label: '', position: Offset(330, 110)),
      GeometryPoint(id: 'n1', label: '', position: Offset(30, 210)),
      GeometryPoint(id: 'n2', label: '', position: Offset(330, 210)),
    ],
    shapes: [
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
        id: 'line',
        type: GeometryShapeType.numberLine,
        pointIds: ['n1', 'n2'],
      ),
    ],
    marks: [
      GeometryMark(
        id: 'angle',
        type: GeometryMarkType.angleArc,
        pointIds: ['a', 'b', 'c'],
        position: Offset(100, 120),
      ),
    ],
  );
}
