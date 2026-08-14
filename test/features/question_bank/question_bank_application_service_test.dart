import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/question_bank/application/question_bank_application_service.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paper question becomes an independent reusable master with fallbacks', () {
    var next = 0;
    final service = QuestionBankApplicationService(
      QuestionCopyService(idFactory: () => 'copy-${next++}'),
    );
    final paperQuestion = Question(
      id: 'paper-question',
      text: 'Solve x + 2 = 5',
      plainTextAccessibility: 'Solve x + 2 = 5',
      marks: 2,
      difficulty: QuestionDifficulty.hard,
    );

    final master = service.createMasterCopy(
      paperQuestion,
      fallbackSubject: 'Mathematics',
      fallbackChapter: 'Linear equations',
      fallbackGrade: 'Class 8',
    );

    expect(master.question.id, isNot(paperQuestion.id));
    expect(master.subject, 'Mathematics');
    expect(master.chapter, 'Linear equations');
    expect(master.question.grade, 'Class 8');
    expect(master.difficulty, Difficulty.hard);
  });

  test('importing a master twice produces independent paper questions', () {
    var next = 0;
    final service = QuestionBankApplicationService(
      QuestionCopyService(idFactory: () => 'copy-${next++}'),
    );
    final master = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'master',
        text: 'Define acceleration.',
        subject: 'Physics',
        chapter: 'Motion',
      ),
    );

    final first = service.copyIntoPaper(master);
    final second = service.copyIntoPaper(master);

    expect(first.id, isNot(master.question.id));
    expect(second.id, isNot(master.question.id));
    expect(first.id, isNot(second.id));
  });

  test('duplicate signature ignores spacing and case but respects type', () {
    final service = QuestionBankApplicationService(QuestionCopyService());
    final existing = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'existing',
        text: 'Find X.',
        plainTextAccessibility: 'Find X.',
        type: QuestionType.shortAnswer,
        subject: 'Math',
        chapter: 'Algebra',
      ),
    );

    final duplicate = Question(
      id: 'new',
      text: 'find   x.',
      plainTextAccessibility: 'find   x.',
      type: QuestionType.shortAnswer,
      subject: 'Math',
      chapter: 'Algebra',
    );
    final differentType = duplicate.copyWith(type: QuestionType.longAnswer);

    expect(service.findLikelyDuplicate(duplicate, [existing]), existing);
    expect(service.findLikelyDuplicate(differentType, [existing]), isNull);
  });
}
