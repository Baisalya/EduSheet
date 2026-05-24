import 'dart:io';

import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:flutter/material.dart';
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
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePaperScreen())),
    );
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
}
