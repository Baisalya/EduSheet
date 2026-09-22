import 'package:edusheet/features/smart_editor/application/smart_editor_smart_commands.dart';
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
  test('W4 slash commands and passive academic suggestions are non-destructive', () {
    final slashDocument = Document()..insert(0, '/geo');
    final slashController = QuillController(
      document: slashDocument,
      selection: const TextSelection.collapsed(offset: 4),
    );
    addTearDown(slashController.dispose);

    expect(SmartEditorSmartCommands.slashQuery(slashController), 'geo');
    expect(slashController.document.toPlainText(), contains('/geo'));

    final questionDocument = Document()
      ..insert(0, 'Question 1. Explain gravity');
    final questionController = QuillController(
      document: questionDocument,
      selection: const TextSelection.collapsed(offset: 27),
    );
    addTearDown(questionController.dispose);

    final suggestion = SmartEditorSmartCommands.suggestionFor(questionController);
    expect(suggestion, isNotNull);
    expect(suggestion?.kind, SmartEditorSuggestionKind.question);
    expect(
      questionController.document.toPlainText(),
      contains('Question 1. Explain gravity'),
    );
  });

  test('W4 reusable blocks stay ordinary editable Quill content', () {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);

    SmartEditorSmartCommands.insertReusableBlock(
      controller,
      SmartEditorReusableBlock.answerLines,
    );
    final text = controller.document.toPlainText();
    expect(text, contains('Answer:'));
    expect(text, contains('________________________________________'));
    expect(text, isNot(contains('\uFFFC')));
  });

  testWidgets('W4 Smart Editor exposes Smart/Full, quick insert and command search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'W4 Smart UX');
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

    expect(find.byKey(const Key('smart-editor-quick-insert')), findsOneWidget);
    expect(
      find.byKey(const Key('smart-editor-command-palette-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('smart-editor-ribbon-mode-toggle')), findsOneWidget);
    expect(find.text('Smart mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('smart-editor-ribbon-mode-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Full tools'), findsOneWidget);

    await tester.tap(find.byKey(const Key('smart-editor-command-palette-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('smart-editor-command-palette')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-command-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('smart-editor-command-search')),
      'answer',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('smart-editor-command-answerLines')),
      findsOneWidget,
    );
  });
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
