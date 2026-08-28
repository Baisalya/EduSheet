import 'dart:io';

import 'package:edusheet/features/document_reader/data/services/document_file_read_service.dart';
import 'package:edusheet/features/document_reader/data/services/presentation_parser_service.dart';
import 'package:edusheet/features/document_reader/data/services/spreadsheet_parser_service.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/domain/models/presentation_model.dart';
import 'package:edusheet/features/document_reader/domain/models/spreadsheet_model.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/presentation_document_viewer.dart';
import 'package:edusheet/features/document_reader/presentation/widgets/viewers/spreadsheet_document_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('legacy Office format stays capability-honest on a phone', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = _document('lesson.ppt', '.ppt');

    await pumpAt(
      tester,
      const Size(320, 720),
      FilePreviewScreen(document: document),
    );

    expect(find.text('External Office viewer recommended'), findsOneWidget);
    expect(find.text('Open externally'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PPTX viewer adapts between phone and desktop layouts', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = _document('lesson.pptx', '.pptx');
    final parser = _FakePresentationParser();

    await pumpAt(
      tester,
      const Size(320, 720),
      PresentationDocumentViewer(document: document, parserService: parser),
    );
    expect(find.text('Lesson title'), findsOneWidget);
    expect(find.text('Present'), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAt(
      tester,
      const Size(1280, 800),
      PresentationDocumentViewer(document: document, parserService: parser),
    );
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PPTX cloud placeholder error is recoverable and retry is sync-safe',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _document('cloud_lesson.pptx', '.pptx');
      final parser = _CloudUnavailablePresentationParser();

      await pumpAt(
        tester,
        const Size(360, 720),
        PresentationDocumentViewer(document: document, parserService: parser),
      );

      expect(
        find.text('OneDrive file is not available offline'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(parser.attempts, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(parser.attempts, 2);
      expect(
        find.text('OneDrive file is not available offline'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'spreadsheet cloud placeholder retry does not return a Future from setState',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _document('cloud_marks.xlsx', '.xlsx');
      final parser = _CloudUnavailableSpreadsheetParser();

      await pumpAt(
        tester,
        const Size(360, 720),
        SpreadsheetDocumentViewer(document: document, parserService: parser),
      );

      expect(
        find.text('Cloud spreadsheet is not available offline'),
        findsOneWidget,
      );
      expect(parser.attempts, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(parser.attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'spreadsheet grid remains renderable on phone and Windows widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _document('marks.xlsx', '.xlsx');
      final parser = _FakeSpreadsheetParser();

      for (final size in const [Size(320, 720), Size(1280, 800)]) {
        await pumpAt(
          tester,
          size,
          SpreadsheetDocumentViewer(document: document, parserService: parser),
        );
        expect(find.textContaining('populated rows'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

DocumentFile _document(String name, String extension) {
  return DocumentFile(
    name: name,
    path: 'C:/Documents/$name',
    extension: extension,
    size: 1024,
    lastModified: DateTime(2026, 8, 14),
    type: DocumentFile.getDocumentType(extension),
  );
}

class _FakePresentationParser extends PresentationParserService {
  @override
  Future<PresentationDocument> load(File file) async {
    return const PresentationDocument(
      slideWidth: 1600,
      slideHeight: 900,
      slides: [
        PresentationSlide(
          number: 1,
          transition: PresentationTransition(
            kind: PresentationTransitionKind.fade,
          ),
          elements: [
            PresentationElement(
              type: PresentationElementType.text,
              left: 0.1,
              top: 0.12,
              width: 0.8,
              height: 0.2,
              hasBounds: true,
              text: 'Lesson title',
              fontSizePoints: 32,
              bold: true,
            ),
          ],
        ),
        PresentationSlide(
          number: 2,
          elements: [
            PresentationElement(
              type: PresentationElementType.text,
              left: 0.1,
              top: 0.3,
              width: 0.8,
              height: 0.2,
              hasBounds: true,
              text: 'Second slide',
            ),
          ],
        ),
      ],
    );
  }
}

class _FakeSpreadsheetParser extends SpreadsheetParserService {
  @override
  Future<SpreadsheetWorkbook> load(File file, String extension) async {
    return const SpreadsheetWorkbook(
      sheets: [
        SpreadsheetSheet(
          name: 'Marks',
          columnCount: 40,
          rows: [
            SpreadsheetRow(rowIndex: 1, cells: {0: 'Student', 1: 'Score'}),
            SpreadsheetRow(rowIndex: 2, cells: {0: 'Asha', 1: '98'}),
          ],
        ),
      ],
    );
  }
}

class _CloudUnavailablePresentationParser extends PresentationParserService {
  int attempts = 0;

  @override
  Future<PresentationDocument> load(File file) async {
    attempts += 1;
    throw DocumentFileReadException(
      kind: DocumentFileReadFailure.cloudProviderUnavailable,
      path: file.path,
      osErrorCode: 362,
      message: 'Cloud provider is not running.',
    );
  }
}

class _CloudUnavailableSpreadsheetParser extends SpreadsheetParserService {
  int attempts = 0;

  @override
  Future<SpreadsheetWorkbook> load(File file, String extension) async {
    attempts += 1;
    throw DocumentFileReadException(
      kind: DocumentFileReadFailure.cloudProviderUnavailable,
      path: file.path,
      osErrorCode: 362,
      message: 'Cloud provider is not running.',
    );
  }
}
