import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/question_bank/data/repositories/local_question_bank_repository.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository round-trip preserves complete modern Question payload', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-bank-');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/question_bank.json');
    final repository = LocalQuestionBankRepository(
      fileResolver: () async => file,
    );

    final entry = QuestionBankQuestion.fromQuestion(
      Question(
        id: 'master',
        text: 'Explain the result.',
        marks: 4,
        negativeMarks: 1,
        difficulty: QuestionDifficulty.hard,
        grade: 'Class 9',
        subject: 'Physics',
        chapter: 'Motion',
        topic: 'Acceleration',
        correctAnswer: 'Explanation',
        explanation: 'Teacher note',
        tags: const ['revision', 'important'],
        tableData: const QuestionTable(
          headers: ['Time', 'Speed'],
          rows: [
            ['1', '5'],
          ],
        ),
        subQuestions: [Question(id: 'part', text: 'State the unit.')],
      ),
      isFavorite: true,
    );

    await repository.addQuestion(entry);
    final restored = (await repository.getAllQuestions()).single;

    expect(restored.question.id, 'master');
    expect(restored.question.marks, 4);
    expect(restored.question.negativeMarks, 1);
    expect(restored.question.difficulty, QuestionDifficulty.hard);
    expect(restored.question.grade, 'Class 9');
    expect(restored.question.topic, 'Acceleration');
    expect(restored.question.correctAnswer, 'Explanation');
    expect(restored.question.explanation, 'Teacher note');
    expect(restored.question.tags, ['revision', 'important']);
    expect(restored.question.tableData?.headers, ['Time', 'Speed']);
    expect(restored.question.subQuestions.single.text, 'State the unit.');
    expect(restored.isFavorite, isTrue);
  });

  test('repository imports the legacy flat Question Bank JSON format', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-bank-');
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/question_bank.json');
    final repository = LocalQuestionBankRepository(
      fileResolver: () async => file,
    );

    final legacy = Question(
      id: 'legacy',
      text: 'Legacy hard question',
      subject: 'Chemistry',
      chapter: 'Atoms',
      difficulty: QuestionDifficulty.hard,
    ).toJson()
      ..['difficulty'] = Difficulty.hard.index
      ..['isFavorite'] = true;

    await repository.importFromJson(jsonEncode([legacy]));
    final restored = (await repository.getAllQuestions()).single;

    expect(restored.question.id, 'legacy');
    expect(restored.subject, 'Chemistry');
    expect(restored.chapter, 'Atoms');
    expect(restored.difficulty, Difficulty.hard);
    expect(restored.question.difficulty, QuestionDifficulty.hard);
    expect(restored.isFavorite, isTrue);
  });
}
