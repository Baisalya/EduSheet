import 'dart:io';

import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/question_bank/data/repositories/local_question_bank_repository.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/smart_paper_release_fixture.dart';

void main() {
  test(
    'Question Bank preserves the complete Smart Paper question structure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'edusheet-release-bank-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final repository = LocalQuestionBankRepository(
        fileResolver: () async => File(
          '${directory.path}${Platform.pathSeparator}question_bank.json',
        ),
      );
      final source = SmartPaperReleaseFixture.advancedQuestion(
        attachmentPath:
            '${directory.path}${Platform.pathSeparator}rainfall.png',
      );

      await repository.addQuestion(
        QuestionBankQuestion.fromQuestion(source, isFavorite: true),
      );
      final restoredEntry = (await repository.getAllQuestions()).single;
      final restored = restoredEntry.question;

      expect(restored.id, source.id);
      expect(restored.subject, 'Mathematics');
      expect(restored.chapter, 'Data Handling');
      expect(restored.topic, 'Comparison');
      expect(restored.tags, ['release-gate', 'data']);
      expect(restored.options, hasLength(2));
      expect(restored.tableData?.headers, ['Village', 'Rainfall']);
      expect(restored.attachments.single.caption, 'Rainfall chart');
      expect(
        restored.attachments.single.alternativeText,
        'A simple rainfall bar chart.',
      );
      expect(restored.subQuestions.map((q) => q.id).toList(), [
        'release-part-a',
        'release-part-b',
      ]);
      expect(restored.internalChoices.map((q) => q.id).toList(), [
        'release-or-a',
        'release-or-b',
      ]);
      expect(
        QuestionOptionLayoutCodec.fromQuestion(restored),
        QuestionOptionLayout.inline,
      );
      expect((restored.metadata['legacyOwner'] as Map)['version'], 7);

      final advanced = QuestionAdvancedContent.fromQuestion(restored);
      expect(advanced.stimulus?.title, 'Rainfall evidence');
      expect(advanced.wordBank, ['increase', 'decrease', 'unchanged']);
      expect(advanced.answerSpace.style, QuestionAnswerSpaceStyle.box);
      expect(advanced.answerSpace.lines, 3);
      expect(restoredEntry.isFavorite, isTrue);
    },
  );
}
