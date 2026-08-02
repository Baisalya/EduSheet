import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = PaperValidator();

  test('calculates optional attempt rules and accepts matching maximum marks', () {
    final paper = _paper(
      maximumMarks: 5,
      requiredCount: 2,
      questions: [
        Question(id: 'q1', text: 'One', marks: 2),
        Question(id: 'q2', text: 'Two', marks: 3),
        Question(id: 'q3', text: 'Three', marks: 1),
      ],
    );

    final result = validator.validate(paper);

    expect(result.calculatedMarks, 5);
    expect(result.issues.where((issue) => issue.code == 'marks.mismatch'), isEmpty);
  });

  test('reports mark mismatch, missing marks and invalid attempt rule', () {
    final paper = _paper(
      maximumMarks: 20,
      requiredCount: 3,
      questions: [Question(id: 'q1', text: 'One', marks: 0)],
    );

    final codes = validator.validate(paper).issues.map((issue) => issue.code);

    expect(codes, contains('marks.mismatch'));
    expect(codes, contains('question.marks_missing'));
    expect(codes, contains('section.invalid_attempt_rule'));
  });

  test('reports empty sections, duplicate IDs and duplicate custom labels', () {
    final paper = Paper(
      id: 'paper',
      title: 'Paper',
      createdAt: DateTime.utc(2026, 7, 19),
      questionNumberStyle: QuestionNumberStyle.custom,
      customQuestionNumberLabels: const ['A', 'A'],
      sections: [
        PaperSection(id: 'empty', title: 'Empty'),
        PaperSection(
          id: 'filled',
          title: 'Filled',
          questions: [
            Question(id: 'duplicate', text: 'One'),
            Question(id: 'duplicate', text: 'Two'),
          ],
        ),
      ],
    );

    final codes = validator.validate(paper).issues.map((issue) => issue.code);

    expect(codes, contains('section.empty'));
    expect(codes, contains('question.duplicate_id'));
    expect(codes, contains('numbering.duplicate'));
  });

  test('reports unresolved template variables and incomplete internal choice', () {
    final paper = _paper(
      questions: [
        Question(
          id: 'choice',
          text: 'Answer {{topic}}',
          type: QuestionType.internalChoice,
          internalChoices: [Question(id: 'a', text: 'Only one alternative')],
        ),
      ],
    );

    final codes = validator.validate(paper).issues.map((issue) => issue.code);

    expect(codes, contains('template.unresolved'));
    expect(codes, contains('question.internal_choice_incomplete'));
  });
}

Paper _paper({
  double? maximumMarks,
  int? requiredCount,
  List<Question> questions = const [],
}) {
  return Paper(
    id: 'paper',
    title: 'Paper',
    maximumMarks: maximumMarks,
    createdAt: DateTime.utc(2026, 7, 19),
    sections: [
      PaperSection(
        id: 'section',
        title: 'Section A',
        requiredCount: requiredCount,
        questions: questions,
      ),
    ],
  );
}
