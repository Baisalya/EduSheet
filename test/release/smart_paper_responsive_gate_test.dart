import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/smart_paper_release_fixture.dart';

void main() {
  testWidgets('advanced Smart Paper question fits a phone authoring viewport', (
    tester,
  ) async {
    await _pumpAdvancedComposer(
      tester,
      size: const Size(360, 760),
      platform: TargetPlatform.android,
    );

    expect(find.text('Paper blocks'), findsOneWidget);
    expect(find.text('Rainfall evidence'), findsOneWidget);
    expect(find.text('Table / data'), findsOneWidget);

    final mobileTools = find.byKey(
      const ValueKey('question-mobile-authoring-tools'),
    );
    expect(mobileTools, findsOneWidget);
    expect(
      find.descendant(of: mobileTools, matching: find.text('Add')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mobileTools, matching: find.text('Math')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'advanced Smart Paper question fits an expanded Windows viewport',
    (tester) async {
      await _pumpAdvancedComposer(
        tester,
        size: const Size(1280, 900),
        platform: TargetPlatform.windows,
      );

      expect(find.text('Paper blocks'), findsOneWidget);
      expect(find.text('Rainfall evidence'), findsOneWidget);
      expect(find.text('Table / data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpAdvancedComposer(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        builder: (context, child) => MathKeyboardWrapper(child: child!),
        home: QuestionComposerPage(
          sectionId: 'release-section',
          question: SmartPaperReleaseFixture.advancedQuestion(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
