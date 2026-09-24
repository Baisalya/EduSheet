import 'dart:io';

import 'package:archive/archive.dart';

Future<File> writeWm78Fixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm78-');
  final file = File('${directory.path}${Platform.pathSeparator}wm78.docx');

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml">
 <w:background w:color="FFF8E8"/>
 <w:body>
  <w:p>
   <w:bookmarkStart w:id="7" w:name="Target_One"/>
   <w:r><w:t>Target paragraph</w:t></w:r>
   <w:bookmarkEnd w:id="7"/>
   <w:r><w:t xml:space="preserve"> </w:t></w:r>
   <w:hyperlink w:anchor="Target_One"><w:r><w:t>Jump back</w:t></w:r></w:hyperlink>
  </w:p>
  <w:p>
   <w:fldSimple w:instr=" DATE \\@ &quot;yyyy&quot; " w:fldLock="1"><w:r><w:t>2026</w:t></w:r></w:fldSimple>
   <w:r><w:t xml:space="preserve"> / page </w:t></w:r>
   <w:fldSimple w:instr=" PAGE "><w:r><w:t>1</w:t></w:r></w:fldSimple>
  </w:p>
  <w:p>
   <m:oMath><m:r><m:t>x+1</m:t></m:r></m:oMath>
   <w:r><w:t xml:space="preserve"> has note</w:t></w:r>
   <w:r><w:footnoteReference w:id="2"/></w:r>
   <w:r><w:t xml:space="preserve"> and endnote</w:t></w:r>
   <w:r><w:endnoteReference w:id="3"/></w:r>
  </w:p>
  <w:p>
   <w:commentRangeStart w:id="4"/>
   <w:r><w:t>Reviewed sentence</w:t></w:r>
   <w:commentRangeEnd w:id="4"/>
   <w:r><w:commentReference w:id="4"/></w:r>
  </w:p>
  <w:p>
   <w:r><w:pict>
    <v:shape style="position:absolute;margin-left:40pt;margin-top:80pt;width:300pt;height:80pt;rotation:315;z-index:-1" fillcolor="#D9D9D9" stroked="f">
     <v:textpath style="font-family:Calibri;font-size:1pt" string="DRAFT"/>
    </v:shape>
   </w:pict></w:r>
  </w:p>
  <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
 </w:body>
</w:document>''';

  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdFootnotes" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/>
 <Relationship Id="rIdEndnotes" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes" Target="endnotes.xml"/>
 <Relationship Id="rIdComments" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/>
</Relationships>''';

  const footnotesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:footnote w:id="2"><w:p><w:r><w:t>Footnote body from Word</w:t></w:r></w:p></w:footnote>
</w:footnotes>''';
  const endnotesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:endnote w:id="3"><w:p><w:r><w:t>Endnote body from Word</w:t></w:r></w:p></w:endnote>
</w:endnotes>''';
  const commentsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:comment w:id="4" w:author="Teacher" w:initials="TR" w:date="2026-09-23T10:00:00Z"><w:p><w:r><w:t>Check this wording.</w:t></w:r></w:p></w:comment>
</w:comments>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.string('word/footnotes.xml', footnotesXml))
    ..addFile(ArchiveFile.string('word/endnotes.xml', endnotesXml))
    ..addFile(ArchiveFile.string('word/comments.xml', commentsXml));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
