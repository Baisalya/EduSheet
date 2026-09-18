import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'question editor keeps ListTile ink on a Material surface in light mode',
    (tester) async {
      await _pumpComposer(tester, ThemeMode.light);
      await _openFormattingToolbar(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'question editor keeps ListTile ink on a Material surface in dark mode',
    (tester) async {
      await _pumpComposer(tester, ThemeMode.dark);
      await _openFormattingToolbar(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpComposer(WidgetTester tester, ThemeMode themeMode) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        builder: (context, child) => MathKeyboardWrapper(child: child!),
        home: const QuestionComposerPage(
          sectionId: 'section',
          initialType: QuestionType.descriptive,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _openFormattingToolbar(WidgetTester tester) async {
  final formattingButton = find.byTooltip('Text formatting');
  expect(formattingButton, findsOneWidget);
  await tester.tap(formattingButton);
  await tester.pumpAndSettle();
  expect(find.byType(QuillSimpleToolbar), findsOneWidget);
}
