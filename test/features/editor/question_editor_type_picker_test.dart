import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('type picker changes question composer to multiple select', (
    tester,
  ) async {
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(QuestionType.mcq.label), findsWidgets);
    expect(find.text('Answer options'), findsOneWidget);

    await tester.tap(find.text(QuestionType.mcq.label).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'multiple select');
    await tester.pumpAndSettle();
    await tester.tap(find.text(QuestionType.multipleSelect.label));
    await tester.pumpAndSettle();

    expect(find.text(QuestionType.multipleSelect.label), findsWidgets);
    expect(
      find.text('Tap the check circles to mark every correct answer.'),
      findsOneWidget,
    );
  });
}
