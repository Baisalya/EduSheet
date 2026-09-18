import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('DOCX parser preserves professional v1 structures', () async {
    final tempDir = await Directory.systemTemp.createTemp('docx_parser_test_');
    try {
      final input = await _writeRichDocx(tempDir);
      final document = await DocxConversionParser.parse(input);

      expect(document.sections, hasLength(1));
      final section = document.sections.single;
      expect(section.page.widthPoints, closeTo(792, 0.1));
      expect(section.page.heightPoints, closeTo(612, 0.1));
      expect(section.page.marginLeftPoints, closeTo(54, 0.1));
      expect(section.headerBlocks, isNotEmpty);
      expect(section.footerBlocks, isNotEmpty);

      final title = section.blocks.whereType<ConversionParagraph>().first;
      expect(title.alignment, ConversionTextAlignment.center);
      final titleRun = title.inlines.whereType<ConversionTextRun>().single;
      expect(titleRun.text, 'Professional Title');
      expect(titleRun.style.bold, isTrue);
      expect(titleRun.style.fontSizePoints, 18);
      expect(titleRun.style.colorHex, 'C00000');
      expect(titleRun.style.fontFamily, 'Arial');

      final hyperlinkParagraph = section.blocks
          .whereType<ConversionParagraph>()
          .firstWhere(
            (paragraph) => paragraph.inlines
                .whereType<ConversionTextRun>()
                .any((run) => run.text.contains('OpenAI')),
          );
      final hyperlinkRun = hyperlinkParagraph.inlines
          .whereType<ConversionTextRun>()
          .firstWhere((run) => run.text.contains('OpenAI'));
      expect(hyperlinkRun.hyperlink, 'https://openai.com/');

      final listParagraph = section.blocks
          .whereType<ConversionParagraph>()
          .firstWhere((paragraph) => paragraph.listLabel != null);
      expect(listParagraph.listLabel, '1. ');

      final table = section.blocks.whereType<ConversionTable>().single;
      expect(table.showBorders, isTrue);
      expect(table.rows, hasLength(2));
      expect(table.rows.first.isHeader, isTrue);
      expect(table.rows.first.cells, hasLength(2));

      final imageParagraph = section.blocks
          .whereType<ConversionParagraph>()
          .firstWhere(
            (paragraph) =>
                paragraph.inlines.whereType<ConversionImageRun>().isNotEmpty,
          );
      final image = imageParagraph.inlines.whereType<ConversionImageRun>().single;
      expect(image.bytes, isNotEmpty);
      expect(image.widthPoints, closeTo(144, 0.1));
      expect(image.heightPoints, closeTo(72, 0.1));

      final footer = section.footerBlocks.whereType<ConversionParagraph>().single;
      expect(
        footer.inlines.whereType<ConversionDynamicFieldRun>().map((e) => e.field),
        containsAll([
          ConversionDynamicField.pageNumber,
          ConversionDynamicField.pageCount,
        ]),
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}

Future<File> _writeRichDocx(Directory directory) async {
  final archive = Archive();

  void addText(String name, String value) {
    archive.addFile(ArchiveFile.string(name, value));
  }

  addText(
    'word/styles.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
    <w:pPrDefault><w:pPr><w:spacing w:after="120"/></w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="TitleStyle">
    <w:pPr><w:jc w:val="center"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Arial"/><w:b/><w:sz w:val="36"/><w:color w:val="C00000"/></w:rPr>
  </w:style>
</w:styles>''',
  );
  addText(
    'word/numbering.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>''',
  );
  addText(
    'word/_rels/document.xml.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdImg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/picture.png"/>
  <Relationship Id="rIdLink" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://openai.com/" TargetMode="External"/>
  <Relationship Id="rIdHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
  <Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>''',
  );
  addText(
    'word/header1.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>School Header</w:t></w:r></w:p></w:hdr>''',
  );
  addText(
    'word/footer1.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:p>
  <w:r><w:t>Page </w:t></w:r>
  <w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
  <w:r><w:t> of </w:t></w:r>
  <w:fldSimple w:instr="NUMPAGES"><w:r><w:t>1</w:t></w:r></w:fldSimple>
</w:p>
</w:ftr>''',
  );
  addText(
    'word/document.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
<w:body>
  <w:p><w:pPr><w:pStyle w:val="TitleStyle"/></w:pPr><w:r><w:t>Professional Title</w:t></w:r></w:p>
  <w:p><w:r><w:t>Visit </w:t></w:r><w:hyperlink r:id="rIdLink"><w:r><w:u w:val="single"/><w:t>OpenAI</w:t></w:r></w:hyperlink></w:p>
  <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>First item</w:t></w:r></w:p>
  <w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/></w:tblPr>
    <w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Marks</w:t></w:r></w:p></w:tc></w:tr>
    <w:tr><w:tc><w:p><w:r><w:t>Riya</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>92</w:t></w:r></w:p></w:tc></w:tr>
  </w:tbl>
  <w:p><w:r><w:drawing><wp:inline><wp:extent cx="1828800" cy="914400"/><wp:docPr id="1" name="Picture" descr="Sample image"/><a:graphic><a:graphicData><a:blip r:embed="rIdImg"/></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>
  <w:sectPr><w:headerReference w:type="default" r:id="rIdHeader"/><w:footerReference w:type="default" r:id="rIdFooter"/><w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720"/></w:sectPr>
</w:body></w:document>''',
  );

  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l9vLagAAAABJRU5ErkJggg==',
  );
  archive.addFile(ArchiveFile.bytes('word/media/picture.png', pngBytes));

  final file = File(p.join(directory.path, 'rich_document.docx'));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
