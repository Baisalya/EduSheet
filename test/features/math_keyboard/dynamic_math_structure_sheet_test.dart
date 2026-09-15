import 'package:edusheet/features/math_keyboard/domain/models/math_dynamic_structure.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/dynamic_math_structure_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matrix columns can decrease from two to one safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DynamicMathStructureSheet(
            initialKind: MathDynamicStructureKind.matrix,
          ),
        ),
      ),
    );
    await tester.pump();

    final decreaseColumns = find.byTooltip('Decrease Columns');
    expect(decreaseColumns, findsOneWidget);

    await tester.tap(decreaseColumns);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(decreaseColumns);
    await tester.pump();
    expect(tester.takeException(), isNull);

    final decreaseButton = find.ancestor(
      of: decreaseColumns,
      matching: find.byType(IconButton),
    );
    expect(decreaseButton, findsOneWidget);
    final button = tester.widget<IconButton>(decreaseButton);
    expect(button.onPressed, isNull);
  });
}
