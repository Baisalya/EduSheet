import 'dart:io';

import 'package:edusheet/features/editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('edusheet_rc1_gate_');
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

  testWidgets('RC1 keeps primary Word authoring reachable on a 360px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: _RcTestApp(platform: TargetPlatform.android)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    final addSection = find.byKey(const Key('word-mode-add-section'));
    expect(addSection, findsOneWidget);
    final addSectionRect = tester.getRect(addSection);
    expect(addSectionRect.top, greaterThanOrEqualTo(0));
    expect(addSectionRect.bottom, lessThanOrEqualTo(760));

    await tester.tap(addSection);
    await tester.pumpAndSettle();

    final paragraph = find.byKey(const Key('word-ribbon-paragraph'));
    expect(paragraph, findsOneWidget);
    final paragraphRect = tester.getRect(paragraph);
    expect(paragraphRect.left, greaterThanOrEqualTo(0));
    expect(paragraphRect.right, lessThanOrEqualTo(360));

    await tester.tap(paragraph);
    await tester.pumpAndSettle();

    expect(find.byType(QuillEditor), findsWidgets);
    expect(find.byKey(const Key('word-ribbon-math')), findsOneWidget);
    expect(find.byKey(const Key('word-ribbon-geometry')), findsOneWidget);
    expect(find.byKey(const Key('word-ribbon-import')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RC1 Word surface survives narrow free-form Windows sizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: _RcTestApp(platform: TargetPlatform.windows)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('word-paper-document')), findsOneWidget);
    expect(find.byKey(const Key('word-paper-editor-scroll')), findsOneWidget);
    expect(find.byKey(const Key('word-ribbon-paragraph')), findsOneWidget);
    expect(find.byKey(const Key('word-ribbon-import')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('RC1 has deterministic offline font plans for release platforms', () {
    final windows = PdfExportThemeService.candidatePathsForOperatingSystem(
      'windows',
    );
    final android = PdfExportThemeService.candidatePathsForOperatingSystem(
      'android',
    );

    expect(windows, contains(r'C:\Windows\Fonts\Nirmala.ttf'));
    expect(windows, contains(r'C:\Windows\Fonts\segoeui.ttf'));
    expect(windows, contains(r'C:\Windows\Fonts\mangal.ttf'));
    expect(windows, contains(r'C:\Windows\Fonts\kalinga.ttf'));
    expect(windows, contains(r'C:\Windows\Fonts\seguisym.ttf'));
    expect(android, contains('/system/fonts/NotoSans-Regular.ttf'));
    expect(android, contains('/system/fonts/NotoSansMath-Regular.ttf'));
    expect(android.any((path) => path.contains('NotoSansOriya')), isTrue);
  });
}

class _RcTestApp extends StatelessWidget {
  const _RcTestApp({required this.platform});

  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
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
