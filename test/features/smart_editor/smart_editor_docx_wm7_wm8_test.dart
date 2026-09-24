import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_word_advanced_embed_builder.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm7_wm8_fixture.dart';

void main() {
  test('WM8 imports advanced Word content as structured inline objects', () async {
    final fixture = await writeWm78Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) await fixture.parent.delete(recursive: true);
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final payloads = _advancedPayloads(imported.document.deltaJson);
    final kinds = payloads.map((payload) => payload.kind).toSet();

    expect(imported.document.wordBackgroundColorHex, 'FFF8E8');
    expect(kinds, contains(SmartEditorWordAdvancedPayload.fieldKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.equationKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.footnoteKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.endnoteKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.bookmarkStartKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.bookmarkEndKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.commentStartKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.commentEndKind));
    expect(kinds, contains(SmartEditorWordAdvancedPayload.commentReferenceKind));

    final dateField = payloads.singleWhere(
      (payload) => payload.kind == SmartEditorWordAdvancedPayload.fieldKind &&
          payload.fieldName == 'DATE',
    );
    expect(dateField.resultText, '2026');
    expect(dateField.locked, isTrue);

    final equation = payloads.singleWhere(
      (payload) => payload.kind == SmartEditorWordAdvancedPayload.equationKind,
    );
    expect(equation.rawXml, contains('<m:oMath'));

    final comment = payloads.singleWhere(
      (payload) =>
          payload.kind == SmartEditorWordAdvancedPayload.commentReferenceKind,
    );
    expect(comment.contentText, 'Check this wording.');
    expect(comment.author, 'Teacher');

    final restored = SmartDocument.fromJson(imported.document.toJson());
    expect(restored.wordBackgroundColorHex, 'FFF8E8');
  });

  test('WM7+WM8 DOCX export reconstructs native Word advanced parts', () async {
    final fixture = await writeWm78Fixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) await fixture.parent.delete(recursive: true);
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final editedDelta = _editAdvancedObjects(imported.document.deltaJson);
    final exported = await service.export(
      imported.document.copyWith(deltaJson: editedDelta),
    );
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final names = archive.files.map((entry) => entry.name).toSet();
    final documentXml = _entryText(archive, 'word/document.xml');
    final rels = _entryText(archive, 'word/_rels/document.xml.rels');
    final contentTypes = _entryText(archive, '[Content_Types].xml');

    expect(documentXml, contains('<w:background w:color="FFF8E8"/>'));
    expect(documentXml, contains('<w:fldSimple w:instr=" DATE'));
    expect(documentXml, contains('>2030</w:t>'));
    expect(documentXml, contains('<w:fldSimple w:instr=" PAGE '));
    expect(documentXml, contains('<m:oMath'));
    expect(documentXml, contains('<w:footnoteReference w:id="'));
    expect(documentXml, contains('<w:endnoteReference w:id="'));
    expect(documentXml, contains('<w:commentRangeStart w:id="'));
    expect(documentXml, contains('<w:commentReference w:id="'));
    expect(documentXml, contains('<w:bookmarkStart'));
    expect(documentXml, contains('w:name="Target_One"'));
    expect(documentXml, contains('<w:hyperlink w:anchor="Target_One"'));
    expect(documentXml, contains('<v:textpath on="t" fitshape="t" string="DRAFT"/>'));
    expect(documentXml, contains('rotation:315.000'));

    expect(names, contains('word/footnotes.xml'));
    expect(names, contains('word/endnotes.xml'));
    expect(names, contains('word/comments.xml'));
    expect(_entryText(archive, 'word/footnotes.xml'), contains('Footnote body from Word'));
    expect(_entryText(archive, 'word/endnotes.xml'), contains('Endnote body from Word'));
    expect(_entryText(archive, 'word/comments.xml'), contains('Edited review note.'));
    expect(_entryText(archive, 'word/comments.xml'), contains('Senior Reviewer'));
    expect(rels, contains('relationships/footnotes'));
    expect(rels, contains('relationships/endnotes'));
    expect(rels, contains('relationships/comments'));
    expect(contentTypes, contains('wordprocessingml.footnotes+xml'));
    expect(contentTypes, contains('wordprocessingml.endnotes+xml'));
    expect(contentTypes, contains('wordprocessingml.comments+xml'));
  });
}


List<dynamic> _editAdvancedObjects(List<dynamic> delta) {
  return delta.map<dynamic>((operation) {
    if (operation is! Map) return operation;
    final mapped = Map<String, dynamic>.from(operation);
    final insert = mapped['insert'];
    if (insert is! Map) return mapped;
    final embed = Map<String, dynamic>.from(insert);
    final raw = embed[SmartEditorWordAdvancedEmbedBuilder.keyName];
    if (raw == null) return mapped;
    var payload = SmartEditorWordAdvancedPayload.fromData(raw);
    if (payload.kind == SmartEditorWordAdvancedPayload.fieldKind &&
        payload.fieldName == 'DATE') {
      payload = payload.copyWith(resultText: '2030', dirty: true);
    } else if (payload.kind ==
        SmartEditorWordAdvancedPayload.commentReferenceKind) {
      payload = payload.copyWith(
        contentText: 'Edited review note.',
        author: 'Senior Reviewer',
      );
    }
    embed[SmartEditorWordAdvancedEmbedBuilder.keyName] = payload.encode();
    mapped['insert'] = embed;
    return mapped;
  }).toList(growable: false);
}

List<SmartEditorWordAdvancedPayload> _advancedPayloads(List<dynamic> delta) {
  final result = <SmartEditorWordAdvancedPayload>[];
  for (final raw in delta.whereType<Map>()) {
    final insert = raw['insert'];
    if (insert is! Map) continue;
    final value = insert[SmartEditorWordAdvancedEmbedBuilder.keyName];
    if (value != null) {
      result.add(SmartEditorWordAdvancedPayload.fromData(value));
    }
  }
  return result;
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(entry.content as List<int>);
}
