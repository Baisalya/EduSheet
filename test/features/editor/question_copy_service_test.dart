import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_mark.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_point.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep copy rewrites question, option, math and geometry identities', () {
    var next = 0;
    String idFactory() => 'copy-${next++}';

    const expression = MathExpression(
      id: 'math-original',
      latex: r'\frac{x}{2}',
      plainText: 'x divided by two',
    );
    const diagram = GeometryDiagram(
      id: 'diagram-original',
      points: [
        GeometryPoint(id: 'p-a', label: 'A', position: Offset(20, 20)),
        GeometryPoint(id: 'p-b', label: 'B', position: Offset(120, 20)),
      ],
      shapes: [
        GeometryShape(
          id: 'shape-original',
          type: GeometryShapeType.line,
          pointIds: ['p-a', 'p-b'],
        ),
      ],
      marks: [
        GeometryMark(
          id: 'mark-original',
          type: GeometryMarkType.equalSideTick,
          pointIds: ['p-a', 'p-b'],
        ),
      ],
    );
    final richText = jsonEncode([
      {'insert': 'Find '},
      {
        'insert': {MathExpression.quillEmbedKey: expression.toQuillEmbedData()},
      },
      {'insert': ' using '},
      {
        'insert': {
          'geometry': jsonEncode({
            'id': diagram.id,
            'height': 200.0,
            'widthFactor': 1.0,
            'alignmentX': 0.0,
            'diagram': diagram.toJson(),
          }),
        },
      },
      {'insert': '.\n'},
    ]);
    final source = Question(
      id: 'question-original',
      text: richText,
      plainTextAccessibility: 'Find x divided by two using [diagram].',
      type: QuestionType.mcq,
      marks: 3,
      difficulty: QuestionDifficulty.hard,
      subject: 'Mathematics',
      chapter: 'Algebra',
      options: [
        QuestionOption(id: 'option-a', text: '1', isCorrect: true),
        QuestionOption(id: 'option-b', text: '2'),
      ],
      mathExpressions: const [expression],
      subQuestions: [Question(id: 'part-a', text: 'Explain.')],
      metadata: const {
        'teacher': {'source': 'own'},
      },
    );

    final copied = QuestionCopyService(
      idFactory: idFactory,
    ).copyQuestion(source, copiedAt: DateTime.utc(2026, 8, 14));

    expect(copied.id, isNot(source.id));
    final sourceOptionIds = source.options.map((item) => item.id).toSet();
    final copiedOptionIds = copied.options.map((item) => item.id).toSet();
    expect(copiedOptionIds.intersection(sourceOptionIds), isEmpty);
    expect(copied.mathExpressions.single.id, isNot(expression.id));
    expect(copied.subQuestions.single.id, isNot('part-a'));
    expect(copied.difficulty, QuestionDifficulty.hard);
    expect(copied.subject, 'Mathematics');
    expect(copied.chapter, 'Algebra');

    final operations = jsonDecode(copied.text) as List<dynamic>;
    final mathInsert = operations
        .map((item) => (item as Map<String, dynamic>)['insert'])
        .whereType<Map>()
        .firstWhere((item) => item.containsKey(MathExpression.quillEmbedKey));
    final embeddedMath = MathExpression.tryFromQuillEmbedData(
      mathInsert[MathExpression.quillEmbedKey],
    );
    expect(embeddedMath, isNotNull);
    expect(embeddedMath!.id, copied.mathExpressions.single.id);

    final geometryInsert = operations
        .map((item) => (item as Map<String, dynamic>)['insert'])
        .whereType<Map>()
        .firstWhere((item) => item.containsKey('geometry'));
    final geometryPayload =
        jsonDecode(geometryInsert['geometry'] as String)
            as Map<String, dynamic>;
    final copiedDiagram = GeometryDiagram.fromJson(
      Map<String, dynamic>.from(geometryPayload['diagram'] as Map),
    );
    expect(copiedDiagram.id, isNot(diagram.id));
    expect(geometryPayload['id'], copiedDiagram.id);
    expect(copiedDiagram.points.map((item) => item.id), isNot(contains('p-a')));
    expect(
      copiedDiagram.shapes.single.pointIds,
      copiedDiagram.points.map((point) => point.id).toList(),
    );
    expect(
      copiedDiagram.marks.single.pointIds,
      copiedDiagram.points.map((point) => point.id).toList(),
    );
  });

  test('deep copy remaps Phase-7 surface, option and math identities', () {
    var next = 0;
    const expression = MathExpression(
      id: 'surface-old',
      latex: r'\frac{1}{2}',
      plainText: 'one half',
    );
    const surface = QuestionMathInlineDocument(
      parts: [
        QuestionMathInlinePart.text('Choose '),
        QuestionMathInlinePart.math(expression),
      ],
    );
    final content = QuestionMathContent(
      surfaces: {
        'option:option-old': surface,
        'attachment:attachment-old:caption': const QuestionMathInlineDocument(
          parts: [
            QuestionMathInlinePart.text('Graph '),
            QuestionMathInlinePart.math(expression),
          ],
        ),
      },
    );
    final source = Question(
      id: 'source',
      text: 'Pick one.',
      options: [QuestionOption(id: 'option-old', text: 'Choose one half')],
      attachments: const [
        QuestionAttachment(
          id: 'attachment-old',
          kind: QuestionAttachmentKind.image,
          path: '/tmp/graph.png',
          alternativeText: 'Graph',
          caption: 'Graph one half',
        ),
      ],
      mathExpressions: const [expression],
      metadata: content.writeToMetadata(const {}),
    );

    final copied = QuestionCopyService(
      idFactory: () => 'copy-${next++}',
    ).copyQuestion(source);
    final copiedContent = QuestionMathContent.fromQuestion(copied);
    final copiedOption = copied.options.single;
    final copiedDocument = copiedContent.documentFor(
      QuestionMathSurfaceKey.option(copiedOption.id),
      currentFallback: copiedOption.text,
    );

    expect(copiedOption.id, isNot('option-old'));
    expect(copiedDocument, isNotNull);
    expect(copiedDocument!.expressions.single.id, isNot('surface-old'));
    expect(
      copied.mathExpressions.map((item) => item.id),
      contains(copiedDocument.expressions.single.id),
    );
    expect(copiedContent.surfaces, isNot(contains('option:option-old')));

    final copiedAttachment = copied.attachments.single;
    expect(copiedAttachment.id, isNot('attachment-old'));
    final copiedCaption = copiedContent.documentFor(
      QuestionMathSurfaceKey.attachmentCaption(copiedAttachment.id),
      currentFallback: copiedAttachment.caption,
    );
    expect(copiedCaption, isNotNull);
    expect(
      copiedCaption!.expressions.single.id,
      copiedDocument.expressions.single.id,
    );
    expect(
      copiedContent.surfaces,
      isNot(contains('attachment:attachment-old:caption')),
    );
  });

  test('two imports of the same master receive independent identities', () {
    var next = 0;
    final service = QuestionCopyService(idFactory: () => 'id-${next++}');
    final source = Question(
      id: 'master',
      text: 'State the theorem.',
      attachments: const [
        QuestionAttachment(
          id: 'attachment',
          kind: QuestionAttachmentKind.file,
          path: '/teacher/source.pdf',
          alternativeText: 'Source',
        ),
      ],
    );

    final first = service.copyQuestion(source);
    final second = service.copyQuestion(source);

    expect(first.id, isNot(second.id));
    expect(first.attachments.single.id, isNot(second.attachments.single.id));
    expect(first.attachments.single.path, second.attachments.single.path);
  });

  // Phase 9 regression: a corrupted source can contain the same persistent ID
  // with different payloads. Copying must map the exact payload, not whichever
  // duplicate ID happened to be visited last.
  test('copy keeps conflicting source math payloads attached correctly', () {
    var next = 0;
    const bodyExpression = MathExpression(
      id: 'conflict',
      latex: 'x',
      plainText: 'x',
    );
    const surfaceExpression = MathExpression(
      id: 'conflict',
      latex: 'y',
      plainText: 'y',
    );
    final richText = jsonEncode([
      {
        'insert': {
          MathExpression.quillEmbedKey: bodyExpression.toQuillEmbedData(),
        },
      },
      {'insert': '\n'},
    ]);
    final content = QuestionMathContent(
      surfaces: {
        QuestionMathSurfaceKey.option(
          'option',
        ): const QuestionMathInlineDocument(
          parts: [QuestionMathInlinePart.math(surfaceExpression)],
        ),
      },
    );
    final source = Question(
      id: 'source-conflict',
      text: richText,
      options: [QuestionOption(id: 'option', text: 'y')],
      mathExpressions: const [bodyExpression, surfaceExpression],
      metadata: content.writeToMetadata(const {}),
    );

    final copied = QuestionCopyService(
      idFactory: () => 'copy-${next++}',
    ).copyQuestion(source);
    final operations = jsonDecode(copied.text) as List<dynamic>;
    final mathInsert = operations
        .map((item) => (item as Map<String, dynamic>)['insert'])
        .whereType<Map>()
        .firstWhere((item) => item.containsKey(MathExpression.quillEmbedKey));
    final copiedBody = MathExpression.tryFromQuillEmbedData(
      mathInsert[MathExpression.quillEmbedKey],
    );
    final copiedSurface = QuestionMathContent.fromQuestion(copied)
        .documentFor(
          QuestionMathSurfaceKey.option(copied.options.single.id),
          currentFallback: copied.options.single.text,
        )!
        .expressions
        .single;

    expect(copiedBody?.latex, 'x');
    expect(copiedSurface.latex, 'y');
    expect(copiedBody?.id, isNot(copiedSurface.id));
  });
}
