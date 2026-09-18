import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/word_document_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocumentFile document() => DocumentFile(
        name: 'performance-regression.docx',
        path: 'C:/Documents/performance-regression.docx',
        extension: '.docx',
        size: 4096,
        lastModified: DateTime(2026, 9, 17),
        type: DocumentType.word,
      );

  testWidgets(
    'Word view-mode and viewport changes keep the same DocxView state',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final doc = document();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WordDocumentViewer(document: doc)),
        ),
      );

      final finder = find.byType(DocxView);
      expect(finder, findsOneWidget);

      final beforeState = tester.state<State>(finder);
      var view = tester.widget<DocxView>(finder);
      expect(view.key, ValueKey('docx-${doc.path}'));
      expect(view.path, doc.path);
      expect(view.config.pageMode, DocxPageMode.continuous);

      await tester.tap(find.text('Fit width'));
      await tester.pump();

      final afterModeState = tester.state<State>(finder);
      view = tester.widget<DocxView>(finder);
      expect(identical(afterModeState, beforeState), isTrue);
      expect(view.key, ValueKey('docx-${doc.path}'));
      expect(view.config.pageMode, DocxPageMode.continuous);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();

      final afterResizeState = tester.state<State>(finder);
      view = tester.widget<DocxView>(finder);
      expect(identical(afterResizeState, beforeState), isTrue);
      expect(view.config.pageMode, DocxPageMode.continuous);
      expect(view.config.pageWidth, closeTo(374, 0.01));
    },
  );

  testWidgets('Phone Fit Width uses continuous rendering without remount keys',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));

    final doc = document();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WordDocumentViewer(document: doc)),
      ),
    );

    final view = tester.widget<DocxView>(find.byType(DocxView));
    expect(view.config.pageMode, DocxPageMode.continuous);
    expect(view.config.pageWidth, closeTo(304, 0.01));
    expect(view.key, ValueKey('docx-${doc.path}'));
  });
}
