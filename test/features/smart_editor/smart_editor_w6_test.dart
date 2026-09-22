import 'dart:io';

import 'package:edusheet/features/editor/services/autosave_coordinator.dart';
import 'package:edusheet/features/smart_editor/data/smart_document_repository.dart';
import 'package:edusheet/features/smart_editor/data/smart_editor_recovery_store.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_library_screen.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_break_embed_builder.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('W6 repairs malformed persisted Delta while keeping valid content', () {
    final source = SmartDocument.blank(title: 'Repair').toJson();
    source['deltaJson'] = <dynamic>[
      <String, dynamic>{'insert': 'Valid text'},
      <String, dynamic>{'retain': 5},
      <String, dynamic>{'insert': 42},
      <String, dynamic>{
        'insert': <String, dynamic>{'image': 'https://example.com/test.png'},
        'attributes': 'invalid attributes',
      },
    ];

    final restored = SmartDocument.fromJson(source);
    expect(restored.deltaJson.length, 3);
    expect(restored.deltaJson.first, <String, dynamic>{'insert': 'Valid text'});
    expect(
      (restored.deltaJson[1] as Map<String, dynamic>)['insert'],
      isA<Map>(),
    );
    expect(
      (restored.deltaJson.last as Map<String, dynamic>)['insert'],
      '\n',
    );

    // The normalized snapshot must be acceptable to Quill, not merely valid
    // JSON.
    expect(() => Document.fromJson(restored.quillOperations), returnsNormally);
  });

  test('W6 crash recovery returns only newer snapshots and clears them', () async {
    final directory = await Directory.systemTemp.createTemp('smart-editor-w6-recovery-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final recovery = SmartEditorRecoveryStore(
      directoryResolver: () async => directory,
    );
    final base = SmartDocument.blank(title: 'Recovery base');
    final newer = base.copyWith(
      title: 'Recovered title',
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Newest unsaved text\n'},
      ],
      updatedAt: base.updatedAt.add(const Duration(seconds: 5)),
    );

    await recovery.save(newer);
    final restored = await recovery.newerSnapshotFor(base);
    expect(restored?.title, 'Recovered title');
    expect(restored?.deltaJson, newer.deltaJson);

    await recovery.clear(base.id);
    expect(await recovery.newerSnapshotFor(base), isNull);

    final older = base.copyWith(
      updatedAt: base.updatedAt.subtract(const Duration(seconds: 1)),
    );
    await recovery.save(older);
    expect(await recovery.newerSnapshotFor(base), isNull);
  });

  testWidgets('W6 library promotes a newer crash-recovery snapshot', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final recovery = _MemorySmartEditorRecoveryStore();
    final base = SmartDocument.blank(title: 'Saved title');
    final recovered = base.copyWith(
      title: 'Recovered unsaved title',
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Recovered body\n'},
      ],
      updatedAt: base.updatedAt.add(const Duration(seconds: 4)),
    );
    await repository.save(base);
    await recovery.save(recovered);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
          smartEditorRecoveryStoreProvider.overrideWithValue(recovery),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: const SmartEditorLibraryScreen(),
        ),
      ),
    );
    final documentTile = find.byKey(ValueKey('smart-document-${base.id}'));
    await _pumpUntil(tester, documentTile);

    await tester.tap(documentTile);
    await _pumpUntil(tester, find.byKey(const Key('smart-editor-title')));

    final title = tester.widget<TextField>(
      find.byKey(const Key('smart-editor-title')),
    );
    expect(title.controller?.text, 'Recovered unsaved title');
    expect((await repository.getById(base.id))?.title, 'Recovered unsaved title');
    expect(find.text('Recovered unsaved Smart Editor changes.'), findsOneWidget);

    // Dispose the editor so its emergency-recovery path is exercised against
    // the deterministic in-memory recovery double used by widget tests.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('W6 lazy autosave materializes only the latest debounced snapshot', () async {
    var factoryCalls = 0;
    final saved = <String>[];
    final coordinator = AutosaveCoordinator<String>(
      delay: const Duration(milliseconds: 20),
      save: (value) async => saved.add(value),
    );
    addTearDown(coordinator.dispose);

    coordinator.scheduleLazy(() {
      factoryCalls += 1;
      return 'old';
    });
    coordinator.scheduleLazy(() {
      factoryCalls += 1;
      return 'latest';
    });

    expect(factoryCalls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    await coordinator.flush();

    expect(factoryCalls, 1);
    expect(saved, <String>['latest']);
  });

  test('W6 explicit page break remains a real multi-page PDF boundary', () async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(0, 0, 'First page content\n', null);
    var offset = controller.document.length - 1;
    controller.replaceText(
      offset,
      0,
      BlockEmbed.custom(
        CustomBlockEmbed(SmartEditorBreakEmbedBuilder.keyName, 'page'),
      ),
      null,
    );
    offset += 1;
    controller.replaceText(offset, 0, '\nSecond page content\n', null);

    final document = SmartDocument.blank(title: 'Pagination').copyWith(
      deltaJson: List<dynamic>.from(controller.document.toDelta().toJson()),
    );
    final result = await const SmartEditorPdfService().export(document);
    final pdf = sf.PdfDocument(inputBytes: result.bytes);
    addTearDown(pdf.dispose);

    expect(pdf.pages.count, greaterThanOrEqualTo(2));
  });

  test('W6 large document survives JSON round-trip without truncation', () {
    final operations = <dynamic>[
      for (var index = 0; index < 6000; index += 1)
        <String, dynamic>{'insert': 'Paragraph $index — classroom notes\n'},
    ];
    final source = SmartDocument.blank(title: 'Large document').copyWith(
      deltaJson: operations,
    );

    final restored = SmartDocument.fromJson(source.toJson());
    expect(restored.deltaJson.length, operations.length);
    expect(
      (restored.deltaJson.last as Map<String, dynamic>)['insert'],
      contains('Paragraph 5999'),
    );
  });

  testWidgets('W6 Back saves the current snapshot before closing', (tester) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final recovery = _MemorySmartEditorRecoveryStore();
    final document = SmartDocument.blank(title: 'Before back');
    await repository.save(document);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
          smartEditorRecoveryStoreProvider.overrideWithValue(recovery),
        ],
        child: _testApp(document),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await _pumpUntil(tester, find.byKey(const Key('smart-editor-title')));

    await tester.enterText(
      find.byKey(const Key('smart-editor-title')),
      'Saved before close',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await _pumpUntilAbsent(
      tester,
      find.byKey(const Key('smart-editor-title')),
    );

    expect(find.text('Open editor'), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-title')), findsNothing);
    expect((await repository.getById(document.id))?.title, 'Saved before close');
  });

  testWidgets('W6 failed primary save blocks close and keeps editor visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recovery = _MemorySmartEditorRecoveryStore();
    final repository = _FailingSmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Do not lose me');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
          smartEditorRecoveryStoreProvider.overrideWithValue(recovery),
        ],
        child: _testApp(document),
      ),
    );
    await tester.tap(find.text('Open editor'));
    final titleFinder = find.byKey(const Key('smart-editor-title'));
    await _pumpUntil(tester, titleFinder);

    await tester.enterText(titleFinder, 'Unsaved recovery copy');
    await tester.pump();
    await tester.binding.handlePopRoute();
    final failureMessage = find.text(
      'Could not save this document. Your recovery copy is still kept.',
    );
    await _pumpUntil(tester, failureMessage);

    expect(titleFinder, findsOneWidget);
    expect(failureMessage, findsWidgets);
    expect(repository.saveCalls, 1);
    final recovered = await recovery.newerSnapshotFor(document);
    expect(recovered, isNotNull);
    expect(recovered?.title, 'Unsaved recovery copy');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 120,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}.');
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 120,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) return;
  }
  final description = finder.describeMatch(Plurality.many);
  fail('Timed out waiting for $description to disappear.');
}


