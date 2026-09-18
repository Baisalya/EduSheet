import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_document_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Word viewer keeps a stable path source across parent rebuilds',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final document = DocumentFile(
        name: 'loading-regression.docx',
        path: 'C:/Documents/loading-regression.docx',
        extension: '.docx',
        size: 4096,
        lastModified: DateTime(2026, 9, 17),
        type: DocumentType.word,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(body: WordDocumentViewer(document: document)),
        ),
      );

      var docxView = tester.widget<DocxView>(find.byType(DocxView));
      expect(docxView.path, document.path);
      expect(docxView.file, isNull);
      expect(docxView.bytes, isNull);

      // Simulate the kind of parent rebuild that occurs when the external
      // DocxSearchController publishes its initial document index. The viewer
      // source must remain value-stable so docx_file_viewer does not restart
      // _loadDocument() from didUpdateWidget.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: WordDocumentViewer(document: document)),
        ),
      );

      docxView = tester.widget<DocxView>(find.byType(DocxView));
      expect(docxView.path, document.path);
      expect(docxView.file, isNull);
      expect(docxView.bytes, isNull);
    },
  );
}
