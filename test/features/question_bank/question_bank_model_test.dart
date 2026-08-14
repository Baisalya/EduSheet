import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads legacy bank JSON whose difficulty overwrote Question metadata', () {
    final legacy = Question(
      id: 'legacy-hard',
      text: 'Hard question',
      subject: 'Physics',
      chapter: 'Motion',
      difficulty: QuestionDifficulty.hard,
      tags: const ['board'],
    ).toJson()
      ..['difficulty'] = 2
      ..['isFavorite'] = true;

    final restored = QuestionBankQuestion.fromJson(legacy);

    expect(restored.difficulty, Difficulty.hard);
    expect(restored.question.difficulty, QuestionDifficulty.hard);
    expect(restored.subject, 'Physics');
    expect(restored.chapter, 'Motion');
    expect(restored.tags, ['board']);
    expect(restored.isFavorite, isTrue);
  });

  test('new bank JSON keeps complete Question difficulty and bank metadata', () {
    final entry = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'q',
        text: 'Question',
        subject: 'Chemistry',
        chapter: 'Atoms',
        difficulty: QuestionDifficulty.easy,
        tags: const ['revision'],
      ),
      isFavorite: true,
      createdAt: DateTime.utc(2026, 8, 14),
    );

    final json = entry.toJson();
    final restored = QuestionBankQuestion.fromJson(json);

    expect(json['difficulty'], 'easy');
    expect(json['bankDifficulty'], Difficulty.easy.index);
    expect(restored.question.difficulty, QuestionDifficulty.easy);
    expect(restored.difficulty, Difficulty.easy);
    expect(restored.subject, 'Chemistry');
    expect(restored.chapter, 'Atoms');
    expect(restored.tags, ['revision']);
    expect(restored.isFavorite, isTrue);
  });
}
