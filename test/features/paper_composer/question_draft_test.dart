import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuestionDraft', () {
    test('preserves advanced persisted fields when editing core fields', () {
      final original = Question(
        id: 'q-1',
        text: 'Old text',
        type: QuestionType.longAnswer,
        marks: 5,
        imageUrl: '/tmp/legacy-diagram.png',
        negativeMarks: 0.5,
        correctAnswer: '42',
        explanation: 'Because it is the answer.',
        estimatedAnswerMinutes: 8,
        difficulty: QuestionDifficulty.hard,
        grade: '10',
        subject: 'Mathematics',
        chapter: 'Algebra',
        topic: 'Quadratics',
        learningObjective: 'Solve quadratic equations',
        tags: const ['exam', 'algebra'],
        instructions: 'Show all work.',
        language: 'en-IN',
        sourceReference: 'Teacher bank',
        attachments: const [
          QuestionAttachment(
            id: 'attachment-1',
            kind: QuestionAttachmentKind.diagram,
            path: '/tmp/geometry.json',
            alternativeText: 'Triangle ABC',
          ),
        ],
        tableData: const QuestionTable(
          headers: ['x', 'y'],
          rows: [
            ['1', '2'],
          ],
          caption: 'Values',
        ),
        subQuestions: [Question(id: 'sub-1', text: 'Part a')],
        internalChoices: [
          Question(id: 'choice-1', text: 'Alternative one'),
          Question(id: 'choice-2', text: 'Alternative two'),
        ],
        mathExpressions: const [
          MathExpression(
            id: 'm-1',
            latex: r'x^2=4',
            plainText: 'x squared equals four',
          ),
        ],
        metadata: const {'custom': 'preserve-me'},
        version: 7,
      );

      final updated = QuestionDraft.fromQuestion(original)
          .copyWith(text: 'New text', marks: 8)
          .toQuestion(plainTextAccessibility: 'New text');

      expect(updated.text, 'New text');
      expect(updated.marks, 8);
      expect(updated.imageUrl, original.imageUrl);
      expect(updated.negativeMarks, original.negativeMarks);
      expect(updated.correctAnswer, original.correctAnswer);
      expect(updated.explanation, original.explanation);
      expect(updated.estimatedAnswerMinutes, original.estimatedAnswerMinutes);
      expect(updated.difficulty, original.difficulty);
      expect(updated.grade, original.grade);
      expect(updated.subject, original.subject);
      expect(updated.chapter, original.chapter);
      expect(updated.topic, original.topic);
      expect(updated.learningObjective, original.learningObjective);
      expect(updated.tags, original.tags);
      expect(updated.instructions, original.instructions);
      expect(updated.language, original.language);
      expect(updated.sourceReference, original.sourceReference);
      expect(updated.attachments.single.id, original.attachments.single.id);
      expect(updated.tableData?.caption, original.tableData?.caption);
      expect(updated.subQuestions.single.id, original.subQuestions.single.id);
      expect(
        updated.internalChoices.map((item) => item.id),
        original.internalChoices.map((item) => item.id),
      );
      expect(updated.metadata['custom'], 'preserve-me');
      expect(updated.version, 8);
    });

    test(
      'quick start creates option helpers without changing storage contract',
      () {
        final draft = QuestionDraft.create().applyQuickStart(QuestionType.mcq);

        expect(draft.type, QuestionType.mcq);
        expect(draft.options, hasLength(4));
        expect(draft.options.map((item) => item.id).toSet(), hasLength(4));
      },
    );

    test('advanced structural content is explicitly editable in the draft', () {
      final draft = QuestionDraft.create().copyWith(
        tableData: const QuestionTable(
          headers: ['Word', 'Meaning'],
          rows: [
            ['A', 'B'],
          ],
        ),
        subQuestions: [Question(id: 'part-a', text: 'Part A')],
        internalChoices: [Question(id: 'or-a', text: 'Alternative')],
        attachments: const [
          QuestionAttachment(
            id: 'img-1',
            kind: QuestionAttachmentKind.image,
            path: '/tmp/image.png',
            alternativeText: 'Reference image',
          ),
        ],
      );

      final saved = draft.toQuestion(plainTextAccessibility: 'Question');
      expect(saved.tableData?.headers, ['Word', 'Meaning']);
      expect(saved.subQuestions.single.id, 'part-a');
      expect(saved.internalChoices.single.id, 'or-a');
      expect(saved.attachments.single.id, 'img-1');
    });

    test('changing legacy type never deletes composed answer options', () {
      final original = QuestionDraft.create(type: QuestionType.mcq);
      final draft = original.copyWith(type: QuestionType.shortAnswer);

      expect(draft.type, QuestionType.shortAnswer);
      expect(
        draft.options.map((item) => item.id),
        original.options.map((item) => item.id),
      );
    });

    test(
      'quick start adds required helpers without removing existing content',
      () {
        final trueFalse = QuestionDraft.create().applyQuickStart(
          QuestionType.trueFalse,
        );
        expect(trueFalse.options.map((item) => item.text), ['True', 'False']);

        final preserved = trueFalse.applyQuickStart(QuestionType.shortAnswer);
        expect(preserved.type, QuestionType.shortAnswer);
        expect(preserved.options.map((item) => item.text), ['True', 'False']);
      },
    );
  });
}
