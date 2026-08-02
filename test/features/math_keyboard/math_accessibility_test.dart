import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_key.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('math key has a readable label, touch target and keyboard action', (
    tester,
  ) async {
    var insertions = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MathKey(
              label: 'plus',
              tex: '+',
              onTap: () => insertions++,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MathKey));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byType(MathKey)).label,
      'Insert plus',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(insertions, 1);
    semantics.dispose();
  });

  testWidgets('malformed formula announces fallback instead of TeX internals', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: SafeMathExpression(
          expression: MathExpression(
            id: 'invalid',
            latex: r'\frac{1}{',
            plainText: 'one divided by an unfinished denominator',
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(SafeMathExpression));
    expect(node.label, contains('Formula needs attention'));
    expect(node.label, contains('one divided by an unfinished denominator'));
    semantics.dispose();
  });

  testWidgets('math key tolerates two-times text scaling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: MathKey(label: 'integral', tex: r'\int', onTap: _noop),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
