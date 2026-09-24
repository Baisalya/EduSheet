import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WM1 Smart Editor DOCX export preserves Word crop and picture transforms',
      () async {
    final png = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGNkaPj/n4GBgYGJAQoAJRkCgp9o0gYAAAAASUVORK5CYII=',
      ),
    );
    final payload = SmartEditorInteropImagePayload(
      bytes: png,
      objectId: 'wm1-image',
      widthPoints: 240,
      heightPoints: 160,
      cropLeft: 0.25,
      cropTop: 0.10,
      cropRight: 0.05,
      cropBottom: 0.02,
      rotationDegrees: 90,
      flipHorizontal: true,
    );
    final document = SmartDocument.blank(title: 'WM1 crop round-trip').copyWith(
      deltaJson: <dynamic>[
        <String, dynamic>{
          'insert': <String, dynamic>{
            SmartEditorInteropImageEmbedBuilder.keyName: payload.encode(),
          },
        },
        const <String, dynamic>{'insert': '\n'},
      ],
    );

    final exported = await const SmartEditorDocxService().export(document);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final documentEntry = archive.files
        .where((entry) => entry.name == 'word/document.xml')
        .single;
    final documentXml = utf8.decode(documentEntry.content);

    expect(documentXml, contains('<a:srcRect'));
    expect(documentXml, contains('l="25000"'));
    expect(documentXml, contains('t="10000"'));
    expect(documentXml, contains('r="5000"'));
    expect(documentXml, contains('b="2000"'));
    expect(documentXml, contains('rot="5400000"'));
    expect(documentXml, contains('flipH="1"'));

    final directory = await Directory.systemTemp.createTemp('edusheet-wm1-export-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}wm1.docx');
    await file.writeAsBytes(exported.bytes, flush: true);
    final reparsed = await DocxConversionParser.parse(file);
    final image = _firstImage(reparsed.sections.single.blocks);

    expect(image.crop.left, closeTo(0.25, 0.0001));
    expect(image.crop.top, closeTo(0.10, 0.0001));
    expect(image.crop.right, closeTo(0.05, 0.0001));
    expect(image.crop.bottom, closeTo(0.02, 0.0001));
    expect(image.rotationDegrees, closeTo(90, 0.001));
    expect(image.flipHorizontal, isTrue);
  });
}

ConversionImageRun _firstImage(List<ConversionBlock> blocks) {
  for (final block in blocks) {
    if (block is ConversionParagraph) {
      for (final inline in block.inlines) {
        if (inline is ConversionImageRun) return inline;
      }
    }
  }
  throw StateError('No image found');
}
