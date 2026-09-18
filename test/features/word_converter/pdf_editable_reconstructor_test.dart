import 'dart:ui';

import 'package:edusheet/features/word_converter/domain/models/editable_document.dart';
import 'package:edusheet/features/word_converter/services/pdf_editable_reconstructor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reconstructor = PdfEditableDocumentReconstructor();

  test('reconstructs heading and joins wrapped body lines', () {
    final document = reconstructor.reconstruct([
      PdfLayoutPageInput(
        pageIndex: 0,
        size: const Size(600, 800),
        lines: [
          _line('Professional Report', 54, 42, 250, 24, fontSize: 20, bold: true),
          _line('This is a wrapped body', 54, 110, 220, 13, fontSize: 11),
          _line('paragraph that continues.', 54, 123, 210, 13, fontSize: 11),
        ],
      ),
    ]);

    final blocks = document.pages.single.blocks;
    expect(blocks, hasLength(2));
    final heading = blocks.first as EditableParagraphBlock;
    final body = blocks.last as EditableParagraphBlock;

    expect(heading.kind, EditableParagraphKind.heading1);
    expect(heading.plainText, 'Professional Report');
    expect(body.kind, EditableParagraphKind.body);
    expect(body.plainText, 'This is a wrapped body paragraph that continues.');
  });

  test('reconstructs repeated aligned geometry as editable table', () {
    final document = reconstructor.reconstruct([
      PdfLayoutPageInput(
        pageIndex: 0,
        size: const Size(600, 800),
        lines: [
          _tableLine('Name', 'Marks', 70),
          _tableLine('Rahul', '80', 90),
          _tableLine('Riya', '92', 110),
        ],
      ),
    ]);

    final blocks = document.pages.single.blocks;
    expect(blocks, hasLength(1));
    final table = blocks.single as EditableTableBlock;
    expect(table.rows, hasLength(3));
    expect(table.rows.first.cells, hasLength(2));
    expect(table.rows.first.cells.first.paragraphs.single.plainText, 'Name');
    expect(table.rows[1].cells[1].paragraphs.single.plainText, '80');
    expect(table.rows[2].cells[0].paragraphs.single.plainText, 'Riya');
  });

  test('orders two-column prose left column before right column', () {
    final document = reconstructor.reconstruct([
      PdfLayoutPageInput(
        pageIndex: 0,
        size: const Size(600, 800),
        lines: [
          _line('Right one', 350, 90, 110, 12),
          _line('Left one', 50, 90, 110, 12),
          _line('Right two', 350, 104, 110, 12),
          _line('Left two', 50, 104, 110, 12),
          _line('Right three', 350, 118, 120, 12),
          _line('Left three', 50, 118, 120, 12),
        ],
      ),
    ]);

    final paragraphs = document.pages.single.blocks
        .whereType<EditableParagraphBlock>()
        .toList();
    expect(paragraphs, hasLength(2));
    expect(paragraphs.first.plainText, 'Left one Left two Left three');
    expect(paragraphs.last.plainText, 'Right one Right two Right three');
  });

  test('dehyphenates wrapped words conservatively', () {
    final document = reconstructor.reconstruct([
      PdfLayoutPageInput(
        pageIndex: 0,
        size: const Size(600, 800),
        lines: [
          _line('profession-', 50, 90, 90, 12),
          _line('ally formatted text', 50, 103, 150, 12),
        ],
      ),
    ]);

    final paragraph =
        document.pages.single.blocks.single as EditableParagraphBlock;
    expect(paragraph.plainText, 'professionally formatted text');
  });
}

PdfLayoutLineInput _line(
  String text,
  double left,
  double top,
  double width,
  double height, {
  double fontSize = 11,
  bool bold = false,
}) {
  return PdfLayoutLineInput(
    text: text,
    bounds: Rect.fromLTWH(left, top, width, height),
    fontSizePoints: fontSize,
    fontFamily: 'Arial',
    bold: bold,
    words: [
      PdfLayoutWordInput(
        text: text,
        bounds: Rect.fromLTWH(left, top, width, height),
        style: EditableTextStyle(
          fontFamily: 'Arial',
          fontSizePoints: fontSize,
          bold: bold,
        ),
      ),
    ],
  );
}

PdfLayoutLineInput _tableLine(String leftText, String rightText, double top) {
  const fontSize = 11.0;
  return PdfLayoutLineInput(
    text: '$leftText $rightText',
    bounds: Rect.fromLTWH(60, top, 360, 13),
    fontSizePoints: fontSize,
    fontFamily: 'Arial',
    words: [
      PdfLayoutWordInput(
        text: leftText,
        bounds: Rect.fromLTWH(60, top, 70, 13),
        style: const EditableTextStyle(
          fontFamily: 'Arial',
          fontSizePoints: fontSize,
        ),
      ),
      PdfLayoutWordInput(
        text: rightText,
        bounds: Rect.fromLTWH(320, top, 70, 13),
        style: const EditableTextStyle(
          fontFamily: 'Arial',
          fontSizePoints: fontSize,
        ),
      ),
    ],
  );
}
