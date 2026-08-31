import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_section_card.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/screens/add_edit_question_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty paper section offers new question and Question Bank', (
    tester,
  ) async {
    var wrote = false;
    var openedBank = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperSectionCard(
            section: PaperSection(id: 's1', title: 'Section A'),
            sectionNumber: 1,
            onAddQuestion: () => wrote = true,
            onAddFromBank: () => openedBank = true,
            onEditQuestion: (_) {},
            onDuplicateQuestion: (_) {},
            onDeleteQuestion: (_) {},
            onSaveQuestionToBank: (_) {},
            onRename: () {},
            onEditInstruction: () {},
            onDuplicateSection: () {},
            onDeleteSection: () {},
          ),
        ),
      ),
    );

    expect(find.text('Write question'), findsOneWidget);
    expect(find.text('Choose from bank'), findsOneWidget);

    await tester.tap(find.text('Write question'));
    expect(wrote, isTrue);
    await tester.tap(find.text('Choose from bank'));
    expect(openedBank, isTrue);
  });

  testWidgets('Question Bank uses the shared teacher math Build workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
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
          supportedLocales: [Locale('en', 'US')],
          builder: (context, child) => MathKeyboardWrapper(child: child!),
          home: const AddEditQuestionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuestionComposerPage), findsOneWidget);
    expect(find.text('New bank question'), findsOneWidget);

    await tester.ensureVisible(find.text('Math'));
    await tester.tap(find.text('Math'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Add math formula'), findsOneWidget);
    _expectFormulaMathKeyboardVisible(tester);
    // The formula editor opens the custom keyboard from a post-frame callback.
    // A single long pump can execute that callback at the end of the frame,
    // leaving AnimatedSlide logically visible but still at its initial hidden
    // offset. Advance the keyboard's real 300 ms entrance animation before
    // interacting with keys so this test exercises a genuinely hit-testable UI.
    await tester.pump(const Duration(milliseconds: 350));

    final buildButton = find.byKey(const ValueKey('math-build-button'));
    expect(buildButton, findsOneWidget);
    expect(tester.getCenter(buildButton).dy, lessThan(900));

    await tester.tap(buildButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Build math faster'), findsOneWidget);
    expect(find.text('Fraction'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Pythagoras'),
      find.byKey(const ValueKey('math-structure-browser')),
      const Offset(0, -180),
    );
    expect(find.text('Pythagoras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Question Bank reopens an embedded formula in the shared editor',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const expression = MathExpression(
        id: 'bank-formula',
        latex: r'a^2 + b^2 = c^2',
        plainText: 'a squared plus b squared equals c squared',
      );
      final document = Document()
        ..insert(0, 'Use ')
        ..insert(4, MathExpressionEmbed(expression))
        ..insert(5, ' to solve.');
      final question = Question(
        id: 'bank-question',
        text: const QuestionRichTextCodec().encode(document),
        plainTextAccessibility:
            'Use a squared plus b squared equals c squared to solve.',
        mathExpressions: const [expression],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: [Locale('en', 'US')],
            builder: (context, child) => MathKeyboardWrapper(child: child!),
            home: AddEditQuestionScreen(
              question: QuestionBankQuestion.fromQuestion(question),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderedFormula = find.byType(SafeMathExpression);
      expect(renderedFormula, findsOneWidget);
      final editTarget = find.ancestor(
        of: renderedFormula,
        matching: find.byType(GestureDetector),
      );
      expect(editTarget, findsOneWidget);

      await tester.tap(editTarget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Edit math formula'), findsOneWidget);
      expect(find.byType(QuestionComposerPage), findsOneWidget);
      _expectFormulaMathKeyboardVisible(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectFormulaMathKeyboardVisible(WidgetTester tester) {
  final context = tester.element(find.byType(FormulaEditorSheet));
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(mathKeyboardControllerProvider);

  expect(state.isVisible, isTrue);
  expect(state.type, KeyboardType.math);
  expect(state.activeController, isNotNull);
  expect(state.activeFocusNode, isNotNull);
}
