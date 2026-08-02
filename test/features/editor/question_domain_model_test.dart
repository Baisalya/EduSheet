import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Question domain model', () {
    test('keeps every supported question type stable through JSON', () {
      for (final type in QuestionType.values) {
        final question = Question(
          id: 'id-${type.name}',
          text: type.label,
          type: type,
        );

        final restored = Question.fromJson(question.toJson());

        expect(restored.type, type, reason: type.name);
        expect(restored.id, question.id);
      }
    });

    test('preserves canonical formula source and accessible fallback', () {
      final question = Question(
        id: 'math-1',
        text: 'Solve the equation',
        type: QuestionType.mathematicalExpression,
        mathExpressions: const [
          MathExpression(
            id: 'formula-1',
            latex: r'\frac{x^2}{2}=8',
            plainText: 'x squared divided by two equals eight',
            display: MathExpressionDisplay.block,
          ),
        ],
      );

      final restored = Question.fromJson(question.toJson());

      expect(restored.mathExpressions, hasLength(1));
      expect(restored.mathExpressions.single.latex, r'\frac{x^2}{2}=8');
      expect(
        restored.mathExpressions.single.plainText,
        'x squared divided by two equals eight',
      );
      expect(
        restored.mathExpressions.single.display,
        MathExpressionDisplay.block,
      );
    });

    test('round trips metadata, attachments, table, parts and choices', () {
      final now = DateTime.utc(2026, 7, 19, 1, 2, 3);
      final question = Question(
        id: 'case-study-1',
        text: 'Read the case and answer.',
        type: QuestionType.caseStudy,
        negativeMarks: 0.25,
        correctAnswer: 'Structured answer',
        explanation: 'Teacher solution',
        estimatedAnswerMinutes: 12,
        difficulty: QuestionDifficulty.hard,
        grade: '10',
        subject: 'Mathematics',
        chapter: 'Algebra',
        topic: 'Quadratics',
        learningObjective: 'Apply the quadratic formula',
        cognitiveLevel: CognitiveLevel.apply,
        tags: const ['board', 'algebra'],
        language: 'en-IN',
        instructions: 'Show all work.',
        sourceReference: 'Teacher handbook p. 12',
        attachments: const [
          QuestionAttachment(
            id: 'diagram-1',
            kind: QuestionAttachmentKind.diagram,
            path: '/safe/diagram.svg',
            alternativeText: 'A labelled parabola',
          ),
        ],
        tableData: const QuestionTable(
          headers: ['x', 'y'],
          rows: [
            ['1', '2'],
            ['2', '4'],
          ],
          accessibilitySummary: 'Values of x and y',
        ),
        subQuestions: [
          Question(id: 'part-a', text: 'Find the discriminant.'),
        ],
        internalChoices: [
          Question(id: 'choice-b', text: 'Or, factorise the expression.'),
        ],
        createdAt: now,
        modifiedAt: now,
        version: 4,
        status: QuestionStatus.draft,
        metadata: const {'customType': 'school-specific'},
      );

      final restored = Question.fromJson(question.toJson());

      expect(restored.negativeMarks, 0.25);
      expect(restored.difficulty, QuestionDifficulty.hard);
      expect(restored.cognitiveLevel, CognitiveLevel.apply);
      expect(restored.attachments.single.alternativeText, 'A labelled parabola');
      expect(restored.tableData!.rows, hasLength(2));
      expect(restored.subQuestions.single.id, 'part-a');
      expect(restored.internalChoices.single.id, 'choice-b');
      expect(restored.version, 4);
      expect(restored.status, QuestionStatus.draft);
      expect(restored.metadata['customType'], 'school-specific');
    });

    test('uses safe fallbacks for unknown future enum values', () {
      final restored = Question.fromJson({
        'id': 'future',
        'text': 'Future question',
        'type': 999,
        'typeName': 'notInstalledYet',
        'alignment': 999,
        'difficulty': 'extreme',
      });

      expect(restored.type, QuestionType.descriptive);
      expect(restored.difficulty, QuestionDifficulty.medium);
    });

    test('derives readable text from legacy Quill Delta', () {
      final question = Question.fromJson({
        'id': 'legacy-rich',
        'text': '[{"insert":"Find x.\\n"}]',
        'type': 1,
      });

      expect(question.plainTextAccessibility, 'Find x.');
    });
  });
}
