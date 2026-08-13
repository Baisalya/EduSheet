import 'package:edusheet/features/editor/domain/models/math_expression.dart';
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
}

class _FormulaEditorTestApp extends StatelessWidget {
  const _FormulaEditorTestApp({required this.expression});

  final MathExpression expression;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => MathKeyboardWrapper(child: child!),
      home: Scaffold(
        body: FormulaEditorSheet(
          initial: expression,
          autoOpenMathKeyboard: false,
        ),
      ),
    );
  }
}
