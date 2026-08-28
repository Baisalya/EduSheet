import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/providers/question_bank_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nullable filters can be cleared after being selected', () {
    const state = QuestionBankState(
      selectedSubject: 'Math',
      selectedChapter: 'Algebra',
      selectedDifficulty: Difficulty.hard,
      selectedType: QuestionType.mcq,
    );

    final cleared = state.copyWith(
      selectedSubject: null,
      selectedChapter: null,
      selectedDifficulty: null,
      selectedType: null,
    );

    expect(cleared.selectedSubject, isNull);
    expect(cleared.selectedChapter, isNull);
    expect(cleared.selectedDifficulty, isNull);
    expect(cleared.selectedType, isNull);
  });

  test('filters modern question type without losing favorites ordering', () {
    final favorite = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'fav',
        text: 'Favorite MCQ',
        type: QuestionType.mcq,
        subject: 'Math',
        chapter: 'Algebra',
      ),
      isFavorite: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final recent = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'recent',
        text: 'Recent MCQ',
        type: QuestionType.mcq,
        subject: 'Math',
        chapter: 'Algebra',
      ),
      createdAt: DateTime.utc(2026, 8, 1),
    );
    final descriptive = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'desc',
        text: 'Long answer',
        type: QuestionType.longAnswer,
        subject: 'Math',
        chapter: 'Algebra',
      ),
    );

    final state = QuestionBankState(
      questions: [recent, descriptive, favorite],
      selectedType: QuestionType.mcq,
    );

    expect(state.filteredQuestions.map((entry) => entry.question.id), [
      'fav',
      'recent',
    ]);
  });
}
