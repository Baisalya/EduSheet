import 'dart:convert';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:edusheet/features/word_converter/domain/models/editable_document.dart';
import 'package:edusheet/features/word_converter/services/editable_docx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes semantic headings, editable table and per-page sections', () {
    final document = EditableDocument(
      pages: [
        EditablePage(
          pageIndex: 0,
          size: const Size(595, 842),
          margins: const EditablePageMargins(leftPoints: 48, rightPoints: 48),
          blocks: [
            const EditableParagraphBlock(
              kind: EditableParagraphKind.heading1,
              runs: [
                EditableTextRun(
                  text: 'Report',
                  style: EditableTextStyle(
                    fontFamily: 'Arial',
                    fontSizePoints: 18,
                    bold: true,
                  ),
                ),
              ],
            ),
            const EditableTableBlock(
              columnWidthsPoints: [180, 90],
              rows: [
                EditableTableRow(
                  cells: [
                    EditableTableCell(
                      paragraphs: [
                        EditableParagraphBlock(
                          runs: [EditableTextRun(text: 'Name')],
                        ),
                      ],
                    ),
                    EditableTableCell(
                      paragraphs: [
                        EditableParagraphBlock(
                          runs: [EditableTextRun(text: 'Marks')],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const EditablePage(
          pageIndex: 1,
          size: Size(842, 595),
          blocks: [
            EditableParagraphBlock(
              runs: [EditableTextRun(text: 'Landscape page')],
            ),
          ],
        ),
      ],
    );

    final archive = ZipDecoder().decodeBytes(EditableDocxWriter.build(document));
    final documentXml = _text(archive, 'word/document.xml');
    final stylesXml = _text(archive, 'word/styles.xml');
    final contentTypes = _text(archive, '[Content_Types].xml');

    expect(documentXml, contains('<w:pStyle w:val="Heading1"/>'));
    expect(documentXml, contains('<w:tbl>'));
    expect(documentXml, contains('<w:tc>'));
    expect(documentXml, contains('<w:type w:val="nextPage"/>'));
    expect(documentXml, contains('w:orient="landscape"'));
    expect(documentXml, contains('<w:rFonts w:ascii="Arial"'));
    expect(stylesXml, contains('w:styleId="Heading1"'));
    expect(contentTypes, contains('/word/styles.xml'));
  });
}

String _text(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}
