import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_file_opener.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Final Word production certification opens, edits, exports and reopens real Microsoft Word corpus on Windows/Android contracts',
      () async {
    final sources = await _findMicrosoftWordCorpus();
    expect(
      sources,
      isNotEmpty,
      reason: 'Final release certification requires a checked-in real Word corpus.',
    );

    const service = SmartEditorDocxService();
    for (final source in sources) {
      final sourceBytes = await source.readAsBytes();
      final sourceArchive = ZipDecoder().decodeBytes(sourceBytes);
      expect(
        _entryText(sourceArchive, 'docProps/app.xml'),
        contains('Microsoft Word'),
        reason: source.path,
      );

      final windowsOpen = await SmartEditorDocxFileOpener(
        pickFile: () async => SmartEditorPickedDocx(
          name: path.basename(source.path),
          path: source.path,
        ),
      ).pickAndImport();
      expect(windowsOpen, isNotNull, reason: 'Windows open failed: ${source.path}');

      final androidOpen = await SmartEditorDocxFileOpener(
        pickFile: () async => SmartEditorPickedDocx(
          name: path.basename(source.path),
          bytes: Uint8List.fromList(sourceBytes),
        ),
      ).pickAndImport();
      expect(androidOpen, isNotNull, reason: 'Android open failed: ${source.path}');
      expect(androidOpen!.document.title, windowsOpen!.document.title);
      expect(androidOpen.document.deltaJson, windowsOpen.document.deltaJson);
      expect(
        androidOpen.document.wordPreservation.toJson(),
        windowsOpen.document.wordPreservation.toJson(),
      );

      final originalParsed = await DocxConversionParser.parse(source);
      final originalText = _conversionPlainText(originalParsed).trim();
      expect(originalText, isNotEmpty, reason: source.path);

      const editMarker = 'EDUSHEET FINAL WORD RELEASE CERTIFICATION EDIT';
      final edited = windowsOpen.document.copyWith(
        title: '${windowsOpen.document.title} - Certified Edit',
        deltaJson: _appendPlainText(windowsOpen.document.deltaJson, editMarker),
        updatedAt: DateTime.utc(2026, 9, 24),
      );
      final exported = await service.export(edited);
      expect(exported.bytes.length, greaterThan(1000), reason: source.path);

      final exportedArchive = ZipDecoder().decodeBytes(exported.bytes);
      _expectHealthyDocxPackage(exportedArchive, source.path);
      expect(
        _entryText(exportedArchive, 'word/document.xml'),
        contains(editMarker),
        reason: 'Smart Editor edit was not emitted into Word XML.',
      );

      // Every preserve-only package part captured from the source must survive
      // byte-for-byte unless it is one of EduSheet's regenerated owned parts.
      for (final preserved in windowsOpen.document.wordPreservation.packageParts) {
        final output = _entryBytesOrNull(exportedArchive, preserved.path);
        expect(output, isNotNull, reason: 'Missing preserved part ${preserved.path}');
        expect(output, preserved.bytes, reason: 'Changed preserved part ${preserved.path}');
      }

      final directory = await Directory.systemTemp.createTemp('edusheet-final-word-');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final roundTripFile = File(
        '${directory.path}${Platform.pathSeparator}certified-roundtrip.docx',
      );
      await roundTripFile.writeAsBytes(exported.bytes, flush: true);

      final reparsed = await DocxConversionParser.parse(roundTripFile);
      final reparsedText = _conversionPlainText(reparsed);
      expect(reparsedText, contains(editMarker));
      for (final token in _anchorTokens(originalText)) {
        expect(
          reparsedText,
          contains(token),
          reason: 'Original real-Word text token lost after round trip: $token',
        );
      }

      final nativeReimport = await service.importFile(roundTripFile);
      expect(nativeReimport.nativeRoundTrip, isTrue);
      expect(_smartPlainText(nativeReimport.document), contains(editMarker));
    }
  });
}

List<dynamic> _appendPlainText(List<dynamic> source, String text) {
  final output = List<dynamic>.from(source);
  if (output.isNotEmpty &&
      output.last is Map &&
      (output.last as Map)['insert']?.toString() == '\n') {
    output.insert(output.length - 1, <String, dynamic>{'insert': '\n$text'});
  } else {
    output.add(<String, dynamic>{'insert': '\n$text\n'});
  }
  return output;
}

