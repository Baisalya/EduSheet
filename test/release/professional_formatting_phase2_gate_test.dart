import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 2 professional section formatting is release-safe', () {
    final section = PaperSection(
      id: 'section-a',
      title: 'Section A',
      prefix: 'Part I',
      headingBold: false,
      headingUppercase: true,
      headingBoxed: true,
      headingSize: SectionHeadingSize.large,
      spacing: SectionSpacing.compact,
      sectionMarksDisplay: SectionMarksDisplay.right,
      questionMarksPlacement: QuestionMarksPlacement.inline,
      keepTogether: true,
      questions: [
        Question(id: 'q1', text: 'Question one', marks: 2),
        Question(id: 'q2', text: 'Question two', marks: 3),
      ],
    );

    final restored = PaperSection.fromJson(section.toJson());
    expect(restored.formattedHeadingText, 'PART I SECTION A');
    expect(restored.sectionMarksText, '5 Marks');
    expect(restored.headingBold, isFalse);
    expect(restored.headingBoxed, isTrue);
    expect(restored.headingSize, SectionHeadingSize.large);
    expect(restored.spacing, SectionSpacing.compact);
    expect(restored.sectionMarksDisplay, SectionMarksDisplay.right);
    expect(restored.questionMarksPlacement, QuestionMarksPlacement.inline);
    expect(restored.keepTogether, isTrue);
  });
}
