import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_direct_authoring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 4A direct Word question stays an assessment question', () {
    final question = WordDirectAuthoringService.blankAssessmentQuestion(
      defaultMarks: 3,
    );
    final section = PaperSection(
      id: 's1',
      title: 'Section A',
      questions: [question],
    );

    expect(question.isWordContentBlock, isFalse);
    expect(question.marks, 3);
    expect(PaperStructureService.assessmentQuestionCount(section), 1);
    expect(section.totalMarks, 3);
  });

  test(
    'Phase 4A question pictures and logos survive canonical JSON round-trip',
    () {
      const attachment = QuestionAttachment(
        id: 'image-1',
        kind: QuestionAttachmentKind.image,
        path: r'C:\paper\diagram.png',
        alternativeText: 'A labelled diagram',
        caption: 'Figure 1',
        mimeType: 'image/png',
      );
      final question = WordDirectAuthoringService.appendImage(
        WordDirectAuthoringService.blankAssessmentQuestion(),
        attachment,
      );
      final paper = Paper(
        id: 'p1',
        title: 'Exam',
        schoolName: 'School',
        logos: const [r'C:\paper\school-logo.png'],
        sections: [
          PaperSection(id: 's1', title: 'Section A', questions: [question]),
        ],
        createdAt: DateTime.utc(2026, 9, 1),
      );

      final restored = Paper.fromJson(paper.toJson());

      expect(restored.logos.single, r'C:\paper\school-logo.png');
      expect(
        restored.sections.single.questions.single.attachments.single.path,
        r'C:\paper\diagram.png',
      );
      expect(
        restored.sections.single.questions.single.attachments.single.caption,
        'Figure 1',
      );
    },
  );
}
