import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/word_converter/services/word_converter_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pdfRendererChannel = MethodChannel('edusheet/pdf_renderer');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('word_converter_test_');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pdfRendererChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('convertPdfToDocxExact embeds one image per PDF page', () async {
    final input = await _writePdfWithText(tempDir);
    final imagePaths = await _writeRenderedPageImages(tempDir, 2);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pdfRendererChannel, (call) async {
          expect(call.method, 'renderPagesToImages');
          expect(call.arguments['pdfPath'], input.path);
          expect(call.arguments['scale'], 3);
          return imagePaths;
        });

    final output = await WordConverterService.convertPdfToDocxExact(input.path);
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();
    final documentXml = _archiveText(archive, 'word/document.xml');
    final relsXml = _archiveText(archive, 'word/_rels/document.xml.rels');
    final contentTypesXml = _archiveText(archive, '[Content_Types].xml');

    expect(p.extension(output.path), '.docx');
    expect(names, contains('word/document.xml'));
    expect(names, contains('word/_rels/document.xml.rels'));
    expect(names, contains('word/media/pdf_page_1.png'));
    expect(names, contains('word/media/pdf_page_2.png'));
    expect(contentTypesXml, contains('ContentType="image/png"'));
    expect(relsXml, contains('Target="media/pdf_page_1.png"'));
    expect(relsXml, contains('Target="media/pdf_page_2.png"'));
    expect(documentXml, contains('<a:blip r:embed="rId1"/>'));
    expect(documentXml, contains('<a:blip r:embed="rId2"/>'));
    expect(documentXml, contains('<wp:extent'));
    expect(documentXml, contains('<w:br w:type="page"/>'));
    expect(documentXml, contains('w:top="0"'));
  });

  test('convertPdfToDocxExact fails cleanly without page rendering', () async {
    final input = await _writePdfWithText(tempDir);

    expect(
      () => WordConverterService.convertPdfToDocxExact(input.path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Exact PDF conversion is unavailable'),
        ),
      ),
    );
  });

  test('convertPdfToDocx creates editable docx text with page break', () async {
    final input = await _writePdfWithText(tempDir);

    final output = await WordConverterService.convertPdfToDocx(input.path);
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();
    final documentXml = _archiveText(archive, 'word/document.xml');

    expect(p.extension(output.path), '.docx');
    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('word/document.xml'));
    expect(documentXml, contains('First page title'));
    expect(documentXml, contains('First page body'));
    expect(documentXml, contains('Second page text'));
    expect(documentXml, contains('<w:br w:type="page"/>'));
  });

  test('convertPdfToDocx rejects PDFs without selectable text', () async {
    final input = await _writeBlankPdf(tempDir);

    expect(
      () => WordConverterService.convertPdfToDocx(input.path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('No readable text found'),
        ),
      ),
    );
  });
}

Future<List<String>> _writeRenderedPageImages(
  Directory directory,
  int count,
) async {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l9vLagAAAABJRU5ErkJggg==',
  );
  final paths = <String>[];
  for (var index = 0; index < count; index++) {
    final file = File(p.join(directory.path, 'page_${index + 1}.png'));
    await file.writeAsBytes(bytes, flush: true);
    paths.add(file.path);
  }
  return paths;
}

Future<File> _writePdfWithText(Directory directory) async {
  final document = sf.PdfDocument();
  final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);

  final firstPage = document.pages.add();
  firstPage.graphics.drawString(
    'First page title',
    font,
    bounds: const Rect.fromLTWH(0, 0, 400, 30),
  );
  firstPage.graphics.drawString(
    'First page body',
    font,
    bounds: const Rect.fromLTWH(0, 40, 400, 30),
  );

  final secondPage = document.pages.add();
  secondPage.graphics.drawString(
    'Second page text',
    font,
    bounds: const Rect.fromLTWH(0, 0, 400, 30),
  );

  final file = File(p.join(directory.path, 'selectable.pdf'));
  await file.writeAsBytes(await document.save(), flush: true);
  document.dispose();
  return file;
}

Future<File> _writeBlankPdf(Directory directory) async {
  final document = sf.PdfDocument();
  document.pages.add();

  final file = File(p.join(directory.path, 'blank.pdf'));
  await file.writeAsBytes(await document.save(), flush: true);
  document.dispose();
  return file;
}

String _archiveText(Archive archive, String name) {
  final file = archive.files.firstWhere((entry) => entry.name == name);
  return utf8.decode(file.content as List<int>);
}
