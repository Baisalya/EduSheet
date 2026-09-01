import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/smart_paper_release_fixture.dart';

void main() {
  group('Smart Paper release compatibility gate', () {
    test('complete Step 1-5 paper survives a real JSON round trip', () {
      final original = SmartPaperReleaseFixture.paper(
        attachmentPath: r'C:\teacher\rainfall.png',
      );
      final json =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final restored = Paper.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.templateId, original.templateId);
      expect(restored.maximumMarks, 10);
      expect(restored.customHeaderValues['legacyHeaderOwner'], 'preserve-me');
      expect(restored.sections, hasLength(1));

      final section = restored.sections.single;
      expect(section.requiredCount, 2);
      expect(section.numberingStyle, QuestionNumberStyle.lowerAlpha);
      expect(section.defaultMarks, 5);
      expect(section.answerSpaceLines, 2);
      expect(section.ruledAnswerArea, isTrue);

      final advancedQuestion = section.questions.first;
      expect(advancedQuestion.type, QuestionType.custom);
      expect(advancedQuestion.options, hasLength(2));
      expect(advancedQuestion.tableData?.caption, 'Observation table');
      expect(
        advancedQuestion.attachments.single.path,
        r'C:\teacher\rainfall.png',
      );
      expect(advancedQuestion.subQuestions, hasLength(2));
      expect(advancedQuestion.internalChoices, hasLength(2));
      expect(
        QuestionOptionLayoutCodec.fromQuestion(advancedQuestion),
        QuestionOptionLayout.inline,
      );
      expect((advancedQuestion.metadata['legacyOwner'] as Map)['keep'], isTrue);

      final advanced = QuestionAdvancedContent.fromQuestion(advancedQuestion);
      expect(advanced.stimulus?.kind, QuestionStimulusKind.caseStudy);
      expect(advanced.stimulus?.title, 'Rainfall evidence');
      expect(advanced.wordBank, ['increase', 'decrease', 'unchanged']);
      expect(advanced.answerSpace.style, QuestionAnswerSpaceStyle.box);
      expect(advanced.answerSpace.lines, 3);

      final mcq = section.questions.last;
      expect(mcq.type, QuestionType.mcq);
      expect(
        QuestionOptionLayoutCodec.fromQuestion(mcq),
        QuestionOptionLayout.twoColumn,
      );
      expect(mcq.metadata['legacyMcqMetadata'], isTrue);
    });

    test(
      'legacy three-type payload still opens after Smart Paper refactor',
      () {
        final restored = Paper.fromJson({
          'id': 'legacy-release-gate',
          'title': 'Legacy paper',
          'sections': [
            {
              'id': 'legacy-section',
              'title': 'Section A',
              'questions': [
                {
                  'id': 'legacy-mcq',
                  'text': 'Choose one',
                  'type': 0,
                  'marks': 1,
                  'options': [
                    {'id': 'a', 'text': 'A', 'isCorrect': true},
                    {'id': 'b', 'text': 'B', 'isCorrect': false},
                  ],
                },
                {'id': 'legacy-desc', 'text': 'Explain', 'type': 1, 'marks': 3},
                {
                  'id': 'legacy-blank',
                  'text': 'Fill ____',
                  'type': 2,
                  'marks': 1,
                },
              ],
            },
          ],
          'createdAt': '2026-01-01T00:00:00.000Z',
        });

        final questions = restored.sections.single.questions;
        expect(questions[0].type, QuestionType.mcq);
        expect(questions[1].type, QuestionType.descriptive);
        expect(questions[2].type, QuestionType.fillInTheBlanks);
        expect(
          QuestionAdvancedContent.fromQuestion(questions[1]).hasAny,
          isFalse,
        );
        expect(
          QuestionOptionLayoutCodec.fromQuestion(questions[0]),
          QuestionOptionLayout.vertical,
        );
      },
    );
  });
}
