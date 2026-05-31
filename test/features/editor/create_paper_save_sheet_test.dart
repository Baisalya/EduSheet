import 'dart:io';

import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('create_paper_test_');
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

  testWidgets('Create Paper save button opens PDF and Word save sheet', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: _CreatePaperTestApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Save as'), findsOneWidget);
    expect(find.text('File name'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Word'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save File'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a file name'), findsOneWidget);
  });

  testWidgets('Word Mode opens the section editor without layout errors', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: _CreatePaperTestApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Section'));
    await tester.pumpAndSettle();

    expect(find.text('Word Mode'), findsOneWidget);

    await tester.tap(find.text('Word Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Section 1 Word Mode'), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Template'), findsOneWidget);

    await tester.tap(find.text('Header'));
    await tester.pumpAndSettle();

    expect(find.text('Paper Identity'), findsOneWidget);
    expect(find.text('Header Fields'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CreatePaperTestApp extends StatelessWidget {
  const _CreatePaperTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('hi', 'IN')],
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: const CreatePaperScreen(),
    );
  }
}
