import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/paper_composer/application/question_document_projection.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('question projection exposes printable and structured content separately', () {
    const diagram = GeometryDiagram(id: 'g1', name: 'Rectangle');
    final geometry = GeometryEmbedLayout.forDiagram(diagram);
    var question = Question(
      id: 'q1',
      text: jsonEncode([
        {'insert': 'Find the perimeter.\n'},
        {
          'insert': {'geometry': geometry.encode()},
        },
        {'insert': '\n'},
      ]),
      options: [QuestionOption(id: 'a', text: '10 cm')],
      attachments: const [
        QuestionAttachment(
          id: 'img-1',
          kind: QuestionAttachmentKind.image,
          path: '/tmp/example.png',
          alternativeText: 'Reference image',
        ),
      ],
    );
    question = WordShapeService.append(
      question,
      const WordShapeObject(
        id: 'textbox-1',
        kind: WordShapeKind.textBox,
        text: 'Teacher note',
      ),
    );

    final document = QuestionDocumentProjection.fromQuestion(question);

    expect(document.prompt.accessibleText, contains('[diagram]'));
    expect(document.hasGeometry, isTrue);
    expect(document.hasFloatingObjects, isTrue);
    expect(document.wordShapes.single.id, 'textbox-1');
    expect(
      document.containsBlock(UniversalQuestionBlockKind.answerOptions),
      isTrue,
    );
    expect(
      document.containsBlock(UniversalQuestionBlockKind.attachment),
      isTrue,
    );
  });

  test('paper projection preserves section and question order', () {
    final paper = Paper(
      id: 'p1',
      title: 'Test',
      createdAt: DateTime(2026, 9, 17),
      sections: [
        PaperSection(
          id: 's1',
          title: 'A',
          questions: [
            Question(id: 'q1', text: 'One'),
            Question(id: 'q2', text: 'Two'),
          ],
        ),
      ],
    );

    final document = PaperDocumentProjection.fromPaper(paper);

    expect(document.sections.map((section) => section.source.id), ['s1']);
    expect(
      document.sections.single.questions.map((question) => question.source.id),
      ['q1', 'q2'],
    );
  });
}
