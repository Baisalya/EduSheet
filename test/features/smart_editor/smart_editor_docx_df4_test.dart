import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_docx_structure_editing.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DF4 Word -> Smart Editor edit -> Word preserves supported layout', () async {
    final fixture = await _writeRoundTripFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final service = const SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    expect(imported.nativeRoundTrip, isFalse);

    final layout = imported.document.pageLayout;
    expect(layout.wordPageWidthPoints, closeTo(612, 0.01));
    expect(layout.wordPageHeightPoints, closeTo(792, 0.01));
    expect(layout.wordMarginTopPoints, closeTo(45, 0.01));
    expect(layout.wordMarginRightPoints, closeTo(50, 0.01));
    expect(layout.wordMarginBottomPoints, closeTo(55, 0.01));
    expect(layout.wordMarginLeftPoints, closeTo(60, 0.01));
    expect(layout.wordHeaderDistancePoints, closeTo(20, 0.01));
    expect(layout.wordFooterDistancePoints, closeTo(25, 0.01));

    // Native SmartDocument persistence must not lose the exact Word geometry.
    final restored = SmartDocument.fromJson(imported.document.toJson());
    expect(restored.pageLayout.wordMarginLeftPoints, closeTo(60, 0.01));
    expect(restored.pageLayout.wordFooterDistancePoints, closeTo(25, 0.01));

    final table = _firstStructuredTable(imported.document.deltaJson);
    expect(table.widthPercent, closeTo(85, 0.01));
    expect(table.indentPoints, closeTo(48, 0.1));
    expect(table.cellSpacingPoints, closeTo(5.333, 0.1));
    expect(table.rows.single.heightPoints, closeTo(40, 0.1));
    expect(table.rows.single.heightRule, 'exact');
    expect(table.rows.single.cells.single.gridSpan, 2);
    expect(table.rows.single.cells.single.paddingLeftPoints, closeTo(16, 0.1));
    expect(table.rows.single.cells.single.verticalAlignment, 'center');

    final editedTable = SmartEditorDocxStructureEditing.updateCellText(
      table,
      0,
      0,
      'Edited inside EduSheet',
    );
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
    final documentXml = _entryText(archive, 'word/document.xml');
    final relationships = _entryText(
      archive,
      'word/_rels/document.xml.rels',
    );

    // Exact source page geometry, including header/footer distances.
    expect(documentXml, contains('<w:pgSz w:w="12240" w:h="15840"'));
    expect(documentXml, contains('w:top="900"'));
    expect(documentXml, contains('w:right="1000"'));
    expect(documentXml, contains('w:bottom="1100"'));
    expect(documentXml, contains('w:left="1200"'));
    expect(documentXml, contains('w:header="400"'));
    expect(documentXml, contains('w:footer="500"'));

    // Structured Word table geometry survives the editable Smart Editor pass.
    expect(documentXml, contains('<w:tblW w:w="4250" w:type="pct"/>'));
    expect(documentXml, contains('<w:tblInd w:w="720" w:type="dxa"/>'));
    expect(
      documentXml,
      contains('<w:tblCellSpacing w:w="80" w:type="dxa"/>'),
    );
    expect(
      documentXml,
      contains('<w:trHeight w:val="600" w:hRule="exact"/>'),
    );
    expect(documentXml, contains('<w:gridSpan w:val="2"/>'));
    expect(documentXml, contains('<w:left w:w="240" w:type="dxa"/>'));
    expect(documentXml, contains('<w:vAlign w:val="center"/>'));
    expect(
      RegExp(
        r'<w:spacing(?=[^>]*w:line="360")'
        r'(?=[^>]*w:lineRule="auto")[^>]*/>',
      ).hasMatch(documentXml),
      isTrue,
    );
    expect(documentXml, contains('w:after="120"'));
    expect(documentXml, contains('Edited inside EduSheet'));

    // Imported font sizes are converted from editor logical pixels back to
    // Word half-points instead of growing by 33% on every export.
    expect(documentXml, contains('<w:sz w:val="56"/>'));

    // Floating image placement and size round-trip as a real Word anchor.
    expect(documentXml, contains('<wp:anchor'));
    expect(documentXml, contains('<wp:positionH relativeFrom="margin">'));
    expect(documentXml, contains('<wp:posOffset>914400</wp:posOffset>'));
    expect(documentXml, contains('<wp:positionV relativeFrom="margin">'));
    expect(documentXml, contains('<wp:posOffset>457200</wp:posOffset>'));
    expect(
      documentXml,
      contains('<wp:extent cx="1371600" cy="914400"/>'),
    );
    expect(documentXml, contains('<wp:wrapSquare wrapText="bothSides"/>'));
    expect(relationships, contains('relationships/image'));

    // A Word text box is exported as an editable text box rather than a table.
    expect(documentXml, contains('<v:textbox'));
    expect(documentXml, contains('margin-left:54.000pt'));
    expect(documentXml, contains('margin-top:27.000pt'));
    expect(documentXml, contains('width:180.000pt'));
    expect(documentXml, contains('height:90.000pt'));
    expect(documentXml, contains('inset="6.000pt,3.000pt,9.000pt,4.000pt"'));
    expect(documentXml, contains('Floating teacher note'));

    // Verify the standard DOCX output itself can be parsed without relying on
    // EduSheet's native custom XML round-trip metadata.
    final exportedFile = File(
      '${fixture.parent.path}${Platform.pathSeparator}df4-exported.docx',
    );
    await exportedFile.writeAsBytes(exported.bytes, flush: true);
    final reparsed = await DocxConversionParser.parse(exportedFile);
    expect(reparsed.sections.single.page.widthPoints, closeTo(612, 0.01));
    expect(reparsed.sections.single.page.marginLeftPoints, closeTo(60, 0.01));
    expect(
      _findText(reparsed.sections.single.blocks),
      contains('Edited inside EduSheet'),
    );
    final image = _firstImage(reparsed.sections.single.blocks);
    expect(image.placement.floating, isTrue);
    expect(image.widthPoints, closeTo(108, 0.1));
    expect(image.heightPoints, closeTo(72, 0.1));
    expect(image.placement.horizontalOffsetPoints, closeTo(72, 0.1));
    expect(image.placement.verticalOffsetPoints, closeTo(36, 0.1));

    final textBox = _firstTextBox(reparsed.sections.single.blocks);
    expect(textBox, isNotNull);
    expect(textBox!.widthPoints, closeTo(180, 0.1));
    expect(textBox.heightPoints, closeTo(90, 0.1));
    expect(textBox.paddingLeftPoints, closeTo(6, 0.1));
    expect(textBox.paddingTopPoints, closeTo(3, 0.1));
    expect(textBox.paddingRightPoints, closeTo(9, 0.1));
    expect(textBox.paddingBottomPoints, closeTo(4, 0.1));
    expect(textBox.placement.floating, isTrue);
    expect(textBox.placement.horizontalOffsetPoints, closeTo(54, 0.1));
    expect(textBox.placement.verticalOffsetPoints, closeTo(27, 0.1));
  });
}

