import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_command_palette.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_document_actions.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_file_opener.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_open_import_workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows-style DOCX selection imports directly from filesystem path', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-open-win-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final source = File('${directory.path}${Platform.pathSeparator}lesson.docx');
    await source.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);

    String? importedPath;
    final opener = SmartEditorDocxFileOpener(
      pickFile: () async => SmartEditorPickedDocx(
        name: 'lesson.docx',
        path: source.path,
      ),
      importFile: (file) async {
        importedPath = file.path;
        expect(await file.readAsBytes(), const <int>[1, 2, 3, 4]);
        return SmartEditorDocxImportResult(
          document: SmartDocument.blank(title: 'Windows import'),
        );
      },
    );

    final result = await opener.pickAndImport();
    expect(result?.document.title, 'Windows import');
    expect(importedPath, source.path);
    expect(await source.exists(), isTrue);
  });

  test('Android-style provider bytes use a private temp DOCX and clean it up', () async {
    String? importedPath;
    final bytes = Uint8List.fromList(<int>[9, 8, 7, 6, 5]);
    final opener = SmartEditorDocxFileOpener(
      pickFile: () async => SmartEditorPickedDocx(
        name: 'provider lesson.docx',
        bytes: bytes,
      ),
      importFile: (file) async {
        importedPath = file.path;
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), bytes);
        return SmartEditorDocxImportResult(
          document: SmartDocument.blank(title: 'Android import'),
        );
      },
    );

    final result = await opener.pickAndImport();
    expect(result?.document.title, 'Android import');
    expect(importedPath, isNotNull);
    expect(await File(importedPath!).exists(), isFalse);
  });

  test('Open/import Word is available from Smart Editor command palette', () {
    final command = smartEditorAllCommands.singleWhere(
      (item) => item.id == SmartEditorCommandId.importDocx,
    );
    expect(command.title, 'Open / import Word (.docx)');
    expect(command.matches('open word'), isTrue);
    expect(command.matches('android'), isTrue);
    expect(command.matches('windows'), isTrue);
  });

  test('Open/import workflow preserves current work before committing imported document', () async {
    final imported = SmartDocument.blank(title: 'Imported lesson');
    final events = <String>[];
    SmartDocument? savedImported;
    String? clearedRecoveryId;
    final opener = SmartEditorDocxFileOpener(
      pickFile: () async => SmartEditorPickedDocx(
        name: 'lesson.docx',
        bytes: Uint8List.fromList(const <int>[1]),
      ),
      importFile: (_) async {
        events.add('import');
        return SmartEditorDocxImportResult(document: imported);
      },
    );

    final result = await SmartEditorOpenImportWorkflow(opener: opener).run(
      persistCurrent: () async {
        events.add('persist-current');
        return true;
      },
      saveImported: (document) async {
        events.add('save-imported');
        savedImported = document;
      },
      clearImportedRecovery: (documentId) async {
        events.add('clear-recovery');
        clearedRecoveryId = documentId;
      },
    );

    expect(result?.document.id, imported.id);
    expect(savedImported?.id, imported.id);
    expect(clearedRecoveryId, imported.id);
    expect(
      events,
      const <String>[
        'import',
        'persist-current',
        'save-imported',
        'clear-recovery',
      ],
    );
  });

  test('Open/import workflow does not commit imported document when current save fails', () async {
    var importedSaved = false;
    final opener = SmartEditorDocxFileOpener(
      pickFile: () async => SmartEditorPickedDocx(
        name: 'lesson.docx',
        bytes: Uint8List.fromList(const <int>[1]),
      ),
      importFile: (_) async => SmartEditorDocxImportResult(
        document: SmartDocument.blank(title: 'Blocked import'),
      ),
    );

    final result = await SmartEditorOpenImportWorkflow(opener: opener).run(
      persistCurrent: () async => false,
      saveImported: (_) async => importedSaved = true,
    );

    expect(result, isNull);
    expect(importedSaved, isFalse);
  });

  testWidgets('desktop Smart Editor Open/import action is directly available', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SmartEditorDesktopOpenDocxButton(
                busy: false,
                onOpen: () => openCount += 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('smart-editor-open-docx')), findsOneWidget);
    await tester.tap(find.byKey(const Key('smart-editor-open-docx')));
    await tester.pump();
    expect(openCount, 1);
  });

  testWidgets('compact Android Smart Editor More menu exposes Open/import', (tester) async {
    var openCount = 0;
    var printCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SmartEditorMobileDocumentMenu(
                fullMode: false,
                busy: false,
                onToggleMode: () {},
                onOpenDocx: () => openCount += 1,
                onExport: (_) {},
                onPrint: () => printCount += 1,
                onSave: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('smart-editor-mobile-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('smart-editor-mobile-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Open / import Word (.docx)'), findsOneWidget);

    await tester.tap(find.text('Open / import Word (.docx)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(openCount, 1);

    await tester.tap(find.byKey(const Key('smart-editor-mobile-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Print'), findsOneWidget);
    await tester.tap(find.text('Print'));
    await tester.pump();
    expect(printCount, 1);
  });
}
