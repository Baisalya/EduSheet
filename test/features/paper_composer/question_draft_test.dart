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
      expect(updated.internalChoices.map((item) => item.id),
          original.internalChoices.map((item) => item.id));
      expect(updated.metadata['custom'], 'preserve-me');
      expect(updated.version, 8);
    });

    test('changing to option type creates options without changing storage enum', () {
      final draft = QuestionDraft.create().copyWith(type: QuestionType.mcq);

      expect(draft.type, QuestionType.mcq);
      expect(draft.options, hasLength(4));
      expect(draft.options.map((item) => item.id).toSet(), hasLength(4));
    });

    test('changing away from option type clears transient answer options', () {
      final draft = QuestionDraft.create(type: QuestionType.mcq)
          .copyWith(type: QuestionType.shortAnswer);

      expect(draft.options, isEmpty);
    });

    test('true/false transitions use semantically correct option sets', () {
      final trueFalse = QuestionDraft.create(type: QuestionType.mcq)
          .copyWith(type: QuestionType.trueFalse);

      expect(trueFalse.options.map((item) => item.text), ['True', 'False']);

      final mcq = trueFalse.copyWith(type: QuestionType.mcq);
      expect(mcq.options, hasLength(4));
      expect(mcq.options.every((item) => item.text.isEmpty), isTrue);
    });
  });
}

