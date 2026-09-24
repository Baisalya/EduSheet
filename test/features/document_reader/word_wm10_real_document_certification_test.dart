import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/word_wm5_wm6_fixture.dart';
import '../../support/word_wm7_wm8_fixture.dart';
import '../../support/word_wm9_preservation_fixture.dart';

void main() {
  test('WM10 certifies the checked-in Microsoft Word identified document', () async {
    final source = await _findMicrosoftWordSeed();

    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final appXml = _entryText(archive, 'docProps/app.xml');
    expect(appXml, contains('<Application>Microsoft Word'));

    final parseWatch = Stopwatch()..start();
    final parsed = await DocxConversionParser.parse(source);
    parseWatch.stop();
    final before = _plainText(parsed);
    expect(before, contains('EduSheet (PowerPaper)'));
    expect(before, contains('Executive Summary'));
    expect(parsed.sections, isNotEmpty);
    expect(_tableCount(parsed), greaterThan(0));
    expect(_imageCount(parsed), greaterThan(0));
    expect(parseWatch.elapsedMilliseconds, lessThan(10000));

    const service = SmartEditorDocxService();
    final imported = await service.importFile(source);
    expect(imported.document.deltaJson, isNotEmpty);

    final exported = await service.export(imported.document);
    final directory = await Directory.systemTemp.createTemp('edusheet-wm10-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final exportedFile = File(
      '${directory.path}${Platform.pathSeparator}wm10-roundtrip.docx',
    );
    await exportedFile.writeAsBytes(exported.bytes, flush: true);

    final exportedArchive = ZipDecoder().decodeBytes(exported.bytes);
    for (final preservedPath in <String>[
      'word/theme/theme1.xml',
      'word/fontTable.xml',
      'word/webSettings.xml',
      'docProps/custom.xml',
    ]) {
      final originalPart = _entryBytesOrNull(archive, preservedPath);
      if (originalPart == null) continue;
      expect(
        _entryBytesOrNull(exportedArchive, preservedPath),
        originalPart,
        reason: 'WM9 package preservation changed $preservedPath',
      );
    }

    final reparsed = await DocxConversionParser.parse(exportedFile);
    final after = _plainText(reparsed);
    expect(after, contains('EduSheet (PowerPaper)'));
    expect(after, contains('Executive Summary'));
    expect(_tableCount(reparsed), greaterThan(0));
    expect(_imageCount(reparsed), greaterThan(0));

    final nativeReimport = await service.importFile(exportedFile);
    expect(nativeReimport.nativeRoundTrip, isTrue);
  });

  test('WM10 compatibility corpus exercises layout, advanced and preservation profiles',
      () async {
    final fixtures = <Future<File> Function()>[
      writeWm56Fixture,
      writeWm78Fixture,
      writeWm9PreservationFixture,
    ];
    final files = <File>[];
    addTearDown(() async {
      for (final file in files) {
        if (await file.parent.exists()) {
          await file.parent.delete(recursive: true);
        }
      }
    });

    for (final create in fixtures) {
      final file = await create();
      files.add(file);
      final parsed = await DocxConversionParser.parse(file);
      expect(parsed.sections, isNotEmpty, reason: file.path);
      expect(_plainText(parsed).trim(), isNotEmpty, reason: file.path);
    }
  });
}


Future<File> _findMicrosoftWordSeed() async {
  final corpusDirectories = <Directory>[
    Directory('test/fixtures/word_maturity/real_word'),
    Directory('release'),
  ];
  final candidates = <File>[];

  for (final directory in corpusDirectories) {
    if (!await directory.exists()) continue;
    candidates.addAll(
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.docx')),
    );
  }
  candidates.sort((left, right) => left.path.compareTo(right.path));

  for (final candidate in candidates) {
    try {
      final archive = ZipDecoder().decodeBytes(await candidate.readAsBytes());
      final appXml = _entryTextOrNull(archive, 'docProps/app.xml');
      if (appXml?.contains('Microsoft Word') ?? false) {
        return candidate;
      }
    } catch (_) {
      // Ignore non-DOCX/corrupt candidates and continue searching the corpus.
    }
  }

  fail(
    'WM10 requires at least one checked-in Microsoft Word-authored DOCX. '
    'Apply the WM10 seed-corpus hotfix so test/fixtures/word_maturity/real_word '
    'contains the certification seed.',
  );
}

String? _entryTextOrNull(Archive archive, String name) {
  for (final entry in archive.files) {
    if (entry.name == name) {
      return utf8.decode(entry.content as List<int>);
    }
  }
  return null;
}

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((candidate) => candidate.name == name);
  return utf8.decode(entry.content as List<int>);
}

String _plainText(ConversionDocument document) {
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
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visitBlocks(block.fallbackBlocks);
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visitBlocks(cell.blocks);
          }
        }
      }
    }
  }

  for (final section in document.sections) {
    visitBlocks(section.blocks);
  }
  return buffer.toString();
}


List<int>? _entryBytesOrNull(Archive archive, String name) {
  for (final entry in archive.files) {
    if (entry.name == name) return List<int>.from(entry.content as List<int>);
  }
  return null;
}

int _tableCount(ConversionDocument document) {
  var count = 0;
  void visit(Iterable<ConversionBlock> blocks) {
    for (final block in blocks) {
      if (block is ConversionTable) {
        count++;
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visit(block.fallbackBlocks);
      } else if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionTextBoxRun) visit(inline.blocks);
          if (inline is ConversionShapeRun) visit(inline.blocks);
          if (inline is ConversionNoteReferenceRun) visit(inline.blocks);
        }
      }
    }
  }
  for (final section in document.sections) {
    visit(section.blocks);
  }
  return count;
}

int _imageCount(ConversionDocument document) {
  var count = 0;
  void visit(Iterable<ConversionBlock> blocks) {
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        for (final inline in block.inlines) {
          if (inline is ConversionImageRun) count++;
          if (inline is ConversionTextBoxRun) visit(inline.blocks);
          if (inline is ConversionShapeRun) visit(inline.blocks);
          if (inline is ConversionNoteReferenceRun) visit(inline.blocks);
        }
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            visit(cell.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        visit(block.fallbackBlocks);
      }
    }
  }
  for (final section in document.sections) {
    visit(section.blocks);
  }
  return count;
}