Future<List<File>> _findMicrosoftWordCorpus() async {
  final directories = <Directory>[
    Directory('test/fixtures/word_maturity/real_word'),
    Directory('release'),
  ];
  final candidates = <File>[];
  for (final directory in directories) {
    if (!await directory.exists()) continue;
    candidates.addAll(
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.docx')),
    );
  }
  candidates.sort((left, right) => left.path.compareTo(right.path));

  final seenHashes = <String>{};
  final result = <File>[];
  for (final candidate in candidates) {
    try {
      final bytes = await candidate.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appXml = _entryTextOrNull(archive, 'docProps/app.xml');
      if (appXml?.contains('Microsoft Word') != true) continue;
      final signature = base64Encode(bytes.length > 256 ? bytes.sublist(0, 256) : bytes);
      if (seenHashes.add('$signature:${bytes.length}')) result.add(candidate);
    } catch (_) {
      // A corrupt/non-DOCX candidate is not part of the valid certification corpus.
    }
  }
  return result;
}

void _expectHealthyDocxPackage(Archive archive, String sourceLabel) {
  final names = archive.files.map((entry) => entry.name).toList(growable: false);
  expect(names.toSet().length, names.length, reason: 'Duplicate ZIP part: $sourceLabel');
  for (final required in <String>[
    '[Content_Types].xml',
    '_rels/.rels',
    'word/document.xml',
    'word/_rels/document.xml.rels',
  ]) {
    expect(names, contains(required), reason: '$sourceLabel missing $required');
  }

  final nameSet = names.toSet();
  for (final relsEntry in archive.files.where((entry) => entry.name.endsWith('.rels'))) {
    final relsXml = utf8.decode(relsEntry.content as List<int>);
    final document = XmlDocument.parse(relsXml);
    final sourcePart = _sourcePartForRelationships(relsEntry.name);
    final sourceDirectory = path.posix.dirname(sourcePart);
    for (final relationship in document.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'Relationship',
        )) {
      if (relationship.getAttribute('TargetMode') == 'External') continue;
      final target = relationship.getAttribute('Target');
      if (target == null || target.isEmpty) continue;
      final withoutFragment = target.split('#').first;
      final resolved = path.posix.normalize(
        path.posix.join(sourceDirectory == '.' ? '' : sourceDirectory, withoutFragment),
      ).replaceFirst(RegExp(r'^/+'), '');
      expect(
        nameSet,
        contains(resolved),
        reason: '${relsEntry.name} points to missing package part $resolved',
      );
    }
  }
}

String _sourcePartForRelationships(String relsPath) {
  if (relsPath == '_rels/.rels') return '';
  final marker = '/_rels/';
  final index = relsPath.indexOf(marker);
  if (index < 0) return '';
  final directory = relsPath.substring(0, index);
  final relName = relsPath.substring(index + marker.length);
  final sourceName = relName.endsWith('.rels')
      ? relName.substring(0, relName.length - '.rels'.length)
      : relName;
  return directory.isEmpty ? sourceName : '$directory/$sourceName';
}

List<String> _anchorTokens(String text) {
  final tokens = RegExp(r'[A-Za-z][A-Za-z0-9()#-]{5,}')
      .allMatches(text)
      .map((match) => match.group(0)!)
      .toSet()
      .take(5)
      .toList(growable: false);
  return tokens;
}

String _smartPlainText(SmartDocument document) {
  final buffer = StringBuffer();
  for (final operation in document.quillOperations) {
    final insert = operation['insert'];
    if (insert is String) buffer.write(insert);
  }
  return buffer.toString();
}

String _conversionPlainText(ConversionDocument document) {
  final buffer = StringBuffer();

  void visitBlocks(Iterable<ConversionBlock> blocks) {
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            buffer.write(inline.text);
          } else if (inline is ConversionDynamicFieldRun) {
            buffer.write(
              inline.field == ConversionDynamicField.pageNumber
                  ? '{PAGE}'
                  : '{NUMPAGES}',
            );
          } else if (inline is ConversionFieldRun) {
            buffer.write(inline.resultText);
          } else if (inline is ConversionMathRun) {
            buffer.write(inline.plainText);
          } else if (inline is ConversionNoteReferenceRun) {
            visitBlocks(inline.blocks);
          } else if (inline is ConversionTextBoxRun) {
            visitBlocks(inline.blocks);
          } else if (inline is ConversionShapeRun) {
            visitBlocks(inline.blocks);
          } else if (inline is ConversionOpaqueOoxmlRun) {
            buffer.write(inline.fallbackText);
          }
        }
        buffer.write(' ');
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visitBlocks(cell.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visitBlocks(block.fallbackBlocks);
      }
    }
  }

  for (final section in document.sections) {
    visitBlocks(section.blocks);
  }
  return buffer.toString();
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((item) => item.name == name);
  return utf8.decode(entry.content as List<int>);
}

String? _entryTextOrNull(Archive archive, String name) {
  for (final entry in archive.files) {
    if (entry.name == name) return utf8.decode(entry.content as List<int>);
  }
  return null;
}

List<int>? _entryBytesOrNull(Archive archive, String name) {
  for (final entry in archive.files) {
    if (entry.name == name) return List<int>.from(entry.content as List<int>);
  }
  return null;
}
