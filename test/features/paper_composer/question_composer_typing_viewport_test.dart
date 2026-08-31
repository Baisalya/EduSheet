import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('question editor grows inside the page scroll surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
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
          home: const QuestionComposerPage(
            sectionId: 'section',
            initialType: QuestionType.descriptive,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.config.scrollable, isFalse);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'teacher can insert a ready formula from the shared paper composer',
    (tester) async {
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
            home: const QuestionComposerPage(
              sectionId: 'section',
              initialType: QuestionType.descriptive,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

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

      final structureBrowser = find.byKey(
        const ValueKey('math-structure-browser'),
      );
      final pythagorasLabel = find.text('Pythagoras');
      await tester.dragUntilVisible(
        pythagorasLabel,
        structureBrowser,
        const Offset(0, -180),
      );
      // dragUntilVisible stops as soon as the label enters the viewport. The
      // first visible pixels can still sit under the keyboard's bottom action
      // area, so move the card farther into the interactive region before
      // tapping its real hit target.
      await tester.drag(structureBrowser, const Offset(0, -120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final pythagorasCard = find.byKey(
        const ValueKey('math-template-math.7815fae5f495'),
      );
      expect(pythagorasCard, findsOneWidget);
      final pythagorasTapTarget = find.ancestor(
        of: pythagorasLabel,
        matching: find.byType(InkWell),
      );
      expect(pythagorasTapTarget, findsOneWidget);
      expect(tester.getCenter(pythagorasTapTarget).dy, lessThan(820));

      await tester.tap(pythagorasTapTarget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.ensureVisible(find.text('Add formula'));
      await tester.tap(find.text('Add formula'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Add math formula'), findsNothing);
      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final operations = editor.controller.document.toDelta().toJson();
      final mathOperation = operations.cast<Map<String, dynamic>>().firstWhere((
        operation,
      ) {
        final insert = operation['insert'];
        return insert is Map &&
            insert.containsKey(MathExpression.quillEmbedKey);
      });
      final mathInsert = mathOperation['insert'] as Map;
      final mathPayload = mathInsert[MathExpression.quillEmbedKey];

      expect(mathPayload, isA<String>());
      expect(mathPayload as String, contains(r'a^2 + b^2 = c^2'));
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
