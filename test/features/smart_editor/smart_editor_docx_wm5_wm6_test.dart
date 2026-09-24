import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_break_embed_builder.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm5_wm6_fixture.dart';

void main() {
  test('WM5 Smart Editor preserves floating placement and shape payloads', () async {
    final fixture = await writeWm56Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final image = _firstImage(imported.document.deltaJson);
    final shape = _firstShape(imported.document.deltaJson);

    expect(image.placement.wrapStyle, 'wrapTight');
    expect(image.placement.wrapText, 'largest');
    expect(image.placement.distanceLeftPoints, closeTo(10.6667, 0.01));
    expect(image.placement.relativeHeight, 123456);
    expect(image.placement.layoutInCell, isFalse);
    expect(image.placement.locked, isTrue);

    expect(shape.kind, 'roundedRectangle');
    expect(shape.placement.floating, isTrue);
    expect(shape.placement.horizontalRelativeFrom, 'column');
    expect(shape.placement.behindText, isTrue);
    expect(shape.placement.relativeHeight, 42);
    expect(shape.placement.wrapStyle, 'wrapThrough');

    final exported = await service.export(imported.document);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final documentXml = _entryText(archive, 'word/document.xml');

    expect(documentXml, contains('<wp:wrapTight wrapText="largest"'));
    expect(documentXml, contains('distL="101600"'));
    expect(documentXml, contains('distR="114300"'));
    expect(documentXml, contains('relativeHeight="123456"'));
    expect(documentXml, contains('layoutInCell="0"'));
    expect(documentXml, contains('locked="1"'));
    expect(documentXml, contains('allowOverlap="0"'));
    expect(documentXml, contains('<v:roundrect'));
    expect(documentXml, contains('mso-position-horizontal-relative:column'));
    expect(documentXml, contains('<w10:wrap type="through" side="left"/>'));
    expect(documentXml, contains('z-index:-42'));
  });

  test('WM6 Smart Editor exports independent sectPr and header/footer stories', () async {
    final fixture = await writeWm56Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final document = imported.document;

    expect(document.wordSections, hasLength(2));
    expect(document.wordEvenAndOddHeaders, isTrue);
    expect(document.wordMirrorMargins, isTrue);
    expect(document.wordGutterAtTop, isTrue);
    expect(document.wordSections.first.breakType, 'oddPage');
    expect(document.wordSections.first.titlePage, isTrue);
    expect(document.wordSections.first.columns.count, 2);
    expect(document.wordSections.first.columns.equalWidth, isFalse);
    expect(_hasBreak(document.deltaJson, 'column'), isTrue);
    expect(document.wordSections.first.gutterPoints, closeTo(18, 0.001));
    expect(document.wordSections.first.pageNumberStart, 7);
    expect(document.wordSections.first.pageNumberFormat, 'upperRoman');
    expect(document.wordSections.first.firstHeader.text, contains('First header'));
    expect(document.wordSections.first.evenHeader.text, contains('Even header'));
    expect(document.wordSections.first.footer.text, contains('{PAGE}'));

    final exported = await service.export(document);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final names = archive.files.map((entry) => entry.name).toSet();
    final documentXml = _entryText(archive, 'word/document.xml');
    final settingsXml = _entryText(archive, 'word/settings.xml');
    final rels = _entryText(archive, 'word/_rels/document.xml.rels');
    final contentTypes = _entryText(archive, '[Content_Types].xml');

    expect(settingsXml, contains('<w:evenAndOddHeaders/>'));
    expect(settingsXml, contains('<w:mirrorMargins/>'));
    expect(settingsXml, contains('<w:gutterAtTop/>'));
    expect(documentXml, contains('<w:type w:val="oddPage"/>'));
    expect(documentXml, contains('<w:titlePg/>'));
    expect(documentXml, contains('<w:cols w:num="2"'));
    expect(documentXml, contains('w:equalWidth="0"'));
    expect(documentXml, contains('<w:br w:type="column"/>'));
    expect(documentXml, contains('<w:col w:w="4320" w:space="360"/>'));
    expect(documentXml, contains('<w:pgNumType w:start="7" w:fmt="upperRoman"/>'));
    expect(documentXml, contains('<w:pgBorders w:offsetFrom="page" w:display="firstPage" w:zOrder="back">'));
    expect(documentXml, contains('<w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/>'));
    expect(documentXml, contains('<w:headerReference w:type="first"'));
    expect(documentXml, contains('<w:headerReference w:type="even"'));
    expect(documentXml, contains('<w:footerReference w:type="default"'));
    expect(rels, contains('relationships/settings'));
    expect(rels, contains('relationships/header'));
    expect(rels, contains('relationships/footer'));
    expect(contentTypes, contains('wordprocessingml.settings+xml'));
    expect(names.any((name) => RegExp(r'^word/header\d+\.xml$').hasMatch(name)), isTrue);
    expect(names.any((name) => RegExp(r'^word/footer\d+\.xml$').hasMatch(name)), isTrue);

    final footerName = names.firstWhere(
      (name) => RegExp(r'^word/footer\d+\.xml$').hasMatch(name),
    );
    final footerXml = _entryText(archive, footerName);
    expect(footerXml, contains('<w:fldSimple w:instr=" PAGE ">'));
    expect(footerXml, contains('<w:fldSimple w:instr=" NUMPAGES ">'));
  });
}

SmartEditorInteropImagePayload _firstImage(List<dynamic> delta) {
  for (final raw in delta.whereType<Map>()) {
    final insert = raw['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorInteropImageEmbedBuilder.keyName];
    if (value != null) return SmartEditorInteropImagePayload.fromData(value);
  }
  throw StateError('No WM5 image payload found.');
}

SmartEditorInteropShapePayload _firstShape(List<dynamic> delta) {
  for (final raw in delta.whereType<Map>()) {
    final insert = raw['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorInteropShapeEmbedBuilder.keyName];
    if (value != null) return SmartEditorInteropShapePayload.fromData(value);
  }
  throw StateError('No WM5 shape payload found.');
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(entry.content as List<int>);
}

bool _hasBreak(List<dynamic> delta, String type) {
  for (final raw in delta.whereType<Map>()) {
    final insert = raw['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorBreakEmbedBuilder.keyName];
    if (value?.toString() == type) {
      return true;
    }
  }
  return false;
}
