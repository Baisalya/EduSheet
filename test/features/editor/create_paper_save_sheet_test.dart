import 'dart:io';

import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paper_composer_test_');
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

  testWidgets('Create Paper opens the new focused composer', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _CreatePaperTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('Create questions, not forms'), findsOneWidget);
    expect(find.text('Write first question'), findsOneWidget);
    expect(find.text('Smart'), findsOneWidget);
    expect(find.text('Word'), findsOneWidget);
    expect(find.text('Start from template'), findsNothing);
  });

  testWidgets('expanded Windows-style composer exposes outline and inspector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _CreatePaperTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('OUTLINE'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('Paper setup'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher can create a section and reach focused question editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _CreatePaperTestApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Write first question'));
    await tester.pumpAndSettle();

    expect(find.text('New question'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(
      find.text(
        'Math and diagrams are inserted exactly at the question cursor. Tap where they should appear first.',
      ),
      findsOneWidget,
    );
    expect(find.text('Formula block'), findsNothing);
    expect(find.text('Geometry'), findsOneWidget);
    expect(find.text('Answer & more details'), findsOneWidget);
    expect(find.text('Save & next'), findsOneWidget);

    await tester.tap(find.text('Math'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Add math formula'), findsOneWidget);
    expect(find.text('Formula'), findsOneWidget);
    expect(
      find.text(
        'Typing here — the next math key goes at the visible formula cursor.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add formula'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Readable description *'), findsNothing);
    // Create Paper must enter a structured MathField session. The old
    // behavior registered the Quill question body directly and converted
    // fraction/root/function keys into plain Unicode approximations.
    expect(find.byType(MathField), findsOneWidget);
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
