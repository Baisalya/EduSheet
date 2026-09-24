import 'dart:io';

import 'package:archive/archive.dart';

Future<File> writeWm9PreservationFixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm9-');
  final file = File(
    '${directory.path}${Platform.pathSeparator}wm9-preservation.docx',
  );

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart"
 xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"
 xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex">
 <w:body>
  <w:p><w:r><w:t>WM9 preservation baseline</w:t></w:r></w:p>
  <w:sdt>
   <w:sdtPr><w:tag w:val="teacher-form"/></w:sdtPr>
   <w:sdtContent><w:p><w:r><w:t>Protected classroom form</w:t></w:r></w:p></w:sdtContent>
  </w:sdt>
  <w:p>
   <w:r>
    <w:t xml:space="preserve">Before chart </w:t>
    <w:drawing>
     <wp:inline><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">
      <c:chart r:id="rIdChart1"/>
     </a:graphicData></a:graphic></wp:inline>
    </w:drawing>
    <w:t xml:space="preserve"> after chart</w:t>
   </w:r>
  </w:p>
  <w:p>
   <w:r>
    <w:object>
     <o:OLEObject Type="Embed" ProgID="Excel.Sheet.12" r:id="rIdOle1"/>
    </w:object>
   </w:r>
  </w:p>
  <w:p>
   <w:r>
    <w:drawing>
     <wp:inline><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/diagram">
      <dgm:relIds r:dm="rIdDiagram1"/>
     </a:graphicData></a:graphic></wp:inline>
    </w:drawing>
   </w:r>
  </w:p>
  <mc:AlternateContent>
   <mc:Choice Requires="w15"><w:p><w:r><w:t>Compatibility choice payload</w:t></w:r></w:p></mc:Choice>
   <mc:Fallback><w:p><w:r><w:t>Compatibility fallback payload</w:t></w:r></w:p></mc:Fallback>
  </mc:AlternateContent>
  <w:customXml w:element="schoolMeta">
   <w:p><w:r><w:t>Custom XML visible fallback</w:t></w:r></w:p>
  </w:customXml>
  <w:tbl>
   <w:tblPr><w:tblW w:w="5000" w:type="dxa"/></w:tblPr>
   <w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>
   <w:tr><w:tc><w:tcPr/><w:sdt><w:sdtContent>
    <w:p><w:r><w:t>Nested protected cell</w:t></w:r></w:p>
   </w:sdtContent></w:sdt></w:tc></w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
 </w:body>
</w:document>''';

  const documentRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdChart1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="charts/chart1.xml"/>
 <Relationship Id="rIdOle1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject" Target="embeddings/oleObject1.bin"/>
 <Relationship Id="rIdDiagram1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData" Target="diagrams/data1.xml"/>
 <Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/customXml" Target="../customXml/item1.xml"/>
 <Relationship Id="rIdTheme1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
 <Relationship Id="rIdCommentsLegacy" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/>
</Relationships>''';

  const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdOfficeDocument" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties" Target="docProps/custom.xml"/>
</Relationships>''';

  const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Default Extension="bin" ContentType="application/vnd.openxmlformats-officedocument.oleObject"/>
 <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
 <Override PartName="/word/charts/chart1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>
 <Override PartName="/word/diagrams/data1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml"/>
 <Override PartName="/word/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
 <Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>
 <Override PartName="/docProps/custom.xml" ContentType="application/vnd.openxmlformats-officedocument.custom-properties+xml"/>
</Types>''';

  const chartXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
 <c:chart><c:autoTitleDeleted val="1"/><c:externalData r:id="rIdWorkbook"/></c:chart>
</c:chartSpace>''';

  const chartRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdWorkbook" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/package" Target="../embeddings/oleObject1.bin"/>
</Relationships>''';

  const diagramXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<dgm:dataModel xmlns:dgm="http://schemas.openxmlformats.org/drawingml/2006/diagram"><dgm:ptLst/></dgm:dataModel>''';

  const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="WM9 Theme"><a:themeElements/></a:theme>''';
  const customXml = '<school><grade>5</grade><subject>Math</subject></school>';
  const legacyComments = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:comment w:id="41" w:author="Legacy Reviewer"><w:p><w:r><w:t>Preserve-only legacy comment part</w:t></w:r></w:p></w:comment>
</w:comments>''';

  const customProps = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
 <property fmtid="{D5CDD505-2E9C-101B-9397-08002B2CF9AE}" pid="2" name="SchoolCode"><vt:lpwstr>EDS-WM9</vt:lpwstr></property>
</Properties>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', rootRels))
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(
      ArchiveFile.string('word/_rels/document.xml.rels', documentRels),
    )
    ..addFile(ArchiveFile.string('word/charts/chart1.xml', chartXml))
    ..addFile(
      ArchiveFile.string('word/charts/_rels/chart1.xml.rels', chartRels),
    )
    ..addFile(ArchiveFile.string('word/diagrams/data1.xml', diagramXml))
    ..addFile(ArchiveFile.string('word/theme/theme1.xml', themeXml))
    ..addFile(ArchiveFile.string('word/comments.xml', legacyComments))
    ..addFile(ArchiveFile.string('customXml/item1.xml', customXml))
    ..addFile(ArchiveFile.string('docProps/custom.xml', customProps))
    ..addFile(
      ArchiveFile.bytes(
        'word/embeddings/oleObject1.bin',
        <int>[0xD0, 0xCF, 0x11, 0xE0, 0x57, 0x4D, 0x39],
      ),
    );

  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
