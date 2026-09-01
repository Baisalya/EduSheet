import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'new question can inherit section marks and choose option layout',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', 'US')],
            home: MathKeyboardWrapper(
              child: QuestionComposerPage(
                sectionId: 'section',
                initialType: QuestionType.mcq,
                initialMarks: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final marksFinder = find.widgetWithText(TextField, 'Marks');
      expect(marksFinder, findsOneWidget);
      expect(tester.widget<TextField>(marksFinder).controller?.text, '5');

      for (final layout in QuestionOptionLayout.values) {
        expect(
          find.byKey(ValueKey('question-option-layout-${layout.name}')),
          findsOneWidget,
        );
      }

      final twoColumnFinder = find.byKey(
        const ValueKey('question-option-layout-twoColumn'),
      );
      await tester.ensureVisible(twoColumnFinder);
      await tester.pumpAndSettle();
      await tester.tap(twoColumnFinder);
      await tester.pump();

      final twoColumnChip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('question-option-layout-twoColumn')),
      );
      expect(twoColumnChip.selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
