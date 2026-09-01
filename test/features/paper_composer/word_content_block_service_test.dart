import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_performance_profiler.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/editor/services/paper_validator.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Word free paragraph round-trips without becoming an assessment question',
    () {
      final paragraph = WordContentBlockService.paragraph(
        text: 'Read the following note before attempting Section A.',
      );

      expect(paragraph.isWordContentBlock, isTrue);
      expect(
        WordContentBlockService.kindOf(paragraph),
        WordContentBlockKind.paragraph,
      );
      expect(paragraph.marks, 0);

      final restored = Question.fromJson(paragraph.toJson());
      expect(restored.isWordContentBlock, isTrue);
      expect(restored.wordContentBlockKind, 'paragraph');
      expect(
        restored.plainTextAccessibility,
        contains('Read the following note'),
      );
    },
  );

  test('Word blocks do not consume numbering, answer-any slots or marks', () {
    final paragraph = WordContentBlockService.paragraph(text: 'Custom note');
    final section = PaperSection(
      id: 'section-a',
      title: 'Section A',
      requiredCount: 1,
      questions: [
        Question(id: 'q1', text: 'First question', marks: 2),
        paragraph,
        Question(id: 'q2', text: 'Second question', marks: 3),
      ],
    );

    expect(PaperStructureService.assessmentQuestionCount(section), 2);
    expect(PaperStructureService.numberedQuestionOrdinal(section, 0), 1);
    expect(PaperStructureService.numberedQuestionOrdinal(section, 1), 1);
    expect(PaperStructureService.numberedQuestionOrdinal(section, 2), 2);
    expect(
      PaperStructureService.answerRuleText(section),
      'Answer any 1 of 2 questions.',
    );
    // requiredCount=1 means the highest-mark real question determines the
    // section maximum. The zero-mark Word paragraph is ignored entirely.
    expect(section.totalMarks, 3);
  });

  test(
    'table and image Word blocks preserve their native advanced content',
    () {
      final table = WordContentBlockService.table(
        const QuestionTable(
          caption: 'Observation table',
          headers: ['x', 'y'],
          rows: [
            ['1', '2'],
          ],
        ),
      );
      final image = WordContentBlockService.image(
        const QuestionAttachment(
          id: 'image-1',
          kind: QuestionAttachmentKind.image,
          path: 'diagram.png',
          alternativeText: 'Triangle ABC',
          caption: 'Figure 1',
        ),
      );

      expect(WordContentBlockService.kindOf(table), WordContentBlockKind.table);
      expect(table.tableData?.caption, 'Observation table');
      expect(WordContentBlockService.kindOf(image), WordContentBlockKind.image);
      expect(image.attachments.single.caption, 'Figure 1');
    },
  );
  test('validator and performance gates ignore Word blocks as questions', () {
    final paragraph = WordContentBlockService.paragraph(text: 'Teacher note');
    final paper = Paper(
      id: 'word-gate-paper',
      title: 'Word Gate',
      createdAt: DateTime(2026, 8, 31),
      sections: [
        PaperSection(
          id: 'section-a',
          title: 'Section A',
          requiredCount: 2,
          questions: [
            Question(
              id: 'q1',
              text: 'Question',
              plainTextAccessibility: 'Question',
              marks: 2,
            ),
            paragraph,
          ],
        ),
      ],
    );

    final validation = const PaperValidator().validate(paper);
    expect(
      validation.issues.where((issue) => issue.questionId == paragraph.id),
      isEmpty,
    );
    expect(
      validation.issues.any(
        (issue) => issue.code == 'section.invalid_attempt_rule',
      ),
      isTrue,
    );

    final profile = const PaperPerformanceProfiler().profile(paper);
    expect(profile.questionCount, 1);
  });
}
