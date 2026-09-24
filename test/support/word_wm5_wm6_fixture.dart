import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Future<File> writeWm56Fixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm56-');
  final file = File('${directory.path}${Platform.pathSeparator}wm56.docx');
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
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:w10="urn:schemas-microsoft-com:office:word">
 <w:body>
  <w:p><w:r><w:t>Section one</w:t></w:r></w:p>
  <w:p><w:r><w:drawing>
   <wp:anchor distT="76200" distB="88900" distL="101600" distR="114300"
    simplePos="0" relativeHeight="123456" behindDoc="0" locked="1"
    layoutInCell="0" allowOverlap="0">
    <wp:simplePos x="0" y="0"/>
    <wp:positionH relativeFrom="page"><wp:posOffset>914400</wp:posOffset></wp:positionH>
    <wp:positionV relativeFrom="margin"><wp:posOffset>457200</wp:posOffset></wp:positionV>
    <wp:extent cx="1524000" cy="1016000"/>
    <wp:wrapTight wrapText="largest"><wp:wrapPolygon edited="0"><wp:start x="0" y="0"/><wp:lineTo x="0" y="21600"/><wp:lineTo x="21600" y="21600"/><wp:lineTo x="21600" y="0"/><wp:lineTo x="0" y="0"/></wp:wrapPolygon></wp:wrapTight>
    <wp:docPr id="1" name="WM5 photo" descr="WM5 photo"/>
    <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
     <pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="photo.png"/><pic:cNvPicPr/></pic:nvPicPr>
      <pic:blipFill><a:blip r:embed="rIdPhoto"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
      <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1524000" cy="1016000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
     </pic:pic>
    </a:graphicData></a:graphic>
   </wp:anchor>
  </w:drawing></w:r></w:p>
  <w:p><w:r><w:pict>
   <v:roundrect id="wm5Shape" fillcolor="#EAF2F8" strokecolor="#2E75B6" strokeweight="1.5pt"
    style="position:absolute;margin-left:36pt;margin-top:24pt;mso-position-horizontal-relative:column;mso-position-vertical-relative:page;mso-wrap-distance-left:4pt;mso-wrap-distance-right:5pt;mso-wrap-distance-top:2pt;mso-wrap-distance-bottom:3pt;width:144pt;height:54pt;z-index:-42"
    o:allowoverlap="t">
    <w10:wrap type="through" side="left"/>
   </v:roundrect>
  </w:pict></w:r></w:p>
  <w:p><w:r><w:br w:type="column"/></w:r><w:r><w:t>After manual column break</w:t></w:r></w:p>
  <w:p>
   <w:pPr><w:sectPr>
    <w:headerReference w:type="default" r:id="rIdHeaderDefault"/>
    <w:headerReference w:type="first" r:id="rIdHeaderFirst"/>
    <w:headerReference w:type="even" r:id="rIdHeaderEven"/>
    <w:footerReference w:type="default" r:id="rIdFooterDefault"/>
    <w:type w:val="oddPage"/><w:titlePg/>
    <w:pgSz w:w="12240" w:h="15840"/>
    <w:pgMar w:top="900" w:right="1000" w:bottom="1100" w:left="1200" w:header="400" w:footer="500" w:gutter="360"/>
    <w:cols w:num="2" w:equalWidth="0" w:space="360" w:sep="1"><w:col w:w="4320" w:space="360"/><w:col w:w="5760" w:space="0"/></w:cols>
    <w:pgNumType w:start="7" w:fmt="upperRoman"/>
    <w:pgBorders w:offsetFrom="page" w:display="firstPage" w:zOrder="back"><w:bottom w:val="single" w:sz="8" w:space="12" w:color="4472C4"/></w:pgBorders>
   </w:sectPr></w:pPr>
  </w:p>
  <w:p><w:r><w:t>Section two landscape</w:t></w:r></w:p>
  <w:sectPr>
   <w:type w:val="oddPage"/>
   <w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/>
   <w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="360" w:footer="360"/>
   <w:cols w:num="1"/>
  </w:sectPr>
 </w:body>
</w:document>''';

  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>
 <Relationship Id="rIdHeaderDefault" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
 <Relationship Id="rIdHeaderFirst" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header2.xml"/>
 <Relationship Id="rIdHeaderEven" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header3.xml"/>
 <Relationship Id="rIdFooterDefault" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>''';

  const settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:evenAndOddHeaders/><w:mirrorMargins/><w:gutterAtTop/></w:settings>''';
  const headerDefault = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Default header</w:t></w:r></w:p></w:hdr>''';
  const headerFirst = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>First header</w:t></w:r></w:p></w:hdr>''';
  const headerEven = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Even header</w:t></w:r></w:p></w:hdr>''';
  const footerDefault = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Page </w:t></w:r><w:fldSimple w:instr=" PAGE "><w:r><w:t>7</w:t></w:r></w:fldSimple><w:r><w:t> / </w:t></w:r><w:fldSimple w:instr=" NUMPAGES "><w:r><w:t>2</w:t></w:r></w:fldSimple></w:p></w:ftr>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.string('word/settings.xml', settingsXml))
    ..addFile(ArchiveFile.string('word/header1.xml', headerDefault))
    ..addFile(ArchiveFile.string('word/header2.xml', headerFirst))
    ..addFile(ArchiveFile.string('word/header3.xml', headerEven))
    ..addFile(ArchiveFile.string('word/footer1.xml', footerDefault))
    ..addFile(ArchiveFile.bytes('word/media/photo.png', png));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
