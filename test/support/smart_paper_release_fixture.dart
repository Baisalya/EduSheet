import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/pdf/application/paper_style_catalog.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

class SmartPaperReleaseFixture {
  const SmartPaperReleaseFixture._();

  static PaperTemplate get template => PaperStyleCatalog.presets
      .firstWhere(
        (preset) => preset.template.id == PaperStyleCatalog.defaultTemplateId,
      )
      .template;

  static Paper paper({String? attachmentPath}) {
    final advancedQuestion = _advancedQuestion(attachmentPath: attachmentPath);
    return Paper(
      id: 'release-paper',
      title: 'Smart Paper Release Gate',
      schoolName: 'EduSheet Demo School',
      instruction: 'Read every instruction carefully.',
      templateId: PaperStyleCatalog.defaultTemplateId,
      maximumMarks: 10,
      questionNumberStyle: QuestionNumberStyle.number,
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Mathematics'),
        PaperHeaderField(id: 'time', label: 'Time', value: '90 minutes'),
      ],
      customHeaderValues: const {'legacyHeaderOwner': 'preserve-me'},
      createdAt: DateTime.utc(2026, 8, 31, 12),
      sections: [
        PaperSection(
          id: 'release-section-a',
          title: 'Section A',
          instruction: 'Answer both questions.',
          prefix: 'A.',
          requiredCount: 2,
          numberingStyle: QuestionNumberStyle.lowerAlpha,
          defaultMarks: 5,
          showTitle: true,
          showDivider: true,
          answerSpaceLines: 2,
          ruledAnswerArea: true,
          questions: [
            advancedQuestion,
            Question(
              id: 'release-mcq',
              text: 'Which expression is equal to 12?',
              type: QuestionType.mcq,
              marks: 5,
              options: [
                QuestionOption(id: 'mcq-a', text: '3 × 4', isCorrect: true),
                QuestionOption(id: 'mcq-b', text: '2 × 5'),
                QuestionOption(id: 'mcq-c', text: '7 + 3'),
                QuestionOption(id: 'mcq-d', text: '15 − 2'),
              ],
              metadata: QuestionOptionLayoutCodec.write(const {
                'legacyMcqMetadata': true,
              }, QuestionOptionLayout.twoColumn),
            ),
          ],
        ),
      ],
    );
  }

  static Question advancedQuestion({String? attachmentPath}) {
    return _advancedQuestion(attachmentPath: attachmentPath);
  }

  static Question _advancedQuestion({String? attachmentPath}) {
    const advanced = QuestionAdvancedContent(
      stimulus: QuestionStimulus(
        kind: QuestionStimulusKind.caseStudy,
        title: 'Rainfall evidence',
        text:
            'Village A received 40 mm of rain while Village B received 25 mm.',
      ),
      wordBank: ['increase', 'decrease', 'unchanged'],
      answerSpace: QuestionAnswerSpace(
        style: QuestionAnswerSpaceStyle.box,
        lines: 3,
      ),
    );

    final metadata = advanced.writeToMetadata(
      QuestionOptionLayoutCodec.write(const {
        'legacyOwner': {'keep': true, 'version': 7},
      }, QuestionOptionLayout.inline),
    );

    return Question(
      id: 'release-advanced',
      text: 'Study the evidence and answer the following.',
      type: QuestionType.custom,
      marks: 5,
      subject: 'Mathematics',
      chapter: 'Data Handling',
      topic: 'Comparison',
      difficulty: QuestionDifficulty.medium,
      tags: const ['release-gate', 'data'],
      instructions: 'Show working where required.',
      options: [
        QuestionOption(id: 'adv-a', text: '15 mm', isCorrect: true),
        QuestionOption(id: 'adv-b', text: '25 mm'),
      ],
      tableData: const QuestionTable(
        headers: ['Village', 'Rainfall'],
        rows: [
          ['A', '40 mm'],
          ['B', '25 mm'],
        ],
        caption: 'Observation table',
        accessibilitySummary:
            'Rainfall comparison for Village A and Village B.',
      ),
      attachments: attachmentPath == null
          ? const []
          : [
              QuestionAttachment(
                id: 'release-image',
                kind: QuestionAttachmentKind.image,
                path: attachmentPath,
                alternativeText: 'A simple rainfall bar chart.',
                caption: 'Rainfall chart',
                mimeType: 'image/png',
                width: 320,
                height: 180,
              ),
            ],
      subQuestions: [
        Question(
          id: 'release-part-a',
          text: 'Calculate the rainfall difference.',
          type: QuestionType.numerical,
          marks: 2,
          correctAnswer: '15 mm',
        ),
        Question(
          id: 'release-part-b',
          text: 'State which village received more rain.',
          type: QuestionType.shortAnswer,
          marks: 1,
          correctAnswer: 'Village A',
        ),
      ],
      internalChoices: [
        Question(
          id: 'release-or-a',
          text: 'Explain the comparison in one sentence.',
          marks: 2,
        ),
        Question(
          id: 'release-or-b',
          text: 'Represent the comparison as a ratio.',
          marks: 2,
        ),
      ],
      metadata: metadata,
    );
  }

  static const semanticMarkers = <String>[
    'Smart Paper Release Gate',
    'Section A',
    'Study the evidence and answer the following.',
    'Rainfall evidence',
    'Village A received 40 mm of rain while Village B received 25 mm.',
    'increase',
    'Observation table',
    'Calculate the rainfall difference.',
    'Explain the comparison in one sentence.',
    'Represent the comparison as a ratio.',
    'Which expression is equal to 12?',
  ];
}
