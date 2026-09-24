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
  test(
    'DF6 production-like academic DOCX parses without data-loss or runaway time',
    () async {
      final fixture = await _writeProductionFixture(pageCount: 30);
      addTearDown(() async {
        if (await fixture.parent.exists()) {
          await fixture.parent.delete(recursive: true);
        }
      });

      final stopwatch = Stopwatch()..start();
      final document = await DocxConversionParser.parse(fixture);
      stopwatch.stop();

      expect(document.sections, isNotEmpty);
      final text = _plainText(document.sections.expand((section) => section.blocks));
      expect(text, contains('EDUSHEET PRODUCTION CERTIFICATION'));
      expect(text, contains('Mathematics'));
      expect(text, contains('ଗଣିତ'));
      expect(text, contains('हिन्दी'));
      expect(text, contains('Teacher observation'));
      expect(text, contains('Page 30 of 30'));

      final tables = _collectTables(
        document.sections.expand((section) => section.blocks),
      );
      expect(tables, isNotEmpty);
      expect(tables.first.rows, isNotEmpty);
      expect(tables.first.rows.first.cells.first.gridSpan, 2);

      final images = _collectImages(
        document.sections.expand((section) => section.blocks),
      );
      expect(images, isNotEmpty);
      expect(images.first.bytes, isNotEmpty);
      expect(images.first.placement.floating, isTrue);

      final textBoxes = _collectTextBoxes(
        document.sections.expand((section) => section.blocks),
      );
      expect(textBoxes, isNotEmpty);
      expect(_plainText(textBoxes.first.blocks), contains('Teacher observation'));

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    },
  );

  test('DF6 malformed DOCX exits deterministically instead of hanging', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-df6-bad-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}broken.docx');
    await file.writeAsBytes(
      utf8.encode('this is not a valid OOXML zip package'),
      flush: true,
    );

    Object? failure;
    ConversionDocument? parsed;
    final stopwatch = Stopwatch()..start();
    try {
      parsed = await DocxConversionParser.parse(file);
    } catch (error) {
      failure = error;
    } finally {
      stopwatch.stop();
    }

    final producedNoUsableDocument = parsed == null ||
        parsed.sections.isEmpty ||
        parsed.sections.every((section) => section.blocks.isEmpty);
    expect(failure != null || producedNoUsableDocument, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  testWidgets(
    'DF6 320x520 Word viewport stays usable and lazily mounts long documents',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 520));

      final document = _syntheticLongDocument(36);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(
              document: document,
              pageWidth: 374,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('word-fidelity-lazy-page-list')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('word-fidelity-page')), findsWidgets);
      expect(
        find.byKey(const ValueKey('word-fidelity-page')).evaluate().length,
        lessThan(36),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DF6 1440x900 desktop Word viewport renders without layout exceptions',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final document = _syntheticLongDocument(12);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordFidelityDocumentView(
              document: document,
              pageWidth: 860,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('word-fidelity-lazy-page-list')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('word-fidelity-page')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

ConversionDocument _syntheticLongDocument(int pages) {
  return ConversionDocument(
    sections: <ConversionSection>[
      ConversionSection(
        page: const ConversionPageSettings(),
        blocks: List<ConversionBlock>.generate(
          pages,
          (index) => ConversionParagraph(
            pageBreakBefore: index > 0,
            inlines: <ConversionInline>[
              ConversionTextRun(
                text: 'DF6 responsive certification page ${index + 1}',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

String _plainText(Iterable<ConversionBlock> blocks) {
  final out = StringBuffer();

  void visit(Iterable<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            out.write(inline.text);
            out.write(' ');
          } else if (inline is ConversionTextBoxRun) {
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
  return out.toString();
}

List<ConversionTable> _collectTables(Iterable<ConversionBlock> blocks) {
  final result = <ConversionTable>[];

  void visit(Iterable<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionTable) {
        result.add(block);
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      } else if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextBoxRun) {
            visit(inline.blocks);
          }
        }
      }
    }
  }

  visit(blocks);
  return result;
}

List<ConversionImageRun> _collectImages(Iterable<ConversionBlock> blocks) {
  final result = <ConversionImageRun>[];

  void visit(Iterable<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionImageRun) {
            result.add(inline);
          } else if (inline is ConversionTextBoxRun) {
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
  return result;
}

List<ConversionTextBoxRun> _collectTextBoxes(
  Iterable<ConversionBlock> blocks,
) {
  final result = <ConversionTextBoxRun>[];

  void visit(Iterable<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextBoxRun) {
            result.add(inline);
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
  return result;
}

Future<File> _writeProductionFixture({required int pageCount}) async {
  final directory =
      await Directory.systemTemp.createTemp('edusheet-df6-production-');
  final file = File(
    '${directory.path}${Platform.pathSeparator}production-academic.docx',
  );

  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGNkaPj/n4GBgYGJAQoAJRkCgp9o0gYAAAAASUVORK5CYII=',
    ),
  );

  final body = StringBuffer()
    ..write(r'''
  <w:p>
   <w:pPr><w:jc w:val="center"/></w:pPr>
   <w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
    <w:t>EDUSHEET PRODUCTION CERTIFICATION</w:t>
   </w:r>
  </w:p>
  <w:p>
   <w:r><w:t>Mathematics • ଗଣିତ • हिन्दी • Science • Teacher Workspace</w:t></w:r>
  </w:p>
  <w:p>
   <w:r><w:drawing>
    <wp:anchor distT="0" distB="0" distL="0" distR="0"
      simplePos="0" relativeHeight="251658240" behindDoc="0"
      locked="0" layoutInCell="1" allowOverlap="1">
     <wp:simplePos x="0" y="0"/>
     <wp:positionH relativeFrom="margin"><wp:posOffset>457200</wp:posOffset></wp:positionH>
     <wp:positionV relativeFrom="margin"><wp:posOffset>228600</wp:posOffset></wp:positionV>
     <wp:extent cx="914400" cy="685800"/>
     <wp:wrapSquare wrapText="bothSides"/>
     <wp:docPr id="1" name="Teacher diagram" descr="Teacher diagram"/>
     <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic>
       <pic:nvPicPr><pic:cNvPr id="0" name="Teacher diagram"/><pic:cNvPicPr/></pic:nvPicPr>
       <pic:blipFill><a:blip r:embed="rIdImage"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
       <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="685800"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
       </pic:spPr>
      </pic:pic>
     </a:graphicData></a:graphic>
    </wp:anchor>
   </w:drawing></w:r>
  </w:p>
  <w:tbl>
   <w:tblPr>
    <w:tblW w:w="4750" w:type="pct"/>
    <w:tblInd w:w="240" w:type="dxa"/>
    <w:tblCellSpacing w:w="40" w:type="dxa"/>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="3000"/><w:gridCol w:w="4200"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:tblHeader/><w:trHeight w:val="500" w:hRule="atLeast"/></w:trPr>
    <w:tc>
     <w:tcPr><w:gridSpan w:val="2"/><w:vAlign w:val="center"/></w:tcPr>
     <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Assessment Overview</w:t></w:r></w:p>
    </w:tc>
   </w:tr>
   <w:tr>
    <w:tc><w:p><w:r><w:t>Subject</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Mathematics</w:t></w:r></w:p></w:tc>
   </w:tr>
  </w:tbl>
  <w:p>
   <w:r><w:pict>
    <v:shape id="TeacherNote"
      style="position:absolute;margin-left:24pt;margin-top:18pt;
      mso-position-horizontal-relative:margin;
      mso-position-vertical-relative:margin;
      width:180pt;height:72pt;z-index:251658240"
      o:allowoverlap="t">
     <v:stroke on="f"/><v:fill on="f"/>
     <v:textbox inset="6pt,4pt,6pt,4pt"><w:txbxContent>
      <w:p><w:r><w:t>Teacher observation</w:t></w:r></w:p>
     </w:txbxContent></v:textbox>
    </v:shape>
   </w:pict></w:r>
  </w:p>
''');

  for (var page = 1; page <= pageCount; page++) {
    body.write('''
  <w:p>
   <w:pPr>${page == 1 ? '' : '<w:pageBreakBefore/>'}
    <w:spacing w:after="120" w:line="300" w:lineRule="auto"/>
   </w:pPr>
   <w:r><w:rPr><w:b/></w:rPr><w:t>Page $page of $pageCount</w:t></w:r>
  </w:p>
  <w:p>
   <w:r><w:t>Question $page: Explain a real classroom concept, show working, and write the final answer.</w:t></w:r>
  </w:p>
''');
  }

  body.write(r'''
  <w:sectPr>
   <w:pgSz w:w="11906" w:h="16838"/>
   <w:pgMar w:top="1134" w:right="1134" w:bottom="1134"
    w:left="1134" w:header="567" w:footer="567" w:gutter="0"/>
  </w:sectPr>
''');

  final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:o="urn:schemas-microsoft-com:office:office">
 <w:body>
${body.toString()}
 </w:body>
</w:document>''';

  const documentRels = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdImage"
  Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
  Target="media/teacher.png"/>
</Relationships>''';

  const packageRels = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1"
  Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
  Target="word/document.xml"/>
</Relationships>''';

  const contentTypes = r'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Default Extension="png" ContentType="image/png"/>
 <Override PartName="/word/document.xml"
  ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', packageRels))
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(
      ArchiveFile.string('word/_rels/document.xml.rels', documentRels),
    )
    ..addFile(ArchiveFile.bytes('word/media/teacher.png', png));

  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
