import 'dart:io';

import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm5_wm6_fixture.dart';

void main() {
  test('WM5 parses anchor wrap, distances, z-order and common VML shapes', () async {
    final fixture = await writeWm56Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final section = document.sections.first;
    final inlines = section.blocks
        .whereType<ConversionParagraph>()
        .expand((paragraph) => paragraph.inlines)
        .toList(growable: false);

    final image = inlines.whereType<ConversionImageRun>().single;
    expect(image.placement.floating, isTrue);
    expect(image.placement.wrapStyle, 'wrapTight');
    expect(image.placement.wrapText, 'largest');
    expect(image.placement.distanceTopPoints, closeTo(6, 0.001));
    expect(image.placement.distanceBottomPoints, closeTo(7, 0.001));
    expect(image.placement.distanceLeftPoints, closeTo(8, 0.001));
    expect(image.placement.distanceRightPoints, closeTo(9, 0.001));
    expect(image.placement.relativeHeight, 123456);
    expect(image.placement.layoutInCell, isFalse);
    expect(image.placement.locked, isTrue);
    expect(image.placement.allowOverlap, isFalse);

    final shape = inlines.whereType<ConversionShapeRun>().single;
    expect(shape.kind, ConversionShapeKind.roundedRectangle);
    expect(shape.widthPoints, closeTo(144, 0.001));
    expect(shape.heightPoints, closeTo(54, 0.001));
    expect(shape.style.fillColorHex, 'EAF2F8');
    expect(shape.style.strokeColorHex, '2E75B6');
    expect(shape.placement.floating, isTrue);
    expect(shape.placement.horizontalRelativeFrom, 'column');
    expect(shape.placement.behindText, isTrue);
    expect(shape.placement.relativeHeight, 42);
    expect(shape.placement.wrapStyle, 'wrapThrough');
    expect(shape.placement.wrapText, 'left');
    expect(shape.placement.distanceLeftPoints, closeTo(4, 0.001));
    expect(shape.placement.distanceRightPoints, closeTo(5, 0.001));
  });

  test('WM6 parses independent sections, columns, page rules and stories', () async {
    final fixture = await writeWm56Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    expect(document.evenAndOddHeaders, isTrue);
    expect(document.mirrorMargins, isTrue);
    expect(document.gutterAtTop, isTrue);
    expect(document.sections, hasLength(2));

    final first = document.sections.first;
    expect(first.breakType, ConversionSectionBreakType.oddPage);
    expect(first.titlePage, isTrue);
    expect(first.columns.count, 2);
    expect(first.columns.equalWidth, isFalse);
    expect(first.columns.separator, isTrue);
    expect(first.columns.columns, hasLength(2));
    expect(first.columns.columns.first.widthPoints, closeTo(216, 0.001));
    expect(first.columns.columns.first.spacingPoints, closeTo(18, 0.001));
    expect(
      first.blocks
          .whereType<ConversionParagraph>()
          .any((paragraph) => paragraph.columnBreakBefore),
      isTrue,
    );
    expect(first.page.gutterPoints, closeTo(18, 0.001));
    expect(first.pageNumberStart, 7);
    expect(first.pageNumberFormat, 'upperRoman');
    expect(first.page.pageBorders.offsetFrom, 'page');
    expect(first.page.pageBorders.display, 'firstPage');
    expect(first.page.pageBorders.zOrder, 'back');
    expect(first.page.pageBorders.borders.bottom?.colorHex, '4472C4');
    expect(_storyText(first.headerBlocks), contains('Default header'));
    expect(_storyText(first.firstPageHeaderBlocks), contains('First header'));
    expect(_storyText(first.evenPageHeaderBlocks), contains('Even header'));
    expect(_storyText(first.footerBlocks), contains('{PAGE}'));

    final second = document.sections[1];
    expect(second.breakType, ConversionSectionBreakType.oddPage);
    expect(second.page.widthPoints, closeTo(792, 0.001));
    expect(second.page.heightPoints, closeTo(612, 0.001));
    expect(second.columns.count, 1);
    // Word independently inherits story types that are not overridden.
    expect(_storyText(second.firstPageHeaderBlocks), contains('First header'));
    expect(_storyText(second.evenPageHeaderBlocks), contains('Even header'));

    // Odd/even header stories are selected by the page ordinal inside the
    // section, not by a restarted PAGE field value or physical page number.
    expect(
      _storyText(
        first.headerForPage(
          pageIndexInSection: 1,
          evenAndOddHeaders: true,
        ),
      ),
      contains('Even header'),
    );
  });

  testWidgets('WM5+WM6 viewer mounts columns, page border and shape layers', (
    tester,
  ) async {
    final fixture = (await tester.runAsync<File>(writeWm56Fixture))!;
    addTearDown(
      () => tester.runAsync(() async {
        if (await fixture.parent.exists()) {
          await fixture.parent.delete(recursive: true);
        }
      }),
    );
    final document = (await tester.runAsync<ConversionDocument>(
      () => DocxConversionParser.parse(fixture),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 950,
            child: WordFidelityDocumentView(
              document: document,
              pageWidth: 816,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-column-0')), findsWidgets);
    expect(find.byKey(const ValueKey('word-column-1')), findsWidgets);
    expect(find.byKey(const ValueKey('word-page-border')), findsWidgets);
    expect(find.byKey(const ValueKey('word-shape-visual')), findsWidgets);
    // The fidelity viewer intentionally virtualizes pages. The parity page may
    // be outside the initial viewport/cache, so drive the vertical page list
    // until the automatically inserted odd/even blank page is materialized.
    final parityPage =
        find.byKey(const ValueKey('word-section-parity-blank-page'));
    if (parityPage.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        parityPage,
        600,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('word-fidelity-lazy-page-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
    }
    expect(parityPage, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _storyText(List<ConversionBlock> blocks) {
  final buffer = StringBuffer();
  void visit(List<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            buffer.write(inline.text);
          } else if (inline is ConversionDynamicFieldRun) {
            buffer.write(
              inline.field == ConversionDynamicField.pageNumber
                  ? '{PAGE}'
                  : '{NUMPAGES}',
            );
          } else if (inline is ConversionTextBoxRun) {
            visit(inline.blocks);
          } else if (inline is ConversionShapeRun) {
            visit(inline.blocks);
          }
        }
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      }
    }
  }

  visit(blocks);
  return buffer.toString();
}
