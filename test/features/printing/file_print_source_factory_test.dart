import 'dart:io';

import 'package:edusheet/features/printing/application/file_print_source_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  test('file print source factory advertises only implemented file types', () {
    expect(FilePrintSourceFactory.supportsPath(r'C:\\docs\\paper.pdf'), isTrue);
    expect(FilePrintSourceFactory.supportsPath('/tmp/lesson.DOCX'), isTrue);
    expect(FilePrintSourceFactory.supportsPath('/tmp/sheet.xlsx'), isFalse);
  });

  test('PDF source reads bytes lazily and caches them', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet_print_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/paper.pdf');
    await file.writeAsBytes(<int>[10, 20, 30, 40]);

    final source = FilePrintSourceFactory.fromPath(
      file.path,
      displayName: 'My Paper.pdf',
    );
    final first = await source.build(PdfPageFormat.a4);
    await file.writeAsBytes(<int>[99]);
    final second = await source.build(PdfPageFormat.a4);

    expect(first, <int>[10, 20, 30, 40]);
    expect(second, <int>[10, 20, 30, 40]);
    expect(source.pdfFileName, 'My Paper.pdf');
  });

  test('unsupported files fail before invoking print platform code', () {
    expect(
      () => FilePrintSourceFactory.fromPath('/tmp/sheet.xlsx'),
      throwsUnsupportedError,
    );
  });
}
