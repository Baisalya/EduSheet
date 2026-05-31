import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats supported question numbering styles', () {
    expect(
      QuestionNumberingService.label(27, QuestionNumberStyle.lowerAlpha),
      'aa',
    );
    expect(
      QuestionNumberingService.label(4, QuestionNumberStyle.upperRoman),
      'IV',
    );
    expect(
      QuestionNumberingService.label(12, QuestionNumberStyle.hindiDigits),
      '१२',
    );
    expect(
      QuestionNumberingService.label(12, QuestionNumberStyle.odiaDigits),
      '୧୨',
    );
    expect(
      QuestionNumberingService.label(2, QuestionNumberStyle.hindiLetters),
      'ख',
    );
    expect(
      QuestionNumberingService.label(3, QuestionNumberStyle.odiaLetters),
      'ଗ',
    );
    expect(
      QuestionNumberingService.label(23, QuestionNumberStyle.englishWords),
      'twenty-three',
    );
    expect(
      QuestionNumberingService.label(
        2,
        QuestionNumberStyle.custom,
        customLabels: ['Q-A', 'Q-B'],
      ),
      'Q-B',
    );
  });

  test('persists paper question numbering style', () {
    final paper = Paper(
      id: 'paper-1',
      title: 'Test',
      createdAt: DateTime(2026),
      questionNumberStyle: QuestionNumberStyle.odiaDigits,
      customQuestionNumberLabels: const ['କ', 'ଖ', 'ଗ'],
    );

    final restored = Paper.fromJson(paper.toJson());

    expect(restored.questionNumberStyle, QuestionNumberStyle.odiaDigits);
    expect(restored.customQuestionNumberLabels, ['କ', 'ଖ', 'ଗ']);
  });
}
