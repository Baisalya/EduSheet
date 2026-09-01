import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_image_attachment_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_stimulus_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_table_editor_sheet.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_word_bank_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reading and word-bank blocks use the shared math keyboard field',
    (tester) async {
      await _pump(tester, const QuestionStimulusSheet());
      expect(find.byType(MathKeyboardField), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await _pump(tester, const QuestionWordBankSheet());
      expect(find.byType(MathKeyboardField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('table cells and image descriptions are math-keyboard aware', (
    tester,
  ) async {
    await _pump(tester, const QuestionTableEditorSheet());
    expect(find.byType(MathKeyboardField), findsAtLeastNWidgets(6));
    expect(tester.takeException(), isNull);

    await _pump(tester, const QuestionImageAttachmentSheet());
    expect(find.byType(MathKeyboardField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        builder: (context, appChild) => MathKeyboardWrapper(child: appChild!),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
