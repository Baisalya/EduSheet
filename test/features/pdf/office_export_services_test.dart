import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/export_file_service.dart';
import 'package:edusheet/features/pdf/services/pdf_service.dart';
import 'package:edusheet/features/pdf/services/presentation_export_service.dart';
import 'package:edusheet/features/pdf/services/spreadsheet_export_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('office_export_test_');
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
    'ExportFileService creates EduSheet folder and unique file names',
    () async {
      final first = await ExportFileService.uniqueFile(
        fileNameBase: 'Algebra Test',
        extension: '.pdf',
      );
      await first.writeAsString('existing');

      final second = await ExportFileService.uniqueFile(
        fileNameBase: 'Algebra Test',
        extension: '.pdf',
      );

      expect(first.path, contains('${Platform.pathSeparator}EduSheet'));
      expect(first.path, endsWith('Algebra Test.pdf'));
      expect(second.path, endsWith('Algebra Test (1).pdf'));
    },
  );

  test(
    'WordExportService saves custom file names inside EduSheet folder',
    () async {
      final output = await WordExportService.export(
        _samplePaper(),
        _sampleTemplate(),
        fileNameBase: 'Class 10 Exam',
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final documentXml = _archiveText(archive, 'word/document.xml');

      expect(output.path, contains('${Platform.pathSeparator}EduSheet'));
      expect(output.path, endsWith('Class 10 Exam.docx'));
      expect(documentXml, contains('Algebra Test'));
      expect(documentXml, contains('Solve x + 2 = 5'));
    },
  );

  test('PdfService exports a PDF file inside EduSheet folder', () async {
    final output = await PdfService.export(
      _samplePaper(),
      _sampleTemplate(),
      fileNameBase: 'Printable Algebra',
    );

    expect(output.path, contains('${Platform.pathSeparator}EduSheet'));
    expect(output.path, endsWith('Printable Algebra.pdf'));
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
  });

  test(
    'SpreadsheetExportService creates workbook sheets with paper data',
    () async {
      final output = await SpreadsheetExportService.export(
        _samplePaper(),
        _sampleTemplate(),
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final names = archive.files.map((file) => file.name).toSet();
      final workbookXml = _archiveText(archive, 'xl/workbook.xml');
      final summaryXml = _archiveText(archive, 'xl/worksheets/sheet1.xml');
      final questionsXml = _archiveText(archive, 'xl/worksheets/sheet2.xml');
      final optionsXml = _archiveText(archive, 'xl/worksheets/sheet3.xml');

      expect(output.path, endsWith('.xlsx'));
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('xl/workbook.xml'));
      expect(names, contains('xl/worksheets/sheet1.xml'));
      expect(names, contains('xl/worksheets/sheet2.xml'));
      expect(names, contains('xl/worksheets/sheet3.xml'));
      expect(workbookXml, contains('Summary'));
      expect(workbookXml, contains('Questions'));
      expect(workbookXml, contains('Options'));
      expect(summaryXml, contains('Algebra Test'));
      expect(summaryXml, contains('Sample School'));
      expect(questionsXml, contains('Solve x + 2 = 5'));
      expect(questionsXml, contains('MCQ'));
      expect(optionsXml, contains('3'));
      expect(optionsXml, contains('Correct'));
    },
  );

  test(
    'PresentationExportService creates editable slides with paper data',
    () async {
      final output = await PresentationExportService.export(
        _samplePaper(),
        _sampleTemplate(),
      );
      final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
      final names = archive.files.map((file) => file.name).toSet();
      final presentationXml = _archiveText(archive, 'ppt/presentation.xml');
      final titleSlideXml = _archiveText(archive, 'ppt/slides/slide1.xml');
      final sectionSlideXml = _archiveText(archive, 'ppt/slides/slide2.xml');
      final questionSlideXml = _archiveText(archive, 'ppt/slides/slide3.xml');

      expect(output.path, endsWith('.pptx'));
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('ppt/presentation.xml'));
      expect(names, contains('ppt/slides/slide1.xml'));
      expect(names, contains('ppt/slides/slide2.xml'));
      expect(names, contains('ppt/slides/slide3.xml'));
      expect(names, contains('ppt/slideMasters/slideMaster1.xml'));
      expect(presentationXml, contains('p:sldIdLst'));
      expect(titleSlideXml, contains('Algebra Test'));
      expect(titleSlideXml, contains('Sample School'));
      expect(sectionSlideXml, contains('Section A'));
      expect(questionSlideXml, contains('Solve x + 2 = 5'));
      expect(questionSlideXml, contains('3'));
    },
  );
}

Paper _samplePaper() {
  return Paper(
    id: 'paper-1',
    title: 'Algebra Test',
    schoolName: 'Sample School',
    instruction: 'Answer carefully.',
    createdAt: DateTime.now(),
    headerFields: [
      PaperHeaderField(id: 'subject', label: 'Subject', value: 'Math'),
    ],
    sections: [
      PaperSection(
        id: 'section-a',
        title: 'Section A',
        prefix: 'A.',
        requiredCount: 1,
        questions: [
          Question(
            id: 'q1',
            text: jsonEncode([
              {'insert': 'Solve x + 2 = 5\n'},
            ]),
            type: QuestionType.mcq,
            marks: 2,
            options: [
              QuestionOption(id: 'a', text: '2'),
              QuestionOption(id: 'b', text: '3', isCorrect: true),
            ],
          ),
        ],
      ),
    ],
  );
}

PaperTemplate _sampleTemplate() {
  return PaperTemplate(
    id: 'template-1',
    name: 'Sample Template',
    type: TemplateType.school,
    primaryColor: PdfColors.black,
  );
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}
