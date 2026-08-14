import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:edusheet/features/calculator/presentation/widgets/scientific_calculator.dart';

void main() {
  Future<ProviderContainer> pumpCalculator(
    WidgetTester tester,
    Size size,
  ) async {
    await tester.binding.setSurfaceSize(size);
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: ScientificCalculator())),
        ),
      ),
    );
    await tester.pump();
    return container;
  }


  testWidgets('renders without overflow at compact Android width', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(360, 740));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(find.text('Scientific'), findsOneWidget);
    expect(find.text('SHIFT'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders desktop split keypad without overflow', (tester) async {
    final container = await pumpCalculator(tester, const Size(1100, 760));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(find.text('Keyboard + touch ready'), findsOneWidget);
    expect(find.text('EXP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small free-form window falls back to scrollable layout', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(500, 480));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('physical keyboard and numpad actions use calculator controller', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final state = container.read(calculatorProvider);
    expect(state.equation, '2+3');
    expect(state.result, '5');
  });

  testWidgets('shows a faded live preview before equals without committing', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump(const Duration(milliseconds: 120));

    var state = container.read(calculatorProvider);
    expect(state.previewResult, '5');
    expect(state.result, '0');
    expect(state.lastAnswer, 0);
    expect(state.history, isEmpty);
    expect(
      find.byKey(const ValueKey('calculator-live-preview')),
      findsOneWidget,
    );
    expect(find.text('≈ 5'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    state = container.read(calculatorProvider);
    expect(state.previewResult, isNull);
    expect(state.result, '5');
    expect(state.lastAnswer, 5);
    expect(state.history, hasLength(1));

    // AnimatedSwitcher intentionally keeps the outgoing preview widget mounted
    // during its fade-out. Settle that transition before asserting removal.
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calculator-live-preview')),
      findsNothing,
    );
  });
}
