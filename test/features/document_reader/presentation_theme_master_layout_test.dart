import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/document_reader/data/services/presentation_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves theme master and layout placeholder fidelity', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edusheet-pptx-theme-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}theme.pptx',
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'ppt/presentation.xml',
          '''<?xml version="1.0"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
 <p:sldSz cx="12192000" cy="6858000"/>
</p:presentation>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/_rels/presentation.xml.rels',
          '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slides/slide1.xml',
          '''<?xml version="1.0"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree><p:sp>
  <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title" idx="1"/></p:nvPr></p:nvSpPr>
  <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:solidFill><a:schemeClr val="accent1"/></a:solidFill><a:latin typeface="+mj-lt"/></a:rPr><a:t>Themed title</a:t></a:r></a:p></p:txBody>
 </p:sp></p:spTree></p:cSld>
</p:sld>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slides/_rels/slide1.xml.rels',
          '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slideLayouts/slideLayout1.xml',
          '''<?xml version="1.0"?>
<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:spTree><p:sp>
  <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title" idx="1"/></p:nvPr></p:nvSpPr>
  <p:spPr><a:xfrm><a:off x="1219200" y="685800"/><a:ext cx="9753600" cy="1371600"/></a:xfrm></p:spPr>
 </p:sp></p:spTree></p:cSld>
</p:sldLayout>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
          '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slideMasters/slideMaster1.xml',
          '''<?xml version="1.0"?>
<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
 <p:cSld><p:bg><p:bgPr><a:solidFill><a:schemeClr val="bg1"/></a:solidFill></p:bgPr></p:bg><p:spTree/></p:cSld>
 <p:txStyles><p:titleStyle><a:lvl1pPr algn="ctr"><a:defRPr sz="3600" b="1"><a:latin typeface="+mj-lt"/></a:defRPr></a:lvl1pPr></p:titleStyle></p:txStyles>
</p:sldMaster>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/slideMasters/_rels/slideMaster1.xml.rels',
          '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/theme/theme1.xml',
          '''<?xml version="1.0"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:themeElements>
 <a:clrScheme name="Office"><a:dk1><a:srgbClr val="111111"/></a:dk1><a:lt1><a:srgbClr val="F8F8F8"/></a:lt1><a:accent1><a:srgbClr val="3366CC"/></a:accent1></a:clrScheme>
 <a:fontScheme name="Office"><a:majorFont><a:latin typeface="Aptos Display"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme>
</a:themeElements></a:theme>''',
        ),
      );

    await file.writeAsBytes(ZipEncoder().encode(archive));
    final presentation = await PresentationParserService().load(file);
    final slide = presentation.slides.single;
    final title = slide.elements.single;

    expect(slide.backgroundColor, 0xFFF8F8F8);
    expect(title.hasBounds, isTrue);
    expect(title.left, closeTo(0.1, 0.001));
    expect(title.width, closeTo(0.8, 0.001));
    expect(title.fontSizePoints, 36);
    expect(title.fontFamily, 'Aptos Display');
    expect(title.bold, isTrue);
    expect(title.alignment, 'ctr');
    expect(title.textColor, 0xFF3366CC);
    expect(title.textRuns.single.fontFamily, 'Aptos Display');
    expect(title.textRuns.single.color, 0xFF3366CC);
  });
}
