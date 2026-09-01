import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/universal_question_adapter.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'universal document allows formerly exclusive structures to coexist',
    () {
      final draft = QuestionDraft.fromQuestion(
        Question(
          id: 'mixed',
          text: 'Read the data and answer.',
          type: QuestionType.caseStudy,
          options: [
            QuestionOption(id: 'a', text: 'One'),
            QuestionOption(id: 'b', text: 'Two'),
          ],
          attachments: const [
            QuestionAttachment(
              id: 'diagram',
              kind: QuestionAttachmentKind.diagram,
              path: '/tmp/diagram.json',
              alternativeText: 'A diagram',
            ),
          ],
          tableData: const QuestionTable(
            headers: ['x', 'y'],
            rows: [
              ['1', '2'],
            ],
          ),
          subQuestions: [Question(id: 'part-a', text: 'Part A')],
          internalChoices: [Question(id: 'choice-b', text: 'Alternative B')],
        ),
      );

      final document = UniversalQuestionAdapter.fromDraft(draft);

      expect(document.contains(UniversalQuestionBlockKind.prompt), isTrue);
      expect(
        document.contains(UniversalQuestionBlockKind.answerOptions),
        isTrue,
      );
      expect(document.contains(UniversalQuestionBlockKind.attachment), isTrue);
      expect(document.contains(UniversalQuestionBlockKind.table), isTrue);
      expect(
        document.contains(UniversalQuestionBlockKind.subQuestions),
        isTrue,
      );
      expect(
        document.contains(UniversalQuestionBlockKind.internalChoice),
        isTrue,
      );
      expect(document.itemCount(UniversalQuestionBlockKind.answerOptions), 2);
      expect(document.hasStructuredContent, isTrue);
    },
  );

  test('plain manual question stays a one-block universal document', () {
    final draft = QuestionDraft.create();
    final document = UniversalQuestionAdapter.fromDraft(draft);

    expect(document.blocks, hasLength(1));
    expect(document.blocks.single.kind, UniversalQuestionBlockKind.prompt);
    expect(UniversalQuestionAdapter.authoringSummary(draft), 'Free writing');
  });
}
