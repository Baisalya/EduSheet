import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'section numbering overrides paper numbering without changing questions',
    () {
      final paper = Paper(
        id: 'p1',
        title: 'Test',
        questionNumberStyle: QuestionNumberStyle.upperRoman,
        createdAt: DateTime(2026, 8, 31),
      );
      final inherited = PaperSection(id: 's1', title: 'A');
      final overridden = PaperSection(
        id: 's2',
        title: 'B',
        numberingStyle: QuestionNumberStyle.lowerAlpha,
      );

      expect(PaperStructureService.questionLabel(2, paper, inherited), 'II');
      expect(PaperStructureService.questionLabel(2, paper, overridden), 'b');
    },
  );

  test('answer-any rule counts only compulsory question slots', () {
    final section = PaperSection(
      id: 's1',
      title: 'Section A',
      requiredCount: 2,
      questions: [
        Question(id: 'q1', text: 'One'),
        Question(id: 'q2', text: 'Two'),
        Question(id: 'q3', text: 'Three'),
        Question(id: 'q4', text: 'OR', isOptional: true),
      ],
    );

    expect(
      PaperStructureService.answerRuleText(section),
      'Answer any 2 of 3 questions.',
    );
  });

  test(
    'answer-any note disappears when all compulsory questions are required',
    () {
      final section = PaperSection(
        id: 's1',
        title: 'Section A',
        requiredCount: 2,
        questions: [
          Question(id: 'q1', text: 'One'),
          Question(id: 'q2', text: 'Two'),
        ],
      );

      expect(PaperStructureService.answerRuleText(section), isNull);
    },
  );
}
