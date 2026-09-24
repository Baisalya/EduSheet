import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_docx_structure_editing.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DF3 structured payload round-trip keeps Word geometry metadata', () {
    final payload = SmartEditorInteropTablePayload(
      objectId: 'docx-table-7',
      showBorders: false,
      widthPercent: 85,
      indentPoints: 48,
      cellSpacingPoints: 5.333,
      alignment: 'center',
      gridColumnWidths: const <double>[120, 260],
      rows: const <SmartEditorInteropTableRow>[
        SmartEditorInteropTableRow(
          heightPoints: 40,
          heightRule: 'exact',
          cells: <SmartEditorInteropTableCell>[
            SmartEditorInteropTableCell(
              text: 'Profile',
              gridSpan: 2,
              paddingTopPoints: 8,
              paddingRightPoints: 8,
              paddingBottomPoints: 8,
              paddingLeftPoints: 16,
              verticalAlignment: 'center',
              verticalMerge: 'restart',
              blocks: <SmartEditorInteropCellBlock>[
                SmartEditorInteropCellBlock.paragraph(
                  runs: <SmartEditorInteropTextRun>[
                    SmartEditorInteropTextRun(text: 'Profile', bold: true),
                  ],
                  lineSpacingMultiple: 1.5,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final decoded = SmartEditorInteropTablePayload.fromData(payload.encode());
    expect(decoded.objectId, 'docx-table-7');
    expect(decoded.widthPercent, 85);
    expect(decoded.indentPoints, 48);
    expect(decoded.cellSpacingPoints, closeTo(5.333, 0.001));
    expect(decoded.rows.single.heightPoints, 40);
    expect(decoded.rows.single.heightRule, 'exact');
    expect(decoded.rows.single.cells.single.gridSpan, 2);
    expect(decoded.rows.single.cells.single.paddingLeftPoints, 16);
    expect(decoded.rows.single.cells.single.verticalAlignment, 'center');
    expect(decoded.rows.single.cells.single.verticalMerge, 'restart');
    expect(
      decoded.rows.single.cells.single.blocks.single.lineSpacingMultiple,
      1.5,
    );
  });

  test('DF3 cell text editing preserves images and nested tables', () {
    final nested = SmartEditorInteropTablePayload(
      rows: const <SmartEditorInteropTableRow>[
        SmartEditorInteropTableRow(
          cells: <SmartEditorInteropTableCell>[
            SmartEditorInteropTableCell(text: 'nested'),
          ],
        ),
      ],
    );
    final table = SmartEditorInteropTablePayload(
      objectId: 'docx-table-edit',
      rows: <SmartEditorInteropTableRow>[
        SmartEditorInteropTableRow(
          cells: <SmartEditorInteropTableCell>[
            SmartEditorInteropTableCell(
              text: 'Old text',
              blocks: <SmartEditorInteropCellBlock>[
                const SmartEditorInteropCellBlock.paragraph(
                  runs: <SmartEditorInteropTextRun>[
                    SmartEditorInteropTextRun(
                      text: 'Old text',
                      bold: true,
                      fontSizePoints: 18,
                    ),
                  ],
                  alignment: 'center',
                ),
                SmartEditorInteropCellBlock.image(
                  SmartEditorInteropImagePayload(
                    bytes: Uint8List.fromList(<int>[1, 2, 3]),
                    widthPoints: 80,
                    heightPoints: 60,
                  ),
                ),
                SmartEditorInteropCellBlock.table(nested),
              ],
            ),
          ],
        ),
      ],
    );

    final updated = SmartEditorDocxStructureEditing.updateCellText(
      table,
      0,
      0,
      'New teacher notes',
    );
    final cell = updated.rows.single.cells.single;
    expect(cell.text, 'New teacher notes');
    expect(cell.blocks.where((block) => block.kind == 'image'), hasLength(1));
    expect(cell.blocks.where((block) => block.kind == 'table'), hasLength(1));
    final paragraph = cell.blocks.firstWhere((block) => block.kind == 'paragraph');
    expect(paragraph.runs.single.text, 'New teacher notes');
    expect(paragraph.runs.single.bold, isTrue);
    expect(paragraph.runs.single.fontSizePoints, 18);
    expect(paragraph.alignment, 'center');
  });

  test('DF3 locks destructive column changes for merged Word tables', () {
    final table = SmartEditorInteropTablePayload(
      rows: const <SmartEditorInteropTableRow>[
        SmartEditorInteropTableRow(
          cells: <SmartEditorInteropTableCell>[
            SmartEditorInteropTableCell(text: 'Merged', gridSpan: 2),
          ],
        ),
      ],
    );

    expect(SmartEditorDocxStructureEditing.hasMergedStructure(table), isTrue);
    expect(
      SmartEditorDocxStructureEditing.addColumn(table).rows.single.cells,
      hasLength(1),
    );
    expect(
      SmartEditorDocxStructureEditing.removeColumn(table, 0).rows.single.cells,
      hasLength(1),
    );
  });

  test('DF3 DOCX import creates structured editable table metadata', () async {
    final fixture = await _writeStructuredTableFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final imported = await const SmartEditorDocxService().importFile(fixture);
    expect(imported.nativeRoundTrip, isFalse);
    final table = _firstTable(imported.document.deltaJson);

    expect(table.objectId, startsWith('docx-table-'));
    expect(table.widthPercent, closeTo(85, 0.01));
    expect(table.indentPoints, closeTo(48, 0.1));
    expect(table.cellSpacingPoints, closeTo(5.333, 0.1));
    expect(table.alignment, 'center');
    expect(table.rows.single.heightPoints, closeTo(40, 0.1));
    expect(table.rows.single.heightRule, 'exact');

    final cell = table.rows.single.cells.single;
    expect(cell.gridSpan, 2);
    expect(cell.paddingTopPoints, closeTo(8, 0.1));
    expect(cell.paddingLeftPoints, closeTo(16, 0.1));
    expect(cell.verticalAlignment, 'center');
    final paragraph = cell.blocks.firstWhere((block) => block.kind == 'paragraph');
    expect(paragraph.lineSpacingMultiple, closeTo(1.5, 0.01));
    expect(cell.text, contains('Editable imported table'));
  });
}

SmartEditorInteropTablePayload _firstTable(List<dynamic> delta) {
  for (final operation in delta.whereType<Map>()) {
    final insert = operation['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorInteropTableEmbedBuilder.keyName];
    if (value != null) return SmartEditorInteropTablePayload.fromData(value);
  }
  throw StateError('No Smart Editor DOCX table embed found.');
}

Future<File> _writeStructuredTableFixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-df3-');
  final file = File('${directory.path}${Platform.pathSeparator}structured.docx');
  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:tbl>
   <w:tblPr>
    <w:tblW w:w="4250" w:type="pct"/>
    <w:tblInd w:w="720" w:type="dxa"/>
    <w:tblCellSpacing w:w="80" w:type="dxa"/>
    <w:tblCellMar>
     <w:top w:w="120" w:type="dxa"/>
     <w:right w:w="120" w:type="dxa"/>
     <w:bottom w:w="120" w:type="dxa"/>
     <w:left w:w="120" w:type="dxa"/>
    </w:tblCellMar>
    <w:jc w:val="center"/>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="2400"/><w:gridCol w:w="3600"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:trHeight w:val="600" w:hRule="exact"/></w:trPr>
    <w:tc>
     <w:tcPr>
      <w:gridSpan w:val="2"/>
      <w:tcMar><w:left w:w="240" w:type="dxa"/></w:tcMar>
      <w:vAlign w:val="center"/>
     </w:tcPr>
     <w:p>
      <w:pPr><w:spacing w:line="360" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:b/></w:rPr><w:t>Editable imported table</w:t></w:r>
     </w:p>
    </w:tc>
   </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
 </w:body>
</w:document>''';
  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>''';
  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}
