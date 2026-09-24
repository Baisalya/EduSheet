import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WM3 parses tabs, paragraph borders, flow and exact numbering glyphs', () async {
    final fixture = await _writeWm34Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final paragraphs = document.sections.single.blocks
        .whereType<ConversionParagraph>()
        .toList(growable: false);

    final heading = paragraphs[0];
    expect(heading.keepWithNext, isTrue);
    expect(heading.keepLines, isTrue);
    expect(heading.widowControl, isFalse);
    expect(heading.contextualSpacing, isTrue);
    expect(heading.borders.bottom?.style, ConversionBorderStyle.single);
    expect(heading.borders.bottom?.colorHex, '4288B9');
    expect(heading.borders.bottom?.widthPoints, closeTo(1.5, 0.001));

    final bullet = paragraphs[1];
    expect(bullet.listLabel, '➢\t');
    expect(bullet.listLabelStyle?.fontFamily, 'Wingdings');
    expect(bullet.leftIndentPoints, closeTo(36, 0.001));
    expect(bullet.firstLineIndentPoints, closeTo(-18, 0.001));
    expect(bullet.tabStops.single.positionPoints, closeTo(36, 0.001));

    final signature = paragraphs[2];
    expect(signature.tabStops, hasLength(1));
    expect(signature.tabStops.single.alignment, ConversionTabAlignment.right);
    expect(signature.tabStops.single.leader, ConversionTabLeader.dot);
    expect(signature.tabStops.single.positionPoints, closeTo(450, 0.001));
  });

  test('WM4 resolves table styles, conditional header, borders and cell rules', () async {
    final fixture = await _writeWm34Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final table = document.sections.single.blocks.whereType<ConversionTable>().single;

    expect(table.styleId, 'ResumeGrid');
    expect(table.layout, ConversionTableLayout.fixed);
    expect(table.widthPercent, closeTo(100, 0.001));
    expect(table.indentPoints, closeTo(12, 0.001));
    expect(table.cellSpacingPoints, closeTo(2, 0.001));
    expect(table.alignment, ConversionTextAlignment.center);
    expect(table.borders.top?.colorHex, '4472C4');
    expect(table.borders.insideHorizontal?.style, ConversionBorderStyle.single);

    final header = table.rows.first;
    expect(header.isHeader, isTrue);
    expect(header.cantSplit, isTrue);
    expect(header.cells.first.shadingHex, 'D9EAF7');
    expect(
      header.cells.first.verticalAlignment,
      ConversionTableCellVerticalAlignment.center,
    );
    expect(header.cells.first.noWrap, isTrue);
    expect(header.cells.first.paddingLeftPoints, closeTo(6, 0.001));
    final headerText = header.cells.first.blocks
        .whereType<ConversionParagraph>()
        .single
        .inlines
        .whereType<ConversionTextRun>()
        .single;
    expect(headerText.style.bold, isTrue);
    expect(headerText.style.colorHex, '1F4E79');

    final body = table.rows[1];
    expect(body.cells.first.noWrap, isTrue);
    expect(body.cells.first.borders.bottom?.style, ConversionBorderStyle.dashed);
    expect(body.cells.first.borders.bottom?.colorHex, 'C00000');
    expect(body.cells[1].verticalMerge, ConversionVerticalMerge.restart);
    expect(table.rows[2].cells[1].verticalMerge, ConversionVerticalMerge.continuation);
  });

  testWidgets('WM3+WM4 viewer mounts tab, paragraph-border and cell-border engines', (
    tester,
  ) async {
    final fixture = (await tester.runAsync<File>(_writeWm34Fixture))!;
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
            width: 1000,
            height: 900,
            child: WordFidelityDocumentView(
              document: document,
              pageWidth: 816,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-paragraph-border')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-tab-layout')), findsWidgets);
    expect(
      find.byKey(const ValueKey('word-table-cell-border-0-0')),
      findsOneWidget,
    );
    expect(find.text('COURSE', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<File> _writeWm34Fixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm34-');
  final file = File('${directory.path}${Platform.pathSeparator}wm34.docx');

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:p>
   <w:pPr><w:pStyle w:val="RuleHeading"/></w:pPr>
   <w:r><w:t>EDUCATION</w:t></w:r>
  </w:p>
  <w:p>
   <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="5"/></w:numPr></w:pPr>
   <w:r><w:t>Preserve Word bullet glyph</w:t></w:r>
  </w:p>
  <w:p>
   <w:pPr><w:tabs><w:tab w:val="right" w:leader="dot" w:pos="9000"/></w:tabs></w:pPr>
   <w:r><w:t>Place: Kendrapara</w:t><w:tab/><w:t>Signature</w:t></w:r>
  </w:p>
  <w:tbl>
   <w:tblPr>
    <w:tblStyle w:val="ResumeGrid"/>
    <w:tblLook w:firstRow="1" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="1" w:noVBand="1"/>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="3600"/><w:gridCol w:w="5400"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>
    <w:tc><w:tcPr><w:tcW w:type="dxa" w:w="3600"/></w:tcPr><w:p><w:r><w:t>COURSE</w:t></w:r></w:p></w:tc>
    <w:tc><w:tcPr><w:tcW w:type="dxa" w:w="5400"/></w:tcPr><w:p><w:r><w:t>INSTITUTION</w:t></w:r></w:p></w:tc>
   </w:tr>
   <w:tr>
    <w:tc>
     <w:tcPr><w:noWrap/><w:tcBorders><w:bottom w:val="dashed" w:sz="8" w:color="C00000"/></w:tcBorders></w:tcPr>
     <w:p><w:r><w:t>MCA</w:t></w:r></w:p>
    </w:tc>
    <w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Centurion University</w:t></w:r></w:p></w:tc>
   </w:tr>
   <w:tr>
    <w:tc><w:p><w:r><w:t>BCA</w:t></w:r></w:p></w:tc>
    <w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc>
   </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>
 </w:body>
</w:document>''';

  const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
 <w:style w:type="paragraph" w:styleId="RuleHeading">
  <w:name w:val="Rule Heading"/><w:basedOn w:val="Normal"/>
  <w:pPr>
   <w:keepNext/><w:keepLines/><w:widowControl w:val="0"/><w:contextualSpacing/>
   <w:pBdr><w:bottom w:val="single" w:sz="12" w:space="4" w:color="4288B9"/></w:pBdr>
  </w:pPr>
  <w:rPr><w:b/><w:color w:val="4288B9"/></w:rPr>
 </w:style>
 <w:style w:type="table" w:styleId="ResumeGrid">
  <w:name w:val="Resume Grid"/>
  <w:tblPr>
   <w:tblW w:type="pct" w:w="5000"/>
   <w:tblLayout w:type="fixed"/>
   <w:tblInd w:type="dxa" w:w="240"/>
   <w:tblCellSpacing w:type="dxa" w:w="40"/>
   <w:jc w:val="center"/>
   <w:tblBorders>
    <w:top w:val="single" w:sz="8" w:color="4472C4"/>
    <w:left w:val="single" w:sz="8" w:color="4472C4"/>
    <w:bottom w:val="single" w:sz="8" w:color="4472C4"/>
    <w:right w:val="single" w:sz="8" w:color="4472C4"/>
    <w:insideH w:val="single" w:sz="4" w:color="9EADBA"/>
    <w:insideV w:val="single" w:sz="4" w:color="9EADBA"/>
   </w:tblBorders>
   <w:tblCellMar>
    <w:top w:type="dxa" w:w="80"/><w:left w:type="dxa" w:w="120"/>
    <w:bottom w:type="dxa" w:w="80"/><w:right w:type="dxa" w:w="120"/>
   </w:tblCellMar>
  </w:tblPr>
  <w:tblStylePr w:type="firstRow">
   <w:tcPr><w:shd w:fill="D9EAF7"/><w:vAlign w:val="center"/><w:noWrap/></w:tcPr>
   <w:rPr><w:b/><w:color w:val="1F4E79"/></w:rPr>
  </w:tblStylePr>
 </w:style>
</w:styles>''';

  const numberingXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:abstractNum w:abstractNumId="2">
  <w:lvl w:ilvl="0">
   <w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="➢"/><w:suff w:val="tab"/>
   <w:pPr><w:tabs><w:tab w:val="left" w:pos="720"/></w:tabs><w:ind w:left="720" w:hanging="360"/></w:pPr>
   <w:rPr><w:rFonts w:ascii="Wingdings" w:hAnsi="Wingdings"/></w:rPr>
  </w:lvl>
 </w:abstractNum>
 <w:num w:numId="5"><w:abstractNumId w:val="2"/></w:num>
</w:numbering>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/styles.xml', stylesXml))
    ..addFile(ArchiveFile.string('word/numbering.xml', numberingXml));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
