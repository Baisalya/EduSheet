import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DF2 parses advanced paragraph, table and anchored drawing layout', () async {
    final fixture = await _writeAdvancedFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final blocks = document.sections.single.blocks;

    final paragraph = blocks.whereType<ConversionParagraph>().first;
    expect(paragraph.lineSpacingMultiple, closeTo(1.5, 0.001));

    final table = blocks.whereType<ConversionTable>().single;
    expect(table.widthPercent, closeTo(85, 0.001));
    expect(table.indentPoints, closeTo(18, 0.001));
    expect(table.cellSpacingPoints, closeTo(2, 0.001));
    expect(table.gridColumnWidths, hasLength(2));

    final firstRow = table.rows.first;
    expect(firstRow.heightPoints, closeTo(30, 0.001));
    expect(firstRow.heightRule, ConversionTableRowHeightRule.exact);
    expect(firstRow.cells.single.gridSpan, 2);
    expect(
      firstRow.cells.single.verticalAlignment,
      ConversionTableCellVerticalAlignment.center,
    );
    expect(firstRow.cells.single.paddingTopPoints, closeTo(5, 0.001));
    expect(firstRow.cells.single.paddingLeftPoints, closeTo(6, 0.001));
    expect(firstRow.cells.single.paddingRightPoints, closeTo(10, 0.001));

    final drawingParagraph = blocks.whereType<ConversionParagraph>().last;
    final image = drawingParagraph.inlines.whereType<ConversionImageRun>().single;
    expect(image.placement.floating, isTrue);
    expect(image.placement.isPagePositioned, isTrue);
    expect(image.placement.horizontalRelativeFrom, 'margin');
    expect(image.placement.verticalRelativeFrom, 'page');
    expect(image.placement.horizontalOffsetPoints, closeTo(10, 0.001));
    expect(image.placement.verticalOffsetPoints, closeTo(20, 0.001));
    expect(image.placement.wrapStyle, 'wrapSquare');
  });

  testWidgets('DF2 renderer keeps header/footer, spanning cells and floating box', (
    tester,
  ) async {
    const bodyTextStyle = ConversionTextStyle(fontSizePoints: 11);
    final document = ConversionDocument(
      sections: [
        ConversionSection(
          page: const ConversionPageSettings(
            widthPoints: 612,
            heightPoints: 792,
            marginTopPoints: 72,
            marginRightPoints: 72,
            marginBottomPoints: 72,
            marginLeftPoints: 72,
            headerDistancePoints: 24,
            footerDistancePoints: 24,
          ),
          headerBlocks: const [
            ConversionParagraph(
              inlines: [ConversionTextRun(text: 'HEADER', style: bodyTextStyle)],
            ),
          ],
          footerBlocks: const [
            ConversionParagraph(
              inlines: [ConversionTextRun(text: 'FOOTER', style: bodyTextStyle)],
            ),
          ],
          blocks: const [
            ConversionTable(
              widthPercent: 100,
              gridColumnWidths: [180, 300],
              rows: [
                ConversionTableRow(
                  cells: [
                    ConversionTableCell(
                      gridSpan: 2,
                      verticalAlignment: ConversionTableCellVerticalAlignment.center,
                      blocks: [
                        ConversionParagraph(
                          inlines: [
                            ConversionTextRun(text: 'SPAN BOTH COLUMNS'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                ConversionTableRow(
                  cells: [
                    ConversionTableCell(
                      blocks: [
                        ConversionParagraph(
                          inlines: [ConversionTextRun(text: 'LEFT COLUMN')],
                        ),
                      ],
                    ),
                    ConversionTableCell(
                      blocks: [
                        ConversionParagraph(
                          inlines: [ConversionTextRun(text: 'RIGHT COLUMN')],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ConversionParagraph(
              inlines: [
                ConversionTextBoxRun(
                  widthPoints: 120,
                  heightPoints: 50,
                  placement: ConversionObjectPlacement.floating(
                    horizontalRelativeFrom: 'margin',
                    verticalRelativeFrom: 'page',
                    horizontalOffsetPoints: 12,
                    verticalOffsetPoints: 18,
                  ),
                  blocks: [
                    ConversionParagraph(
                      inlines: [ConversionTextRun(text: 'FLOAT BOX')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 900,
            child: WordFidelityDocumentView(
              document: document,
              pageWidth: 612,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-fidelity-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-fidelity-footer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('word-table-cell-0-0-span-2')),
      findsOneWidget,
    );
    expect(find.textContaining('LEFT COLUMN', findRichText: true), findsWidgets);
    expect(find.textContaining('RIGHT COLUMN', findRichText: true), findsWidgets);
    expect(find.textContaining('FLOAT BOX', findRichText: true), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('word-floating-'),
      ),
      findsOneWidget,
    );
  });
}

Future<File> _writeAdvancedFixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-df2-layout-');
  final file = File('${directory.path}${Platform.pathSeparator}advanced.docx');
  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGNkaPj/n4GBgYGJAQoAJRkCgp9o0gYAAAAASUVORK5CYII=',
    ),
  );

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
 <w:body>
  <w:p>
   <w:pPr><w:spacing w:line="360" w:lineRule="auto"/></w:pPr>
   <w:r><w:t>ADVANCED LAYOUT</w:t></w:r>
  </w:p>
  <w:tbl>
   <w:tblPr>
    <w:tblW w:w="4250" w:type="pct"/>
    <w:tblInd w:w="360" w:type="dxa"/>
    <w:tblCellSpacing w:w="40" w:type="dxa"/>
    <w:tblCellMar>
     <w:top w:w="100" w:type="dxa"/>
     <w:left w:w="120" w:type="dxa"/>
     <w:right w:w="120" w:type="dxa"/>
     <w:bottom w:w="100" w:type="dxa"/>
    </w:tblCellMar>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="2400"/><w:gridCol w:w="4800"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:trHeight w:val="600" w:hRule="exact"/></w:trPr>
    <w:tc>
     <w:tcPr>
      <w:gridSpan w:val="2"/>
      <w:vAlign w:val="center"/>
      <w:tcMar><w:right w:w="200" w:type="dxa"/></w:tcMar>
     </w:tcPr>
     <w:p><w:r><w:t>MERGED HEADING</w:t></w:r></w:p>
    </w:tc>
   </w:tr>
   <w:tr>
    <w:tc><w:p><w:r><w:t>LEFT</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>RIGHT</w:t></w:r></w:p></w:tc>
   </w:tr>
  </w:tbl>
  <w:p>
   <w:r><w:drawing>
    <wp:anchor behindDoc="0" allowOverlap="1">
     <wp:positionH relativeFrom="margin"><wp:posOffset>127000</wp:posOffset></wp:positionH>
     <wp:positionV relativeFrom="page"><wp:posOffset>254000</wp:posOffset></wp:positionV>
     <wp:extent cx="1270000" cy="635000"/>
     <wp:wrapSquare wrapText="bothSides"/>
     <wp:docPr id="1" name="Floating image" descr="Floating image"/>
     <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic><pic:blipFill><a:blip r:embed="rIdPhoto"/></pic:blipFill></pic:pic>
     </a:graphicData></a:graphic>
    </wp:anchor>
   </w:drawing></w:r>
  </w:p>
  <w:sectPr>
   <w:pgSz w:w="12240" w:h="15840"/>
   <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="480" w:footer="480"/>
  </w:sectPr>
 </w:body>
</w:document>''';

  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>
</Relationships>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.bytes('word/media/photo.png', png));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
