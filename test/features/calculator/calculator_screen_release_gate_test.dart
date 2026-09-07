import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:edusheet/features/calculator/presentation/screens/calculator_screen.dart';

void main() {
  Future<ProviderContainer> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalculatorScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'desktop screen solves formula, inserts result and exposes history',
    (tester) async {
      final container = await pumpScreen(tester, const Size(1100, 760));
      addTearDown(container.dispose);

      final screenContext = tester.element(find.byType(CalculatorScreen));
      expect(MediaQuery.sizeOf(screenContext).width, 1100);

      await tester.tap(find.byTooltip('Science formulas'));
      await tester.pumpAndSettle();
      expect(find.text('Science Formulas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calculator-formula-route-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('formula-catalog-title-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calculator-formula-route-sheet')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey("formula-tile-Newton's Second Law")),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('formula-input-m')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('formula-input-a')),
        '3',
      );
      await tester.tap(find.byKey(const ValueKey('formula-solver-calculate')));
      await tester.pump();
      expect(find.text('F = 6 N'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('formula-solver-insert-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert result'));
      await tester.pumpAndSettle();

      expect(find.text('Science Formulas'), findsNothing);
      expect(container.read(calculatorProvider).equation, '6');

      container.read(calculatorProvider.notifier).calculate();
      await tester.pump();
      expect(container.read(calculatorProvider).result, '6');

      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      expect(find.text('Calculation History'), findsOneWidget);
      expect(find.text('= 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop screen can insert the resolved calculation expression', (
    tester,
  ) async {
    final container = await pumpScreen(tester, const Size(1100, 760));
    addTearDown(container.dispose);

    await tester.tap(find.byTooltip('Science formulas'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calculator-formula-route-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('formula-catalog-title-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey("formula-tile-Newton's Second Law")),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('formula-input-m')), '2');
    await tester.enterText(find.byKey(const ValueKey('formula-input-a')), '3');
    await tester.tap(find.byKey(const ValueKey('formula-solver-calculate')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('formula-solver-insert-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert calculation'));
    await tester.pumpAndSettle();

    expect(container.read(calculatorProvider).equation, '((2)*(3))');
    container.read(calculatorProvider.notifier).calculate();
    await tester.pump();
    expect(container.read(calculatorProvider).result, '6');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact screen opens formula catalog through adaptive modal path',
    (tester) async {
      final container = await pumpScreen(tester, const Size(390, 800));
      addTearDown(container.dispose);

      final screenContext = tester.element(find.byType(CalculatorScreen));
      expect(MediaQuery.sizeOf(screenContext).width, 390);

      await tester.tap(find.byTooltip('Science formulas'));
      await tester.pumpAndSettle();

      expect(find.text('Science Formulas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calculator-formula-route-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('formula-catalog-title-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('formula-catalog-drag-handle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calculator-formula-route-dialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('formula-tile-Average Velocity')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
