import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_word_advanced_embed_builder.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm9_preservation_fixture.dart';

void main() {
  test('WM9 canonical model keeps unsupported OOXML as preserve-only capsules',
      () async {
    final fixture = await writeWm9PreservationFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final document = await DocxConversionParser.parse(fixture);
    final blocks = document.sections.first.blocks;
    final opaqueBlocks = blocks.whereType<ConversionOpaqueOoxmlBlock>().toList();
    expect(
      opaqueBlocks.map((block) => block.featureKind),
      containsAll(<String>[
        'contentControl',
        'customXml',
        'alternateContent',
        'tableWithUnsupportedOoxml',
      ]),
    );

    final opaqueRuns = blocks
        .whereType<ConversionParagraph>()
        .expand((paragraph) => paragraph.inlines)
        .whereType<ConversionOpaqueOoxmlRun>()
        .toList(growable: false);
    expect(opaqueRuns.map((run) => run.featureKind), contains('chart'));
    expect(opaqueRuns.map((run) => run.featureKind), contains('embeddedObject'));
    expect(opaqueRuns.map((run) => run.featureKind), contains('smartArt'));
    final chartParagraph = blocks
        .whereType<ConversionParagraph>()
        .singleWhere((paragraph) => paragraph.inlines.any(
              (inline) =>
                  inline is ConversionOpaqueOoxmlRun &&
                  inline.featureKind == 'chart',
            ));
    expect(chartParagraph.inlines.first, isA<ConversionTextRun>());
    expect(
      (chartParagraph.inlines.first as ConversionTextRun).text,
      'Before chart ',
    );
    expect(chartParagraph.inlines[1], isA<ConversionOpaqueOoxmlRun>());
    expect(chartParagraph.inlines[2], isA<ConversionTextRun>());
    expect(
      (chartParagraph.inlines[2] as ConversionTextRun).text,
      ' after chart',
    );
    expect(
      opaqueRuns.expand((run) => run.relationshipIds),
      containsAll(<String>['rIdChart1', 'rIdOle1', 'rIdDiagram1']),
    );

  });

  test('WM9 Word to EduSheet to Word preserves unknown package dependencies',
      () async {
    final fixture = await writeWm9PreservationFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    const service = SmartEditorDocxService();
    final imported = await service.importFile(fixture);
    final preservation = imported.document.wordPreservation;
    expect(
      preservation.documentRelationships.any(
        (relationship) =>
            relationship.id == 'rIdSettings' &&
            relationship.type.endsWith('/customXml') &&
            relationship.target == '../customXml/item1.xml',
      ),
      isTrue,
      reason:
          'WM9 must not mistake arbitrary Word customXml relationships for EduSheet native metadata.',
    );
    final paths = preservation.packageParts.map((part) => part.path).toSet();
    expect(paths, contains('word/charts/chart1.xml'));
    expect(paths, contains('word/charts/_rels/chart1.xml.rels'));
    expect(paths, contains('word/embeddings/oleObject1.bin'));
    expect(paths, contains('word/diagrams/data1.xml'));
    expect(paths, contains('word/theme/theme1.xml'));
    expect(paths, contains('word/comments.xml'));
    expect(paths, contains('customXml/item1.xml'));
    expect(paths, contains('docProps/custom.xml'));
    expect(preservation.documentNamespaces['cx'], isNotNull);

    final opaquePayloads = _opaquePayloads(imported.document.deltaJson);
    expect(
      opaquePayloads.map((payload) => payload.featureKind),
      containsAll(<String>[
        'contentControl',
        'chart',
        'embeddedObject',
        'smartArt',
        'customXml',
        'alternateContent',
        'tableWithUnsupportedOoxml',
      ]),
    );

    final original = ZipDecoder().decodeBytes(await fixture.readAsBytes());
    final originalChart = _entryBytes(original, 'word/charts/chart1.xml');
    final originalOle = _entryBytes(original, 'word/embeddings/oleObject1.bin');
    final originalDiagram = _entryBytes(original, 'word/diagrams/data1.xml');
    final originalCustom = _entryBytes(original, 'customXml/item1.xml');

    final edited = imported.document.copyWith(
      deltaJson: <dynamic>[
        <String, dynamic>{'insert': 'Edited before preserved objects\n'},
        ...imported.document.deltaJson,
      ],
    );
    final exported = await service.export(edited);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final names = archive.files.map((entry) => entry.name).toSet();
    final documentXml = _entryText(archive, 'word/document.xml');
    final rels = _entryText(archive, 'word/_rels/document.xml.rels');
    final rootRels = _entryText(archive, '_rels/.rels');
    final contentTypes = _entryText(archive, '[Content_Types].xml');

    expect(names, contains('word/charts/chart1.xml'));
    expect(names, contains('word/charts/_rels/chart1.xml.rels'));
    expect(names, contains('word/embeddings/oleObject1.bin'));
    expect(names, contains('word/diagrams/data1.xml'));
    expect(names, contains('word/theme/theme1.xml'));
    expect(names, contains('word/comments.xml'));
    expect(names, contains('customXml/item1.xml'));
    expect(names, contains('docProps/custom.xml'));
    expect(documentXml, contains('Edited before preserved objects'));
    expect(documentXml, contains('<w:sdt'));
    expect(documentXml, contains('<c:chart r:id="rIdChart1"'));
    expect(documentXml, contains('r:id="rIdOle1"'));
    expect(documentXml, contains('r:dm="rIdDiagram1"'));
    expect(documentXml, contains('<mc:AlternateContent'));
    expect(documentXml, contains('Nested protected cell'));
    expect(documentXml, contains('xmlns:cx='));
    expect(rels, contains('Id="rIdChart1"'));
    expect(rels, contains('Id="rIdOle1"'));
    expect(rels, contains('Id="rIdDiagram1"'));
    expect(
      rels,
      contains(
        'Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/customXml" Target="../customXml/item1.xml"',
      ),
    );
    expect(
      rels,
      contains(
        'Id="rIdSettings_2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"',
      ),
    );
    expect(rels, contains('Id="rIdTheme1"'));
    expect(rels, contains('Id="rIdCommentsLegacy"'));
    expect(rootRels, contains('Id="rId1"'));
    expect(rootRels, contains('Id="rId1_2"'));
    expect(contentTypes, contains('drawingml.chart+xml'));
    expect(contentTypes, contains('officedocument.oleObject'));
    expect(contentTypes, contains('drawingml.diagramData+xml'));
    expect(contentTypes, contains('custom-properties+xml'));
    expect(contentTypes, contains('wordprocessingml.comments+xml'));
    expect(
      _entryText(archive, 'word/comments.xml'),
      contains('Preserve-only legacy comment part'),
    );

    expect(
      sha256.convert(_entryBytes(archive, 'word/charts/chart1.xml')).toString(),
      sha256.convert(originalChart).toString(),
    );
    expect(
      sha256.convert(_entryBytes(archive, 'word/embeddings/oleObject1.bin')).toString(),
      sha256.convert(originalOle).toString(),
    );
    expect(
      sha256.convert(_entryBytes(archive, 'word/diagrams/data1.xml')).toString(),
      sha256.convert(originalDiagram).toString(),
    );
    expect(
      sha256.convert(_entryBytes(archive, 'customXml/item1.xml')).toString(),
      sha256.convert(originalCustom).toString(),
    );

    final exportedFile = File(
      '${fixture.parent.path}${Platform.pathSeparator}wm9-exported.docx',
    );
    await exportedFile.writeAsBytes(exported.bytes, flush: true);
    final nativeMetadata = _entryText(
      archive,
      SmartEditorDocxService.roundTripPartName,
    );
    expect(nativeMetadata, isNot(contains('word/charts/chart1.xml')));

    final reparsed = await DocxConversionParser.parse(exportedFile);
    expect(
      reparsed.sections
          .expand((section) => section.blocks)
          .whereType<ConversionOpaqueOoxmlBlock>(),
      isNotEmpty,
    );

    final nativeReimport = await service.importFile(exportedFile);
    expect(nativeReimport.nativeRoundTrip, isTrue);
    expect(
      nativeReimport.document.wordPreservation.packageParts
          .map((part) => part.path),
      contains('word/charts/chart1.xml'),
    );
  });
}

List<SmartEditorWordAdvancedPayload> _opaquePayloads(List<dynamic> delta) {
  final result = <SmartEditorWordAdvancedPayload>[];
  for (final operation in delta.whereType<Map>()) {
    final insert = operation['insert'];
    if (insert is! Map) continue;
    final raw = insert[SmartEditorWordAdvancedEmbedBuilder.keyName];
    if (raw == null) continue;
    final payload = SmartEditorWordAdvancedPayload.fromData(raw);
    if (payload.kind == SmartEditorWordAdvancedPayload.opaqueOoxmlKind) {
      result.add(payload);
    }
  }
  return result;
}

List<int> _entryBytes(Archive archive, String name) {
  final entry = archive.files.firstWhere((candidate) => candidate.name == name);
  return List<int>.from(entry.content as List<int>);
}

String _entryText(Archive archive, String name) =>
    utf8.decode(_entryBytes(archive, name));