Widget _testApp(SmartDocument document) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', 'US')],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SmartEditorScreen(document: document),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
}

class _MemorySmartDocumentRepository implements SmartDocumentRepository {
  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<List<SmartDocument>> getAll() async => _items.values.toList();

  @override
  Future<SmartDocument?> getById(String id) async => _items[id];

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }
}

class _MemorySmartEditorRecoveryStore extends SmartEditorRecoveryStore {
  _MemorySmartEditorRecoveryStore()
    : super(directoryResolver: () async => Directory.current);

  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }

  @override
  Future<SmartDocument?> newerSnapshotFor(SmartDocument base) async {
    final recovered = _items[base.id];
    if (recovered == null || recovered.id != base.id) return null;
    if (!recovered.updatedAt.isAfter(base.updatedAt)) {
      _items.remove(base.id);
      return null;
    }
    return recovered;
  }

  @override
  Future<void> clear(String documentId) async {
    _items.remove(documentId);
  }
}

class _FailingSmartDocumentRepository implements SmartDocumentRepository {
  int saveCalls = 0;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<SmartDocument>> getAll() async => const <SmartDocument>[];

  @override
  Future<SmartDocument?> getById(String id) async => null;

  @override
  Future<void> save(SmartDocument document) async {
    saveCalls += 1;
    throw FileSystemException('Simulated write failure');
  }
}
