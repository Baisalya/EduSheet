import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_docx_structure_editing.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WM4 Smart Editor preserves resolved Word table semantics through edit/export', () async {
    final fixture = await _writeTableFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final table = _firstTable(imported.document.deltaJson);

    expect(table.styleId, 'ResumeGrid');
    expect(table.layout, 'fixed');
    expect(table.shadingHex, 'F8FAFC');
    expect(table.borders['top'], isA<Map>());
    expect((table.borders['top'] as Map)['colorHex'], '4472C4');
    expect(table.rows.first.header, isTrue);
    expect(table.rows.first.cantSplit, isTrue);
    expect(table.rows.first.cells.first.shadingHex, 'D9EAF7');
    expect(table.rows[1].cells.first.noWrap, isTrue);
    expect(table.rows[1].cells.first.widthPercent, closeTo(40, 0.01));
    expect((table.rows[1].cells.first.borders['bottom'] as Map)['style'], 'dashed');

    final editedTable = SmartEditorDocxStructureEditing.updateCellText(
      table,
      1,
      0,
      'Edited MCA',
    );
    expect(editedTable.layout, 'fixed');
    expect(editedTable.borders, isNotEmpty);
    expect(editedTable.rows.first.cantSplit, isTrue);
    expect(editedTable.rows[1].cells.first.noWrap, isTrue);
    expect(editedTable.rows[1].cells.first.widthPercent, closeTo(40, 0.01));
    expect(editedTable.rows[1].cells.first.borders, isNotEmpty);

    final edited = imported.document.copyWith(
      deltaJson: _replaceTable(
        imported.document.deltaJson,
        table.objectId!,
        editedTable,
      ),
      updatedAt: DateTime.now().toUtc(),
    );
    final exported = await service.export(edited);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final xml = utf8.decode(
      archive.files
          .firstWhere((entry) => entry.name == 'word/document.xml')
          .content as List<int>,
    );

    expect(xml, contains('<w:tblStyle w:val="ResumeGrid"/>'));
    expect(xml, contains('<w:tblLayout w:type="fixed"/>'));
    expect(xml, contains('<w:shd w:val="clear" w:fill="F8FAFC"/>'));
    expect(
      RegExp(r'<w:top[^>]*w:val="single"[^>]*w:sz="8"[^>]*w:color="4472C4"').hasMatch(xml),
      isTrue,
    );
    expect(xml, contains('<w:cantSplit/>'));
    expect(xml, contains('<w:tcW w:w="2000" w:type="pct"/>'));
    expect(xml, contains('<w:noWrap/>'));
    expect(
      RegExp(r'<w:bottom[^>]*w:val="dashed"[^>]*w:sz="8"[^>]*w:color="C00000"').hasMatch(xml),
      isTrue,
    );
    expect(xml, contains('Edited MCA'));
  });
}

SmartEditorInteropTablePayload _firstTable(List<dynamic> delta) {
  for (final raw in delta.whereType<Map>()) {
    final operation = Map<String, dynamic>.from(raw);
    final insert = operation['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorInteropTableEmbedBuilder.keyName];
    if (value == null) continue;
    final table = SmartEditorInteropTablePayload.fromData(value);
    if (table.sourceKind == 'table') return table;
  }
  throw StateError('No WM4 table payload found.');
}

List<dynamic> _replaceTable(
  List<dynamic> delta,
  String objectId,
  SmartEditorInteropTablePayload replacement,
) {
  return delta.map<dynamic>((raw) {
    if (raw is! Map) return raw;
    final operation = Map<String, dynamic>.from(raw);
    final insert = operation['insert'];
    if (insert is! Map) return operation;
    final insertMap = Map<String, dynamic>.from(insert);
    final value = insertMap[SmartEditorInteropTableEmbedBuilder.keyName];
    if (value == null) return operation;
    final table = SmartEditorInteropTablePayload.fromData(value);
    if (table.objectId != objectId) return operation;
    insertMap[SmartEditorInteropTableEmbedBuilder.keyName] = replacement.encode();
    operation['insert'] = insertMap;
    return operation;
  }).toList(growable: false);
}

Future<File> _writeTableFixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-wm4-smart-');
  final file = File('${directory.path}${Platform.pathSeparator}wm4-smart.docx');

  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:tbl>
   <w:tblPr>
    <w:tblStyle w:val="ResumeGrid"/>
    <w:tblW w:type="pct" w:w="5000"/>
    <w:tblLayout w:type="fixed"/>
    <w:shd w:val="clear" w:fill="F8FAFC"/>
    <w:tblLook w:firstRow="1" w:noHBand="1" w:noVBand="1"/>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="3600"/><w:gridCol w:w="5400"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>
    <w:tc><w:p><w:r><w:t>COURSE</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>INSTITUTION</w:t></w:r></w:p></w:tc>
   </w:tr>
   <w:tr>
    <w:tc>
     <w:tcPr>
      <w:tcW w:type="pct" w:w="2000"/><w:noWrap/>
      <w:tcBorders><w:bottom w:val="dashed" w:sz="8" w:color="C00000"/></w:tcBorders>
     </w:tcPr>
     <w:p><w:r><w:t>MCA</w:t></w:r></w:p>
    </w:tc>
    <w:tc><w:p><w:r><w:t>Centurion University</w:t></w:r></w:p></w:tc>
   </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>
 </w:body>
</w:document>''';

  const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
 <w:style w:type="table" w:styleId="ResumeGrid">
  <w:tblPr><w:tblBorders>
   <w:top w:val="single" w:sz="8" w:color="4472C4"/>
   <w:left w:val="single" w:sz="8" w:color="4472C4"/>
   <w:bottom w:val="single" w:sz="8" w:color="4472C4"/>
   <w:right w:val="single" w:sz="8" w:color="4472C4"/>
   <w:insideH w:val="single" w:sz="4" w:color="9EADBA"/>
   <w:insideV w:val="single" w:sz="4" w:color="9EADBA"/>
  </w:tblBorders></w:tblPr>
  <w:tblStylePr w:type="firstRow"><w:tcPr><w:shd w:fill="D9EAF7"/></w:tcPr><w:rPr><w:b/></w:rPr></w:tblStylePr>
 </w:style>
</w:styles>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/styles.xml', stylesXml));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
