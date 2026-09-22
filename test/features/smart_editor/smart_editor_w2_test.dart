import 'dart:io';

import 'package:edusheet/features/smart_editor/data/smart_document_repository.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('W2 layout, header and footer round-trip without breaking W1 JSON', () {
    final legacy = SmartDocument.fromJson(<String, dynamic>{
      'id': 'legacy',
      'title': 'Old W1 document',
      'deltaJson': const <dynamic>[
        <String, dynamic>{'insert': 'Legacy\n'},
      ],
      'pageLayout': <String, dynamic>{
        'pageSize': 'a4',
        'orientation': 'portrait',
        'marginPreset': 'normal',
      },
      'createdAt': '2026-09-21T00:00:00.000Z',
      'updatedAt': '2026-09-21T00:00:00.000Z',
    });
    expect(legacy.header.enabled, isFalse);
    expect(legacy.footer.enabled, isFalse);
    expect(
      legacy.pageLayout.borderStyle,
      SmartDocumentPageBorderStyle.subtle,
    );

    final source = legacy.copyWith(
      pageLayout: const SmartDocumentPageLayout(
        pageSize: SmartDocumentPageSize.letter,
        orientation: SmartDocumentOrientation.landscape,
        marginPreset: SmartDocumentMarginPreset.custom,
        borderStyle: SmartDocumentPageBorderStyle.doubleLine,
        customTopMargin: 42,
        customRightMargin: 54,
        customBottomMargin: 66,
        customLeftMargin: 78,
      ),
      header: const SmartDocumentHeaderFooter(
        enabled: true,
        text: 'ABC School\nHalf Yearly Examination',
        alignment: SmartDocumentHeaderFooterAlignment.center,
        showDivider: true,
      ),
      footer: const SmartDocumentHeaderFooter(
        enabled: true,
        text: 'Teacher copy',
        alignment: SmartDocumentHeaderFooterAlignment.right,
      ),
    );
    final restored = SmartDocument.fromJson(source.toJson());

    expect(restored.pageLayout.marginPreset, SmartDocumentMarginPreset.custom);
    expect(restored.pageLayout.topMarginPoints, 42);
    expect(restored.pageLayout.rightMarginPoints, 54);
    expect(restored.pageLayout.bottomMarginPoints, 66);
    expect(restored.pageLayout.leftMarginPoints, 78);
    expect(
      restored.pageLayout.borderStyle,
      SmartDocumentPageBorderStyle.doubleLine,
    );
    expect(restored.header.enabled, isTrue);
    expect(restored.header.text, contains('ABC School'));
    expect(restored.header.showDivider, isTrue);
    expect(restored.footer.alignment, SmartDocumentHeaderFooterAlignment.right);
  });

  testWidgets('W2 editor exposes header freedom and contextual properties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Layout Notes').copyWith(
      header: const SmartDocumentHeaderFooter(
        enabled: true,
        text: 'My free header',
        alignment: SmartDocumentHeaderFooterAlignment.left,
        showDivider: true,
      ),
      footer: const SmartDocumentHeaderFooter(
        enabled: true,
        text: 'My footer',
      ),
    );
    await repository.save(document);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: SmartEditorScreen(document: document),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart-editor-page-header')), findsOneWidget);
    expect(find.text('My free header'), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-page-footer')), findsOneWidget);
    expect(find.text('My footer'), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-header-footer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('smart-editor-properties')));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('smart-editor-properties-panel'));
    expect(panel, findsOneWidget);
    expect(find.byKey(const Key('smart-editor-indent-less')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-indent-more')), findsOneWidget);

    final panelScroll = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-editor-style-normal')),
      220,
      scrollable: panelScroll,
    );
    expect(find.byKey(const Key('smart-editor-style-normal')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-style-title')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-editor-page-break')),
      220,
      scrollable: panelScroll,
    );
    expect(find.byKey(const Key('smart-editor-page-break')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-section-break')), findsOneWidget);
  });

  testWidgets('manual page break is stored as a semantic Quill embed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Break Test');
    await repository.save(document);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: SmartEditorScreen(document: document),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart-editor-properties')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const Key('smart-editor-properties-panel'));
    final panelScroll = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('smart-editor-page-break')),
      220,
      scrollable: panelScroll,
    );
    await tester.tap(find.byKey(const Key('smart-editor-page-break')));
    await tester.pumpAndSettle();

    expect(find.text('Page break'), findsOneWidget);

    await tester.tap(find.byKey(const Key('smart-editor-save')));
    await tester.pumpAndSettle();
    final saved = await repository.getById(document.id);
    expect(saved, isNotNull);
    expect(_containsSmartBreak(saved!.deltaJson, 'page'), isTrue);
  });

  test('repository persists W2 document metadata', () async {
    final temp = await Directory.systemTemp.createTemp('smart-editor-w2-');
    addTearDown(() => temp.delete(recursive: true));
    final repository = LocalSmartDocumentRepository(
      fileResolver: () async => File('${temp.path}/smart.json'),
    );
    final document = SmartDocument.blank(title: 'Header Test').copyWith(
      header: const SmartDocumentHeaderFooter(
        enabled: true,
        text: 'School Header',
      ),
      pageLayout: const SmartDocumentPageLayout(
        borderStyle: SmartDocumentPageBorderStyle.solid,
      ),
    );

    await repository.save(document);
    final restored = await repository.getById(document.id);
    expect(restored?.header.text, 'School Header');
    expect(
      restored?.pageLayout.borderStyle,
      SmartDocumentPageBorderStyle.solid,
    );
  });
}

bool _containsSmartBreak(Object? value, String expectedType) {
  if (value is Map) {
    final direct = value['smartBreak'];
    if (direct?.toString() == expectedType) return true;
    for (final nested in value.values) {
      if (_containsSmartBreak(nested, expectedType)) return true;
    }
    return false;
  }
  if (value is Iterable) {
    for (final nested in value) {
      if (_containsSmartBreak(nested, expectedType)) return true;
    }
    return false;
  }
  if (value is String && value.contains('smartBreak')) {
    return value.contains(expectedType);
  }
  return false;
}

class _MemorySmartDocumentRepository implements SmartDocumentRepository {
  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<List<SmartDocument>> getAll() async => _items.values.toList();

  @override
  Future<SmartDocument?> getById(String id) async => _items[id];

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }
}
