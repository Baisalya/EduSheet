import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/paper_composer/application/smart_paper_docx_round_trip_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/smart_paper_release_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('step10_round_trip_gate_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Step 10 Word export restores the exact canonical Smart Paper',
    () async {
      final paper = SmartPaperReleaseFixture.paper();
      final output = await WordExportService.export(
        paper,
        SmartPaperReleaseFixture.template,
      );

      final result = await SmartPaperDocxRoundTripService.importFromFile(
        output,
      );

      expect(result.canRestoreExactly, isTrue);
      expect(jsonEncode(result.paper!.toJson()), jsonEncode(paper.toJson()));
    },
  );

  test(
    'Step 10 safely merges supported Word edits without losing structure',
    () async {
      final paper = SmartPaperReleaseFixture.paper();
      final output = await WordExportService.export(
        paper,
        SmartPaperReleaseFixture.template,
      );
      final source = ZipDecoder().decodeBytes(await output.readAsBytes());
      final document = _archiveText(source, 'word/document.xml');

      expect(
        document,
        contains(SmartPaperDocxRoundTripService.questionTextTag('release-mcq')),
      );
      expect(
        document,
        contains(
          SmartPaperDocxRoundTripService.questionOptionTag(
            'release-mcq',
            'mcq-b',
          ),
        ),
      );

      final edited = document
          .replaceFirst(
            'Which expression is equal to 12?',
            'Which expression is equal to 18?',
          )
          .replaceFirst('2 × 5', '3 × 6');
      final bytes = _replaceDocument(source, edited);

      final result = SmartPaperDocxRoundTripService.importFromBytes(bytes);

      expect(
        result.status,
        SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip,
      );
      final restored = result.paper!;
      final advanced = restored.sections.single.questions.first;
      final mcq = restored.sections.single.questions.last;
      expect(mcq.plainTextAccessibility, 'Which expression is equal to 18?');
      expect(mcq.options[1].text, '3 × 6');

      // Advanced content that Word did not edit remains canonical and structured.
      expect(advanced.tableData?.rows.length, 2);
      expect(advanced.subQuestions.length, 2);
      expect(advanced.internalChoices.length, 2);
      expect(advanced.metadata, paper.sections.single.questions.first.metadata);
      expect(restored.pageLayout.toJson(), paper.pageLayout.toJson());
      expect(restored.maximumMarks, paper.maximumMarks);
    },
  );

  test(
    'Step 10 refuses structural external edits rather than flattening them',
    () async {
      final paper = SmartPaperReleaseFixture.paper();
      final output = await WordExportService.export(
        paper,
        SmartPaperReleaseFixture.template,
      );
      final source = ZipDecoder().decodeBytes(await output.readAsBytes());
      final document = _archiveText(source, 'word/document.xml');
      final edited = document.replaceFirst(
        '<w:body>',
        '<w:body><w:p><w:r><w:t>External unsupported block</w:t></w:r></w:p>',
      );

      final result = SmartPaperDocxRoundTripService.importFromBytes(
        _replaceDocument(source, edited),
      );

      expect(result.status, SmartPaperDocxImportStatus.modifiedOutsideEduSheet);
      expect(result.paper, isNull);
      expect(result.canApplySafely, isFalse);
    },
  );
}

String _archiveText(Archive archive, String name) {
  final entry = archive.files.firstWhere((file) => file.name == name);
  return utf8.decode(entry.content as List<int>);
}

List<int> _replaceDocument(Archive source, String documentXml) {
  final target = Archive();
  for (final entry in source.files) {
    if (entry.name == 'word/document.xml') {
      target.addFile(ArchiveFile.string(entry.name, documentXml));
    } else {
      target.addFile(
        ArchiveFile.bytes(
          entry.name,
          List<int>.from(entry.content as List<int>),
        ),
      );
    }
  }
  return ZipEncoder().encode(target);
}
