import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  testWidgets('existing formula opens visual editor before advanced source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: _FormulaEditorTestApp(
          expression: MathExpression(
            id: 'existing',
            latex: r'\sqrt{1223^{1}}',
            plainText: 'square root of 1223 to the power 1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit math formula'), findsOneWidget);
    expect(find.byType(MathField), findsOneWidget);
    expect(find.text('Formula source'), findsNothing);
    expect(find.text('Readable description *'), findsNothing);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Save formula'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.text('Formula source'), findsOneWidget);
    expect(find.text('Accessibility description (optional)'), findsOneWidget);
  });

  testWidgets(
    'formula math keyboard stays active through its local category panel',
    (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: _FormulaEditorTestApp(
            expression: MathExpression(
              id: 'session',
              latex: r'x+1',
              plainText: 'x plus 1',
            ),
            autoOpenMathKeyboard: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      _expectFormulaMathSession(tester, isVisible: true);

      await tester.tap(find.text('MORE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('More math & science keys'), findsOneWidget);
      _expectFormulaMathSession(tester, isVisible: true);

      await tester.ensureVisible(find.text('TRIG'));
      await tester.tap(find.text('TRIG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('More math & science keys'), findsNothing);
      _expectFormulaMathSession(tester, isVisible: true);

      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.pump();

      // Moving to a real editor outside the custom keyboard is still a genuine
      // focus change and must release the visual math-keyboard session.
      _expectFormulaMathSession(tester, isVisible: false);
    },
  );
}

void _expectFormulaMathSession(WidgetTester tester, {required bool isVisible}) {
  final context = tester.element(find.byType(FormulaEditorSheet));
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(mathKeyboardControllerProvider);

  expect(state.isVisible, isVisible);
  if (isVisible) {
    expect(state.type, KeyboardType.math);
    expect(state.activeController, isA<MathFieldEditingController>());
    expect(state.activeFocusNode, isNotNull);
  } else {
    expect(state.activeController, isNull);
    expect(state.activeFocusNode, isNull);
  }
}

class _FormulaEditorTestApp extends StatelessWidget {
  const _FormulaEditorTestApp({
    required this.expression,
    this.autoOpenMathKeyboard = false,
  });

  final MathExpression expression;
  final bool autoOpenMathKeyboard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: Scaffold(
        body: FormulaEditorSheet(
          initial: expression,
          autoOpenMathKeyboard: autoOpenMathKeyboard,
        ),
      ),
    );
  }
}