SmartEditorInteropTablePayload _firstStructuredTable(List<dynamic> delta) {
  for (final operation in delta.whereType<Map>()) {
    final insert = operation['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorInteropTableEmbedBuilder.keyName];
    if (value == null) continue;
    final table = SmartEditorInteropTablePayload.fromData(value);
    if (table.sourceKind == 'table') return table;
  }
  throw StateError('No structured Word table found.');
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
    final rawTable = insertMap[SmartEditorInteropTableEmbedBuilder.keyName];
    if (rawTable == null) return operation;
    final table = SmartEditorInteropTablePayload.fromData(rawTable);
    if (table.objectId != objectId) return operation;
    insertMap[SmartEditorInteropTableEmbedBuilder.keyName] = replacement.encode();
    operation['insert'] = insertMap;
    return operation;
  }).toList(growable: false);
}

String _findText(List<ConversionBlock> blocks) {
  final out = StringBuffer();
  void visit(List<ConversionBlock> items) {
    for (final block in items) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            out.write(inline.text);
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

ConversionImageRun _firstImage(List<ConversionBlock> blocks) {
  for (final block in blocks) {
    if (block is ConversionParagraph) {
      for (final inline in block.inlines) {
        if (inline is ConversionImageRun) return inline;
        if (inline is ConversionTextBoxRun) {
          try {
            return _firstImage(inline.blocks);
          } on StateError {
            // Continue searching the outer document.
          }
        }
      }
    } else if (block is ConversionTable) {
      for (final row in block.rows) {
        for (final cell in row.cells) {
          try {
            return _firstImage(cell.blocks);
          } on StateError {
            // Continue searching remaining cells.
          }
        }
      }
    }
  }
  throw StateError('No image found.');
}

ConversionTextBoxRun? _firstTextBox(List<ConversionBlock> blocks) {
  for (final block in blocks) {
    if (block is ConversionParagraph) {
      for (final inline in block.inlines) {
        if (inline is ConversionTextBoxRun) return inline;
      }
    } else if (block is ConversionTable) {
      for (final row in block.rows) {
        for (final cell in row.cells) {
          final nested = _firstTextBox(cell.blocks);
          if (nested != null) return nested;
        }
      }
    }
  }
  return null;
}

Future<File> _writeRoundTripFixture() async {
  final directory = await Directory.systemTemp.createTemp('edusheet-df4-');
  final file = File(
    '${directory.path}${Platform.pathSeparator}roundtrip-source.docx',
  );
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
 xmlns:o="urn:schemas-microsoft-com:office:office">
 <w:body>
  <w:p><w:r><w:rPr><w:sz w:val="56"/></w:rPr><w:t>ROUND TRIP TITLE</w:t></w:r></w:p>
  <w:p>
   <w:r><w:drawing>
    <wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="251658240" behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1">
     <wp:simplePos x="0" y="0"/>
     <wp:positionH relativeFrom="margin"><wp:posOffset>914400</wp:posOffset></wp:positionH>
     <wp:positionV relativeFrom="margin"><wp:posOffset>457200</wp:posOffset></wp:positionV>
     <wp:extent cx="1371600" cy="914400"/>
     <wp:wrapSquare wrapText="bothSides"/>
     <wp:docPr id="1" name="Round trip photo" descr="Round trip photo"/>
     <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="Round trip photo"/><pic:cNvPicPr/></pic:nvPicPr>
       <pic:blipFill><a:blip r:embed="rIdPhoto"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
       <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1371600" cy="914400"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
      </pic:pic>
     </a:graphicData></a:graphic>
    </wp:anchor>
   </w:drawing></w:r>
  </w:p>
  <w:tbl>
   <w:tblPr>
    <w:tblW w:w="4250" w:type="pct"/>
    <w:tblInd w:w="720" w:type="dxa"/>
    <w:tblCellSpacing w:w="80" w:type="dxa"/>
    <w:jc w:val="center"/>
   </w:tblPr>
   <w:tblGrid><w:gridCol w:w="2400"/><w:gridCol w:w="3600"/></w:tblGrid>
   <w:tr>
    <w:trPr><w:trHeight w:val="600" w:hRule="exact"/></w:trPr>
    <w:tc>
     <w:tcPr>
      <w:gridSpan w:val="2"/>
      <w:tcMar>
       <w:top w:w="120" w:type="dxa"/>
       <w:right w:w="180" w:type="dxa"/>
       <w:bottom w:w="100" w:type="dxa"/>
       <w:left w:w="240" w:type="dxa"/>
      </w:tcMar>
      <w:vAlign w:val="center"/>
     </w:tcPr>
     <w:p>
      <w:pPr><w:spacing w:line="360" w:lineRule="auto"/></w:pPr>
      <w:r><w:rPr><w:b/></w:rPr><w:t>Original table text</w:t></w:r>
     </w:p>
    </w:tc>
   </w:tr>
  </w:tbl>
  <w:p>
   <w:r><w:pict>
    <v:shape id="SourceTextBox" style="position:absolute;margin-left:54pt;margin-top:27pt;mso-position-horizontal-relative:margin;mso-position-vertical-relative:margin;width:180pt;height:90pt;z-index:251658240" o:allowoverlap="t">
     <v:stroke on="f"/><v:fill on="f"/>
     <v:textbox inset="6pt,3pt,9pt,4pt"><w:txbxContent>
      <w:p><w:r><w:t>Floating teacher note</w:t></w:r></w:p>
     </w:txbxContent></v:textbox>
    </v:shape>
   </w:pict></w:r>
  </w:p>
  <w:sectPr>
   <w:pgSz w:w="12240" w:h="15840"/>
   <w:pgMar w:top="900" w:right="1000" w:bottom="1100" w:left="1200" w:header="400" w:footer="500" w:gutter="0"/>
  </w:sectPr>
 </w:body>
</w:document>''';
  const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>
</Relationships>''';
  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.bytes('word/media/photo.png', png));
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(entry.content as List<int>);
}
