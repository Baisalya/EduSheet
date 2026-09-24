import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WM1+WM2 resolves scoped relationships, crop geometry and Word theme styles',
      () async {
    final fixture = await _writeWm12Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final section = document.sections.single;
    final paragraphs = section.blocks.whereType<ConversionParagraph>().toList();

    final heading = paragraphs[0].inlines.whereType<ConversionTextRun>().single;
    expect(heading.text, 'projects');
    expect(heading.style.fontFamily, 'Avenir Next');
    expect(heading.style.allCaps, isTrue);
    expect(heading.style.smallCaps, isFalse);
    expect(heading.style.letterSpacingPoints, closeTo(1, 0.001));
    expect(heading.style.colorHex, '99B3CC');

    final normal = paragraphs[1].inlines.whereType<ConversionTextRun>().single;
    expect(normal.style.fontFamily, 'Aptos');
    expect(normal.style.colorHex, '111111');

    final bodyImage = paragraphs[2].inlines.whereType<ConversionImageRun>().single;
    expect(bodyImage.crop.left, closeTo(0.25, 0.0001));
    expect(bodyImage.crop.top, closeTo(0.10, 0.0001));
    expect(bodyImage.crop.right, closeTo(0.05, 0.0001));
    expect(bodyImage.crop.bottom, closeTo(0, 0.0001));
    expect(bodyImage.rotationDegrees, closeTo(90, 0.001));
    expect(bodyImage.flipHorizontal, isTrue);
    expect(bodyImage.flipVertical, isFalse);
    expect(bodyImage.sourceRelationshipId, 'rIdPic');
    expect(bodyImage.sourcePartPath, 'word/media/body.png');

    final headerImage = section.headerBlocks
        .whereType<ConversionParagraph>()
        .single
        .inlines
        .whereType<ConversionImageRun>()
        .single;
    expect(headerImage.sourceRelationshipId, 'rIdPic');
    expect(headerImage.sourcePartPath, 'word/media/header.png');
  });

  testWidgets('WM1+WM2 viewer applies caps and mounts a crop clip', (tester) async {
    // File-system and ZIP/XML parsing use real asynchronous I/O. Widget tests
    // execute under FakeAsync, so run those operations outside the fake clock
    // just like the established DF1 real-DOCX widget regression. Without this
    // boundary the test can wait until the global 10-minute timeout even when
    // the renderer itself is healthy.
    final fixture = (await tester.runAsync<File>(_writeWm12Fixture))!;
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
              pageWidth: 612,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PROJECTS', findRichText: true), findsOneWidget);
    expect(
      find.byKey(const ValueKey('word-image-crop-clip')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('WM1 Smart Editor image payload preserves crop and transforms', () {
    final payload = SmartEditorInteropImagePayload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      objectId: 'image-1',
      widthPoints: 240,
      heightPoints: 160,
      cropLeft: 0.25,
      cropTop: 0.1,
      cropRight: 0.05,
      rotationDegrees: 90,
      flipHorizontal: true,
    );

    final decoded = SmartEditorInteropImagePayload.fromData(payload.encode());
    expect(decoded.cropLeft, closeTo(0.25, 0.0001));
    expect(decoded.cropTop, closeTo(0.1, 0.0001));
    expect(decoded.cropRight, closeTo(0.05, 0.0001));
    expect(decoded.rotationDegrees, closeTo(90, 0.001));
    expect(decoded.flipHorizontal, isTrue);
  });
}

Future<File> _writeWm12Fixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm12-');
  final file = File('${directory.path}${Platform.pathSeparator}wm12.docx');
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
   <w:pPr><w:pStyle w:val="SectionHeading"/></w:pPr>
   <w:r><w:t>projects</w:t></w:r>
  </w:p>
  <w:p><w:r><w:t>Default styled paragraph</w:t></w:r></w:p>
  <w:p><w:r><w:drawing>
   <wp:inline>
    <wp:extent cx="1905000" cy="1270000"/>
    <wp:docPr id="1" name="Cropped profile" descr="Cropped profile"/>
    <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
     <pic:pic>
      <pic:nvPicPr><pic:cNvPr id="1" name="body.png"/><pic:cNvPicPr/></pic:nvPicPr>
      <pic:blipFill>
       <a:blip r:embed="rIdPic"/>
       <a:srcRect l="25000" t="10000" r="5000" b="0"/>
       <a:stretch><a:fillRect/></a:stretch>
      </pic:blipFill>
      <pic:spPr>
       <a:xfrm rot="5400000" flipH="1"><a:off x="0" y="0"/><a:ext cx="1905000" cy="1270000"/></a:xfrm>
       <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </pic:spPr>
     </pic:pic>
    </a:graphicData></a:graphic>
   </wp:inline>
  </w:drawing></w:r></w:p>
  <w:sectPr>
   <w:headerReference w:type="default" r:id="rIdHeader"/>
   <w:pgSz w:w="12240" w:h="15840"/>
   <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="360" w:footer="360"/>
  </w:sectPr>
 </w:body>
</w:document>''';

  const documentRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPic" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/body.png"/>
 <Relationship Id="rIdHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
</Relationships>''';

  const headerXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
 <w:p><w:r><w:drawing><wp:inline>
  <wp:extent cx="254000" cy="254000"/>
  <wp:docPr id="2" name="Header image"/>
  <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
   <pic:pic><pic:blipFill><a:blip r:embed="rIdPic"/></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="254000" cy="254000"/></a:xfrm></pic:spPr></pic:pic>
  </a:graphicData></a:graphic>
 </wp:inline></w:drawing></w:r></w:p>
</w:hdr>''';

  const headerRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPic" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/header.png"/>
</Relationships>''';

  const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:docDefaults>
  <w:rPrDefault><w:rPr><w:rFonts w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr><w:spacing w:after="120"/></w:pPr></w:pPrDefault>
 </w:docDefaults>
 <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
  <w:name w:val="Normal"/>
  <w:rPr><w:color w:themeColor="text1" w:val="111111"/></w:rPr>
 </w:style>
 <w:style w:type="paragraph" w:styleId="SectionHeading">
  <w:name w:val="Section Heading"/><w:basedOn w:val="Normal"/>
  <w:rPr>
   <w:rFonts w:asciiTheme="majorHAnsi" w:hAnsiTheme="majorHAnsi"/>
   <w:color w:themeColor="accent1" w:themeTint="80" w:val="336699"/>
   <w:caps/><w:spacing w:val="20"/>
  </w:rPr>
 </w:style>
</w:styles>''';

  const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="WM12">
 <a:themeElements>
  <a:clrScheme name="WM12 Colors">
   <a:dk1><a:srgbClr val="111111"/></a:dk1>
   <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
   <a:dk2><a:srgbClr val="222222"/></a:dk2>
   <a:lt2><a:srgbClr val="EEEEEE"/></a:lt2>
   <a:accent1><a:srgbClr val="336699"/></a:accent1>
   <a:accent2><a:srgbClr val="993333"/></a:accent2>
   <a:accent3><a:srgbClr val="339966"/></a:accent3>
   <a:accent4><a:srgbClr val="663399"/></a:accent4>
   <a:accent5><a:srgbClr val="996633"/></a:accent5>
   <a:accent6><a:srgbClr val="336666"/></a:accent6>
   <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
   <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
  </a:clrScheme>
  <a:fontScheme name="WM12 Fonts">
   <a:majorFont><a:latin typeface="Avenir Next"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
   <a:minorFont><a:latin typeface="Aptos"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
  </a:fontScheme>
  <a:fmtScheme name="WM12 Format"/>
 </a:themeElements>
</a:theme>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', documentRels))
    ..addFile(ArchiveFile.string('word/header1.xml', headerXml))
    ..addFile(ArchiveFile.string('word/_rels/header1.xml.rels', headerRels))
    ..addFile(ArchiveFile.string('word/styles.xml', stylesXml))
    ..addFile(ArchiveFile.string('word/theme/theme1.xml', themeXml))
    ..addFile(ArchiveFile('word/media/body.png', png.length, png))
    ..addFile(ArchiveFile('word/media/header.png', png.length, png));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
