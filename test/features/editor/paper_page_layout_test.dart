import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/editor/services/paper_structure_service.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy paper JSON receives backward-compatible page layout defaults',
    () {
      final paper = Paper.fromJson({
        'id': 'legacy-paper',
        'title': 'Legacy',
        'sections': const [],
        'createdAt': '2026-08-31T00:00:00.000',
      });

      expect(paper.pageLayout.pageSize, PaperPageSize.useTemplate);
      expect(paper.pageLayout.orientation, PaperPageOrientation.portrait);
      expect(paper.pageLayout.margins.topPoints, 36);
      expect(paper.pageLayout.lineSpacing, 1.15);
      expect(
        paper.pageLayout.pageNumberPosition,
        PaperPageNumberPosition.footerCenter,
      );
    },
  );

  test('Step 9 page layout survives Paper JSON round-trip', () {
    final original = Paper(
      id: 'layout-paper',
      title: 'Layout',
      headerText: 'Running header',
      footerText: 'Running footer',
      showPageNumbers: true,
      pageLayout: const PaperPageLayout(
        pageSize: PaperPageSize.a5,
        orientation: PaperPageOrientation.landscape,
        margins: PaperPageMargins(
          topPoints: 42,
          rightPoints: 31,
          bottomPoints: 52,
          leftPoints: 37,
        ),
        headerDistancePoints: 14,
        footerDistancePoints: 16,
        lineSpacing: 1.5,
        paragraphSpacingPoints: 10,
        pageNumberPosition: PaperPageNumberPosition.headerRight,
      ),
      createdAt: DateTime.utc(2026, 8, 31),
    );

    final restored = Paper.fromJson(original.toJson());

    expect(restored.headerText, 'Running header');
    expect(restored.footerText, 'Running footer');
    expect(restored.pageLayout.pageSize, PaperPageSize.a5);
    expect(restored.pageLayout.orientation, PaperPageOrientation.landscape);
    expect(restored.pageLayout.margins.leftPoints, 37);
    expect(restored.pageLayout.headerDistancePoints, 14);
    expect(restored.pageLayout.footerDistancePoints, 16);
    expect(restored.pageLayout.lineSpacing, 1.5);
    expect(restored.pageLayout.paragraphSpacingPoints, 10);
    expect(
      restored.pageLayout.pageNumberPosition,
      PaperPageNumberPosition.headerRight,
    );
  });

  test(
    'manual page break is layout-only and consumes no assessment ordinal',
    () {
      final pageBreak = WordContentBlockService.pageBreak();
      final section = PaperSection(
        id: 'section-a',
        title: 'Section A',
        questions: [
          Question(id: 'q1', text: 'Question one', marks: 2),
          pageBreak,
          Question(id: 'q2', text: 'Question two', marks: 3),
        ],
      );

      expect(pageBreak.isWordContentBlock, isTrue);
      expect(
        WordContentBlockService.kindOf(pageBreak),
        WordContentBlockKind.pageBreak,
      );
      expect(pageBreak.marks, 0);
      expect(PaperStructureService.assessmentQuestionCount(section), 2);
      expect(PaperStructureService.numberedQuestionOrdinal(section, 0), 1);
      expect(PaperStructureService.numberedQuestionOrdinal(section, 1), 1);
      expect(PaperStructureService.numberedQuestionOrdinal(section, 2), 2);
    },
  );

  test('page layout deserialization bounds unsafe persisted values', () {
    final layout = PaperPageLayout.fromJson({
      'pageSize': 'legal',
      'orientation': 'landscape',
      'margins': {
        'topPoints': -10,
        'rightPoints': 999,
        'bottomPoints': 48,
        'leftPoints': 50,
      },
      'headerDistancePoints': -50,
      'footerDistancePoints': 999,
      'lineSpacing': 20,
      'paragraphSpacingPoints': -10,
      'pageNumberPosition': 'footerRight',
    });

    expect(layout.margins.topPoints, 12);
    expect(layout.margins.rightPoints, 144);
    expect(layout.headerDistancePoints, 0);
    expect(layout.footerDistancePoints, 72);
    expect(layout.lineSpacing, 3);
    expect(layout.paragraphSpacingPoints, 0);
    expect(layout.pageNumberPosition, PaperPageNumberPosition.footerRight);
  });
}
