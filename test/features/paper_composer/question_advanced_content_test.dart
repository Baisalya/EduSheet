import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/question_advanced_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/universal_question_adapter.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/paper_composer/domain/universal_question_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advanced content round-trips through existing question metadata', () {
    const advanced = QuestionAdvancedContent(
      stimulus: QuestionStimulus(
        kind: QuestionStimulusKind.caseStudy,
        title: 'Case study',
        text: 'A shop recorded the following sales.',
      ),
      wordBank: ['mean', 'median', 'mode'],
      answerSpace: QuestionAnswerSpace(
        style: QuestionAnswerSpaceStyle.box,
        lines: 5,
      ),
    );

    final metadata = advanced.writeToMetadata(const {'legacy': 'keep-me'});
    final question = Question(
      id: 'advanced-q',
      text: 'Answer the questions.',
      metadata: metadata,
    );
    final restored = QuestionAdvancedContent.fromQuestion(question);

    expect(metadata['legacy'], 'keep-me');
    expect(restored.stimulus?.kind, QuestionStimulusKind.caseStudy);
    expect(restored.stimulus?.title, 'Case study');
    expect(restored.wordBank, ['mean', 'median', 'mode']);
    expect(restored.answerSpace.style, QuestionAnswerSpaceStyle.box);
    expect(restored.answerSpace.lines, 5);
  });

  test(
    'draft preserves advanced blocks without adding a persistence schema',
    () {
      const advanced = QuestionAdvancedContent(
        stimulus: QuestionStimulus(text: 'Read this passage.'),
        wordBank: ['is', 'are'],
        answerSpace: QuestionAnswerSpace(
          style: QuestionAnswerSpaceStyle.ruled,
          lines: 4,
        ),
      );
      final seed = Question(
        id: 'mixed-advanced',
        text: 'Complete the task.',
        tableData: const QuestionTable(
          headers: ['A', 'B'],
          rows: [
            ['1', '2'],
          ],
        ),
        subQuestions: [Question(id: 'part-a', text: 'First part', marks: 2)],
        internalChoices: [
          Question(id: 'or-a', text: 'Alternative A', marks: 3),
          Question(id: 'or-b', text: 'Alternative B', marks: 3),
        ],
        metadata: advanced.writeToMetadata(const {'legacy': true}),
      );

      final draft = QuestionDraft.fromQuestion(seed);
      final saved = draft.toQuestion(plainTextAccessibility: 'Accessible task');
      final document = UniversalQuestionAdapter.fromDraft(draft);

      expect(saved.metadata['legacy'], isTrue);
      expect(
        QuestionAdvancedContent.fromQuestion(saved).stimulus?.text,
        'Read this passage.',
      );
      expect(document.contains(UniversalQuestionBlockKind.stimulus), isTrue);
      expect(document.contains(UniversalQuestionBlockKind.wordBank), isTrue);
      expect(document.contains(UniversalQuestionBlockKind.table), isTrue);
      expect(
        document.contains(UniversalQuestionBlockKind.subQuestions),
        isTrue,
      );
      expect(
        document.contains(UniversalQuestionBlockKind.internalChoice),
        isTrue,
      );
      expect(document.contains(UniversalQuestionBlockKind.answerSpace), isTrue);
    },
  );

  test(
    'advanced structure resolves labels, marks and answer-space precedence',
    () {
      expect(QuestionAdvancedStructureService.partLabel(0), '(a)');
      expect(QuestionAdvancedStructureService.partLabel(25), '(z)');
      expect(QuestionAdvancedStructureService.partLabel(26), '(aa)');

      final balanced = [
        Question(id: 'a', text: 'A', marks: 4),
        Question(id: 'b', text: 'B', marks: 4),
      ];
      final unbalanced = [
        Question(id: 'a', text: 'A', marks: 4),
        Question(id: 'b', text: 'B', marks: 3),
      ];
      expect(
        QuestionAdvancedStructureService.internalChoiceMarksBalanced(balanced),
        isTrue,
      );
      expect(
        QuestionAdvancedStructureService.internalChoiceMarksBalanced(
          unbalanced,
        ),
        isFalse,
      );

      final section = PaperSection(
        id: 'section',
        title: 'Section A',
        answerSpaceLines: 3,
        ruledAnswerArea: true,
      );
      final sectionResolved =
          QuestionAdvancedStructureService.resolveAnswerSpace(
            Question(id: 'plain', text: 'Explain.'),
            section,
          );
      expect(sectionResolved.style, QuestionAnswerSpaceStyle.ruled);
      expect(sectionResolved.lines, 3);
      expect(sectionResolved.questionOverride, isFalse);

      const override = QuestionAdvancedContent(
        answerSpace: QuestionAnswerSpace(
          style: QuestionAnswerSpaceStyle.graph,
          lines: 6,
        ),
      );
      final overridden = QuestionAdvancedStructureService.resolveAnswerSpace(
        Question(
          id: 'graph',
          text: 'Plot the graph.',
          metadata: override.writeToMetadata(const {}),
        ),
        section,
      );
      expect(overridden.style, QuestionAnswerSpaceStyle.graph);
      expect(overridden.lines, 6);
      expect(overridden.questionOverride, isTrue);
    },
  );
}
