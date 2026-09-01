import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy paper receives professional-formatting compatibility defaults',
    () {
      final paper = Paper.fromJson({
        'id': 'legacy',
        'title': 'Legacy',
        'createdAt': '2026-09-01T00:00:00.000',
        'sections': [
          {
            'id': 'section-a',
            'title': 'Section A',
            'showDivider': true,
            'questions': const [],
          },
        ],
      });

      expect(paper.instructionAlignment, PaperTextAlignment.left);
      final section = paper.sections.single;
      expect(section.headingAlignment, PaperTextAlignment.center);
      expect(section.instructionAlignment, PaperTextAlignment.center);
      expect(section.answerRuleAlignment, PaperTextAlignment.center);
      expect(section.showTopDivider, isFalse);
      expect(section.showBottomDivider, isTrue);
      expect(section.showDivider, isTrue);
      expect(section.showInstructionLabel, isFalse);
      expect(section.headingBold, isTrue);
      expect(section.headingUppercase, isFalse);
      expect(section.headingBoxed, isFalse);
      expect(section.headingSize, SectionHeadingSize.normal);
      expect(section.spacing, SectionSpacing.normal);
      expect(section.sectionMarksDisplay, SectionMarksDisplay.hidden);
      expect(section.questionMarksPlacement, QuestionMarksPlacement.rightEdge);
      expect(section.keepTogether, isTrue);
    },
  );

  test(
    'professional section and instruction formatting survives JSON round-trip',
    () {
      final original = Paper(
        id: 'professional',
        title: 'Professional',
        instruction: 'Read carefully.',
        instructionAlignment: PaperTextAlignment.right,
        createdAt: DateTime.utc(2026, 9, 1),
        sections: [
          PaperSection(
            id: 'section-a',
            title: 'Section A',
            instruction: 'Answer briefly.',
            headingAlignment: PaperTextAlignment.left,
            instructionAlignment: PaperTextAlignment.right,
            answerRuleAlignment: PaperTextAlignment.left,
            showInstructionLabel: true,
            showTopDivider: true,
            showBottomDivider: false,
            headingBold: false,
            headingUppercase: true,
            headingBoxed: true,
            headingSize: SectionHeadingSize.large,
            spacing: SectionSpacing.spacious,
            sectionMarksDisplay: SectionMarksDisplay.right,
            questionMarksPlacement: QuestionMarksPlacement.inline,
            keepTogether: false,
            questions: [
              Question(
                id: 'q1',
                text: 'Explain gravity.',
                instructions: 'Use one sentence.',
                instructionAlignment: PaperTextAlignment.center,
              ),
            ],
          ),
        ],
      );

      final restored = Paper.fromJson(original.toJson());

      expect(restored.instructionAlignment, PaperTextAlignment.right);
      final section = restored.sections.single;
      expect(section.headingAlignment, PaperTextAlignment.left);
      expect(section.instructionAlignment, PaperTextAlignment.right);
      expect(section.answerRuleAlignment, PaperTextAlignment.left);
      expect(section.showInstructionLabel, isTrue);
      expect(section.showTopDivider, isTrue);
      expect(section.showBottomDivider, isFalse);
      expect(section.showDivider, isFalse);
      expect(section.headingBold, isFalse);
      expect(section.headingUppercase, isTrue);
      expect(section.headingBoxed, isTrue);
      expect(section.headingSize, SectionHeadingSize.large);
      expect(section.spacing, SectionSpacing.spacious);
      expect(section.sectionMarksDisplay, SectionMarksDisplay.right);
      expect(section.questionMarksPlacement, QuestionMarksPlacement.inline);
      expect(section.keepTogether, isFalse);
      expect(section.formattedHeadingText, 'SECTION A');
      expect(section.sectionMarksText, '1 Mark');
      expect(
        section.questions.single.instructionAlignment,
        PaperTextAlignment.center,
      );
    },
  );

  test('legacy divider alias continues to map to the lower section rule', () {
    final section = PaperSection(
      id: 'section-a',
      title: 'Section A',
      showDivider: false,
    );

    expect(section.showBottomDivider, isFalse);
    expect(section.showDivider, isFalse);
    final restored = PaperSection.fromJson(section.toJson());
    expect(restored.showBottomDivider, isFalse);
    expect(restored.showDivider, isFalse);
  });

  test('section marks use required-count-aware printable total', () {
    final section = PaperSection(
      id: 'marks',
      title: 'Part A',
      requiredCount: 1,
      sectionMarksDisplay: SectionMarksDisplay.inline,
      questions: [
        Question(id: 'q1', text: 'One', marks: 2),
        Question(id: 'q2', text: 'Two', marks: 5),
      ],
    );

    expect(section.sectionMarksText, '5 Marks');
    expect(section.formattedHeadingText, 'Part A');
  });
}
