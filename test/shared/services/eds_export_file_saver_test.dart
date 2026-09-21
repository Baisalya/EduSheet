import 'dart:convert';

import 'package:edusheet/shared/services/eds_export_file_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EdsExportFileSaver', () {
    test('Android passes UTF-8 .eds bytes to saveFile and does not rewrite path', () async {
      EdsSaveDialogRequest? captured;
      var writeCalls = 0;
      final saver = EdsExportFileSaver(
        isAndroid: true,
        saveFile: (request) async {
          captured = request;
          return 'content://picked/document/42';
        },
        writeTextFile: (path, source) async {
          writeCalls++;
        },
      );

      final result = await saver.save(
        source: '{"title":"ଗଣିତ ✓"}',
        fileName: 'My Paper',
        dialogTitle: 'Save editable EduSheet paper',
      );

      expect(result, 'content://picked/document/42');
      expect(captured, isNotNull);
      expect(captured!.fileName, 'My Paper.eds');
      expect(utf8.decode(captured!.bytes!), '{"title":"ଗଣିତ ✓"}');
      expect(writeCalls, 0);
    });

    test('Windows-style flow preserves path save then File write behavior', () async {
      EdsSaveDialogRequest? captured;
      String? writtenPath;
      String? writtenSource;
      final saver = EdsExportFileSaver(
        isAndroid: false,
        saveFile: (request) async {
          captured = request;
          return r'C:\Exports\Paper';
        },
        writeTextFile: (path, source) async {
          writtenPath = path;
          writtenSource = source;
        },
      );

      final result = await saver.save(
        source: '{"paper":1}',
        fileName: 'Paper.eds',
        dialogTitle: 'Save editable EduSheet paper',
      );

      expect(captured, isNotNull);
      expect(captured!.bytes, isNull);
      expect(captured!.fileName, 'Paper.eds');
      expect(writtenPath, r'C:\Exports\Paper.eds');
      expect(writtenSource, '{"paper":1}');
      expect(result, r'C:\Exports\Paper.eds');
    });
  });
}
