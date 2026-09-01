import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile composer leads with free writing and optional helpers', (
    tester,
  ) async {
    await _pumpComposer(tester);

    expect(find.text('Write freely'), findsOneWidget);
    expect(find.text('Quick start'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Question type'), findsNothing);

    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add to question'), findsOneWidget);
    expect(find.text('Blank line'), findsOneWidget);
    expect(find.text('Sub-question'), findsOneWidget);
    expect(find.text('OR separator'), findsOneWidget);
    expect(find.text('Answer options'), findsOneWidget);
    expect(find.text('Passage / poem / case study'), findsOneWidget);
    expect(find.text('Word bank'), findsOneWidget);
    expect(find.text('Table / data'), findsOneWidget);
    expect(find.text('Image / chart / map'), findsOneWidget);
    expect(find.text('Structured question part'), findsOneWidget);
    expect(find.text('Internal OR choice'), findsOneWidget);
    expect(find.text('Answer space'), findsOneWidget);
    expect(find.text('Quick start helper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'answer options are added as a helper instead of a required type',
    (tester) async {
      await _pumpComposer(tester);

      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Answer options'));
      await tester.pumpAndSettle();

      expect(find.text('Answer options'), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);
      expect(find.text('Option D'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpComposer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: [
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
}
