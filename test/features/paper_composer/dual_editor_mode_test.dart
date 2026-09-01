import 'dart:io';

import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dual_editor_mode_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Smart and Word modes edit one shared paper', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paper-editor-mode-switch')), findsOneWidget);
    expect(find.text('Smart'), findsOneWidget);
    expect(find.text('Word'), findsOneWidget);
    expect(find.byKey(const Key('word-paper-document')), findsNothing);

    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word-paper-document')), findsOneWidget);
    expect(find.byKey(const Key('word-paper-title')), findsOneWidget);

    final titleEditor = find.descendant(
      of: find.byKey(const Key('word-paper-title')),
      matching: find.byType(TextField),
    );
    await tester.enterText(titleEditor, 'Algebra Midterm');
    await tester.pump();

    // The app bar is driven by the same EditorState as Smart Mode. A change in
    // Word Mode must therefore be observable without any import/conversion.
    expect(find.text('Algebra Midterm'), findsWidgets);

    await tester.tap(find.text('Smart'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word-paper-document')), findsNothing);
    expect(find.text('Algebra Midterm'), findsOneWidget);

    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();
    final titleField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('word-paper-title')),
        matching: find.byType(TextField),
      ),
    );
    expect(titleField.controller?.text, 'Algebra Midterm');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Word free paragraph stays in the shared paper without consuming a question',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: _TestApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Word'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('word-mode-add-section')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('word-ribbon-paragraph')), findsOneWidget);

      await tester.tap(find.byKey(const Key('word-ribbon-paragraph')));
      await tester.pumpAndSettle();

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor).first);
      editor.controller.replaceText(0, 0, 'Custom notice', null);
      await tester.pump();

      expect(find.byKey(const Key('word-ribbon-math')), findsOneWidget);
      expect(find.byKey(const Key('word-ribbon-geometry')), findsOneWidget);

      await tester.tap(find.text('Smart'));
      await tester.pumpAndSettle();

      expect(find.text('Custom notice'), findsOneWidget);
      expect(find.text('0 questions · 0 marks'), findsOneWidget);

      await tester.tap(find.text('Word'));
      await tester.pumpAndSettle();
      final restored = tester.widget<QuillEditor>(
        find.byType(QuillEditor).first,
      );
      expect(
        restored.controller.document.toPlainText(),
        contains('Custom notice'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Word Mode fits a phone viewport without a parallel paper copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word-paper-editor-scroll')), findsOneWidget);
    expect(find.byKey(const Key('word-paper-document')), findsOneWidget);
    expect(find.byKey(const Key('word-ribbon-import')), findsOneWidget);
    expect(find.text('Add section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: const CreatePaperScreen(),
    );
  }
}
