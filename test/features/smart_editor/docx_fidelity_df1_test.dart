import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_document_viewer.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_fidelity_document_view.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DF1 keeps borderless resume columns, styles and in-cell photo', () async {
    final fixture = await _writeResumeFixture();
    addTearDown(() async {
      if (await fixture.parent.exists()) {
        await fixture.parent.delete(recursive: true);
      }
    });

    final parsed = await DocxConversionParser.parse(fixture);
    expect(WordFidelityDocumentView.shouldUseFor(parsed), isTrue);
    final table = parsed.sections.single.blocks.first;
    expect(table.runtimeType.toString(), 'ConversionTable');

    final imported = await const SmartEditorDocxService().importFile(fixture);
    expect(imported.nativeRoundTrip, isFalse);
    final tablePayload = _firstTable(imported.document.deltaJson);

    expect(tablePayload.gridColumnWidths, hasLength(2));
    expect(tablePayload.gridColumnWidths[0], closeTo(160, 0.2));
    expect(tablePayload.gridColumnWidths[1], closeTo(333.333, 0.3));
    expect(tablePayload.rows.single.cells, hasLength(2));

    final left = tablePayload.rows.single.cells.first;
    final right = tablePayload.rows.single.cells.last;
    expect(left.text, isNot(contains('[image]')));
    expect(left.blocks.any((block) => block.kind == 'image'), isTrue);
    final image = left.blocks.firstWhere((block) => block.kind == 'image').image;
    expect(image, isNotNull);
    expect(image!.bytes, isNotEmpty);
    expect(image.widthPoints, closeTo(144, 0.3));
    expect(image.heightPoints, closeTo(192, 0.3));

    final headingRun = right.blocks
        .where((block) => block.kind == 'paragraph')
        .expand((block) => block.runs)
        .firstWhere((run) => run.text.contains('BAISALYA ROUL'));
    expect(headingRun.fontSizePoints, closeTo(37.333, 0.3));
    expect(right.text, contains('PROFESSIONAL WORK EXPERIENCE'));

    // A standard DOCX re-export must keep the rich table image as a real Word
    // media relationship, rather than silently dropping it.
    final exported = await const SmartEditorDocxService().export(imported.document);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final documentXml = _entryText(archive, 'word/document.xml');
    final relationships = _entryText(archive, 'word/_rels/document.xml.rels');
    expect(documentXml, contains('<w:tblGrid>'));
    expect(documentXml, contains('BAISALYA ROUL'));
    expect(documentXml, contains('<w:drawing>'));
    expect(relationships, contains('relationships/image'));
    expect(
      archive.files.any((entry) => entry.name.startsWith('word/media/table_image_')),
      isTrue,
    );
  });


  testWidgets('DF1 Word viewer auto-selects fidelity path for complex resume DOCX', (
    tester,
  ) async {
    final fixture = (await tester.runAsync<File>(
      () => _writeResumeFixture(includePhoto: false),
    ))!;
    addTearDown(
      () => tester.runAsync(() async {
        if (await fixture.parent.exists()) {
          await fixture.parent.delete(recursive: true);
        }
      }),
    );
    final parsed = (await tester.runAsync<ConversionDocument>(
      () => DocxConversionParser.parse(fixture),
    ))!;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final stat = (await tester.runAsync<FileStat>(
      () => fixture.stat(),
    ))!;
    final document = DocumentFile(
      name: 'resume.docx',
      path: fixture.path,
      extension: '.docx',
      size: stat.size,
      lastModified: stat.modified,
      type: DocumentType.word,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordDocumentViewer(
            document: document,
            fidelityLoader: (_) async => parsed,
          ),
        ),
      ),
    );
    await tester.pump();

    // The production selection path is exercised with a pre-parsed document,
    // so no real filesystem Future starts inside the widget test fake-async
    // zone. Pump only the injected Future + setState transition.
    for (var i = 0;
        i < 8 && find.byType(WordFidelityDocumentView).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.byType(WordFidelityDocumentView), findsOneWidget);
    expect(find.byType(DocxView), findsNothing);
    expect(find.textContaining('BAISALYA ROUL', findRichText: true), findsWidgets);
  });

  testWidgets('DF1 fidelity renderer shows both resume columns', (
    tester,
  ) async {
    final fixture = (await tester.runAsync<File>(
      () => _writeResumeFixture(includePhoto: false),
    ))!;
    addTearDown(
      () => tester.runAsync(() async {
        if (await fixture.parent.exists()) {
          await fixture.parent.delete(recursive: true);
        }
      }),
    );
    final parsed = (await tester.runAsync<ConversionDocument>(
      () => DocxConversionParser.parse(fixture),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 900,
            child: WordFidelityDocumentView(
              document: parsed,
              pageWidth: 794,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-fidelity-page')), findsOneWidget);
    expect(find.textContaining('PROFILE', findRichText: true), findsWidgets);
    expect(find.textContaining('BAISALYA ROUL', findRichText: true), findsWidgets);
    expect(find.textContaining('PROFESSIONAL WORK EXPERIENCE', findRichText: true), findsWidgets);
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

Future<File> _writeResumeFixture({bool includePhoto = true}) async {
  final directory = await Directory.systemTemp.createTemp('edusheet-df1-resume-');
  final file = File('${directory.path}${Platform.pathSeparator}resume.docx');
  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGNkaPj/n4GBgYGJAQoAJRkCgp9o0gYAAAAASUVORK5CYII=',
    ),
  );
  const cx = 1371600; // 108 pt
  const cy = 1828800; // 144 pt
  final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
 <w:body>
  <w:tbl>
   <w:tblPr><w:tblW w:w="7400" w:type="dxa"/></w:tblPr>
   <w:tblGrid><w:gridCol w:w="2400"/><w:gridCol w:w="5000"/></w:tblGrid>
   <w:tr>
    <w:tc>
     <w:tcPr><w:tcW w:w="2400" w:type="dxa"/></w:tcPr>
     ${includePhoto ? '<w:p><w:r><w:drawing><wp:inline><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="1" name="Resume photo" descr="Resume photo"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:blipFill><a:blip r:embed="rIdPhoto"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>' : ''}
     <w:p><w:r><w:rPr><w:b/><w:color w:val="4F81BD"/></w:rPr><w:t>PROFILE</w:t></w:r></w:p>
     <w:p><w:r><w:t>Seeking a position that will utilize my talent.</w:t></w:r></w:p>
    </w:tc>
    <w:tc>
     <w:tcPr><w:tcW w:w="5000" w:type="dxa"/></w:tcPr>
     <w:p><w:r><w:rPr><w:sz w:val="56"/></w:rPr><w:t>BAISALYA ROUL</w:t></w:r></w:p>
     <w:p><w:r><w:rPr><w:b/></w:rPr><w:t>PROFESSIONAL WORK EXPERIENCE</w:t></w:r></w:p>
     <w:p><w:r><w:t>1. Sabthik App (as Intern)</w:t></w:r></w:p>
    </w:tc>
   </w:tr>
  </w:tbl>
  <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr>
 </w:body>
</w:document>''';
  final rels = includePhoto
      ? '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rIdPhoto" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/photo.png"/>
</Relationships>'''
      : '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels));
  if (includePhoto) {
    archive.addFile(ArchiveFile.bytes('word/media/photo.png', png));
  }
  await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
  return file;
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(entry.content as List<int>);
}
