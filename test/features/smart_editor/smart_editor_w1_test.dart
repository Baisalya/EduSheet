import 'dart:io';

import 'package:edusheet/features/paper_composer/presentation/widgets/section_format_sheet.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
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
  test('Smart Document round-trips freeform delta and page layout', () {
    final source = SmartDocument.blank(title: 'Lesson Notes').copyWith(
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Heading'},
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1},
        },
        <String, dynamic>{'insert': 'Normal paragraph\n'},
      ],
      pageLayout: const SmartDocumentPageLayout(
        pageSize: SmartDocumentPageSize.letter,
        orientation: SmartDocumentOrientation.landscape,
        marginPreset: SmartDocumentMarginPreset.narrow,
      ),
    );

    final restored = SmartDocument.fromJson(source.toJson());
    expect(restored.id, source.id);
    expect(restored.title, 'Lesson Notes');
    expect(restored.deltaJson, source.deltaJson);
    expect(restored.pageLayout.pageSize, SmartDocumentPageSize.letter);
    expect(
      restored.pageLayout.orientation,
      SmartDocumentOrientation.landscape,
    );
    expect(
      restored.pageLayout.marginPreset,
      SmartDocumentMarginPreset.narrow,
    );
  });

  test('local Smart Editor repository saves, updates and deletes documents', () async {
    final temp = await Directory.systemTemp.createTemp('smart-editor-w1-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}${Platform.pathSeparator}smart.json');
    final repository = LocalSmartDocumentRepository(
      fileResolver: () async => file,
    );
    final source = SmartDocument.blank(title: 'First');

    await repository.save(source);
    expect((await repository.getAll()).single.title, 'First');

    await repository.save(
      source.copyWith(
        title: 'Renamed',
        updatedAt: source.updatedAt.add(const Duration(minutes: 1)),
      ),
    );
    expect((await repository.getAll()).single.title, 'Renamed');

    await repository.delete(source.id);
    expect(await repository.getAll(), isEmpty);
  });

  testWidgets('W1 editor is freeform and exposes Word-style core controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Free Notes');
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

    expect(find.byKey(const Key('smart-editor-page')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-layout')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-save')), findsOneWidget);
    final titleField = tester.widget<TextField>(
      find.byKey(const Key('smart-editor-title')),
    );
    expect(titleField.controller?.text, 'Free Notes');

    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    editor.controller.replaceText(0, 0, 'Completely free paragraph', null);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('3 words'), findsOneWidget);

    final saved = await repository.getById(document.id);
    expect(saved, isNotNull);
    final savedQuill = Document.fromJson(saved!.quillOperations);
    expect(savedQuill.toPlainText(), contains('Completely free paragraph'));
  });

  testWidgets('Create Paper section formatting exposes all four line choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final section = PaperSection(id: 'section', title: 'Section 1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionFormatSheet(
            section: section,
            paperNumberingStyle: QuestionNumberStyle.number,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dividerStyle = find.byKey(const Key('section-divider-style'));
    expect(dividerStyle, findsOneWidget);

    final noneOption = find.descendant(
      of: dividerStyle,
      matching: find.text('None'),
    );
    final topOption = find.descendant(
      of: dividerStyle,
      matching: find.text('Top'),
    );
    final bottomOption = find.descendant(
      of: dividerStyle,
      matching: find.text('Bottom'),
    );
    final bothOption = find.descendant(
      of: dividerStyle,
      matching: find.text('Both'),
    );

    expect(noneOption, findsOneWidget);
    expect(topOption, findsOneWidget);
    expect(bottomOption, findsOneWidget);
    expect(bothOption, findsOneWidget);

    await tester.tap(noneOption);
    await tester.pump();
    final noneChipFinder = find.ancestor(
      of: noneOption,
      matching: find.byType(ChoiceChip),
    );
    expect(noneChipFinder, findsOneWidget);
    final noneChip = tester.widget<ChoiceChip>(noneChipFinder);
    expect(noneChip.selected, isTrue);
  });
}

class _MemorySmartDocumentRepository implements SmartDocumentRepository {
  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<List<SmartDocument>> getAll() async {
    final values = _items.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  @override
  Future<SmartDocument?> getById(String id) async => _items[id];

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }
}
