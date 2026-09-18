import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/services/question_paper_service.dart';
import 'package:edusheet/features/pdf/services/word_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase7_page_tools_');
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
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('DOCX carries columns, page background and repeated watermark', () async {
    final paper = _paper();
    final output = await WordExportService.export(paper, _template());
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final document = _archiveText(archive, 'word/document.xml');
    final header = _archiveText(archive, 'word/header1.xml');

    expect(document, contains('<w:background w:color="FFFDF5"/>'));
    expect(document, contains('<w:cols w:num="3" w:space="480"/>'));
    expect(header, contains('EduSheetWatermark'));
    expect(header, contains('SAMPLE'));
    expect(header, contains('rotation:325'));
  });

  test('PDF accepts the same Phase 7 page design contract', () async {
    final pdf = await QuestionPaperService.generateDocument(
      _paper(),
      _template(),
    );
    final bytes = await pdf.save();

    expect(bytes, isNotEmpty);
  });
}

Paper _paper() {
  return Paper(
    id: 'phase7-paper',
    title: 'Phase 7 Paper',
    createdAt: DateTime(2026, 9, 18),
    pageLayout: const PaperPageLayout(
      pageSize: PaperPageSize.a4,
      columns: PaperPageColumns.three,
      columnSpacingPoints: 24,
      watermarkText: 'SAMPLE',
      watermarkOpacity: 0.15,
      pageBackgroundArgb: 0xFFFFFDF5,
      showRulers: true,
      showGrid: true,
      gridSpacingPoints: 12,
    ),
    sections: [
      PaperSection(
        id: 's1',
        title: 'Section A',
        questions: [
          Question(id: 'q1', text: 'Question one', marks: 1),
          Question(id: 'q2', text: 'Question two', marks: 1),
          Question(id: 'q3', text: 'Question three', marks: 1),
        ],
      ),
    ],
  );
}

PaperTemplate _template() {
  return PaperTemplate(
    id: 'phase7-template',
    name: 'Phase 7 Template',
    type: TemplateType.school,
    primaryColor: PdfColors.black,
  );
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}
