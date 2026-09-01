import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RC2 canonical paper round-trip preserves release-critical state', () {
    final freeParagraph = WordContentBlockService.paragraph(
      text: 'Teacher note: हिंदी / ଓଡ଼ିଆ / − × ÷ √ π',
    );
    final pageBreak = WordContentBlockService.pageBreak();

    final original = Paper(
      id: 'rc2-paper',
      title: 'Final Validation',
      schoolName: 'EduSheet School',
      instruction: 'Answer all required questions.',
      instructionAlignment: PaperTextAlignment.center,
      templateId: 'board_classic',
      headerText: 'Assessment 2026',
      footerText: 'End of paper',
      showPageNumbers: true,
      pageLayout: const PaperPageLayout(
        pageSize: PaperPageSize.a4,
        orientation: PaperPageOrientation.landscape,
        margins: PaperPageMargins(
          topPoints: 42,
          rightPoints: 36,
          bottomPoints: 48,
          leftPoints: 36,
        ),
        headerDistancePoints: 16,
        footerDistancePoints: 18,
        lineSpacing: 1.25,
        paragraphSpacingPoints: 8,
        pageNumberPosition: PaperPageNumberPosition.footerRight,
      ),
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Science'),
        PaperHeaderField(id: 'class', label: 'Class', value: 'X'),
        PaperHeaderField(id: 'time', label: 'Time', value: '3 Hours'),
      ],
      sections: [
        PaperSection(
          id: 'section-a',
          title: 'Section A',
          prefix: 'Part I',
          instruction: 'Attempt both questions.',
          showTopDivider: true,
          showBottomDivider: true,
          headingAlignment: PaperTextAlignment.center,
          instructionAlignment: PaperTextAlignment.left,
          answerRuleAlignment: PaperTextAlignment.right,
          showInstructionLabel: true,
          headingBold: true,
          headingUppercase: true,
          headingBoxed: true,
          headingSize: SectionHeadingSize.large,
          spacing: SectionSpacing.compact,
          sectionMarksDisplay: SectionMarksDisplay.right,
          questionMarksPlacement: QuestionMarksPlacement.inline,
          keepTogether: true,
          questions: [
            Question(
              id: 'q1',
              text: 'Explain gravity. हिंदी / ଓଡ଼ିଆ / − × ÷ √ π',
              marks: 5,
              instructions: 'Use a labelled diagram.',
              instructionAlignment: PaperTextAlignment.left,
            ),
            freeParagraph,
            pageBreak,
            Question(id: 'q2', text: 'State Newton\'s third law.', marks: 3),
          ],
        ),
      ],
      createdAt: DateTime.utc(2026, 9, 1),
    );

    final restored = Paper.fromJson(original.toJson());
    final section = restored.sections.single;

    expect(restored.pageLayout.pageSize, PaperPageSize.a4);
    expect(restored.pageLayout.orientation, PaperPageOrientation.landscape);
    expect(restored.pageLayout.margins.topPoints, 42);
    expect(
      restored.pageLayout.pageNumberPosition,
      PaperPageNumberPosition.footerRight,
    );
    expect(restored.instructionAlignment, PaperTextAlignment.center);
    expect(section.formattedHeadingText, 'PART I SECTION A');
    expect(section.headingBoxed, isTrue);
    expect(section.headingSize, SectionHeadingSize.large);
    expect(section.spacing, SectionSpacing.compact);
    expect(section.sectionMarksDisplay, SectionMarksDisplay.right);
    expect(section.questionMarksPlacement, QuestionMarksPlacement.inline);
    expect(section.keepTogether, isTrue);
    expect(section.totalMarks, 8);
    expect(PaperStructureService.assessmentQuestionCount(section), 2);
    expect(section.questions[1].isWordContentBlock, isTrue);
    expect(
      WordContentBlockService.kindOf(section.questions[1]),
      WordContentBlockKind.paragraph,
    );
    expect(
      WordContentBlockService.kindOf(section.questions[2]),
      WordContentBlockKind.pageBreak,
    );
    expect(section.questions.first.instructions, 'Use a labelled diagram.');
  });

  test('RC2 release header metadata remains export-resolvable', () {
    const template = PaperTemplate(
      id: 'rc2-board',
      name: 'RC2 Board',
      type: TemplateType.board,
      headerLayout: HeaderLayout.dps,
      paperLayout: PaperLayout.twoColumn,
      paperSize: PaperSize.a4,
    );
    final paper = Paper(
      id: 'rc2-header',
      title: 'Board Examination',
      schoolName: 'EduSheet School',
      headerFields: [
        PaperHeaderField(id: 'subject', label: 'Subject', value: 'Mathematics'),
        PaperHeaderField(id: 'class', label: 'Class', value: 'X'),
        PaperHeaderField(id: 'time', label: 'Time', value: '3 Hours'),
        PaperHeaderField(id: 'set', label: 'Set', value: 'A'),
        PaperHeaderField(id: 'code', label: 'Paper Code', value: 'M-10'),
      ],
      createdAt: DateTime.utc(2026, 9, 1),
    );

    final layout = PaperHeaderLayoutFactory.resolveForPaper(template, paper);
    final fieldBlock = layout.elements.firstWhere(
      (element) => element.type == ElementType.headerFieldsBlock,
    );
    final resolved = PaperHeaderLayoutFactory.resolveHeaderFields(
      fieldBlock,
      paper,
    );
    final labels = resolved.map((field) => field.label).toSet();

    expect(
      labels,
      containsAll({'Subject', 'Class', 'Time', 'Set', 'Paper Code'}),
    );
    expect(layout.elements.isNotEmpty, isTrue);
  });

  test('RC2 offline font plans cover Windows and Android release targets', () {
    final windows = PdfExportThemeService.candidatePathsForOperatingSystem(
      'windows',
    );
    final android = PdfExportThemeService.candidatePathsForOperatingSystem(
      'android',
    );

    expect(windows, contains(r'C:\Windows\Fonts\Nirmala.ttf'));
    expect(windows, contains(r'C:\Windows\Fonts\segoeui.ttf'));
    expect(
      windows.any((path) => path.toLowerCase().contains('kalinga')),
      isTrue,
    );
    expect(android, contains('/system/fonts/NotoSans-Regular.ttf'));
    expect(android, contains('/system/fonts/NotoSansMath-Regular.ttf'));
    expect(android.any((path) => path.contains('NotoSansOriya')), isTrue);
  });
}
