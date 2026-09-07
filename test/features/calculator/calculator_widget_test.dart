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

  testWidgets(
    'physical keyboard and numpad actions use calculator controller',
    (tester) async {
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
    },
  );

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
    expect(find.byKey(const ValueKey('calculator-live-preview')), findsNothing);
  });

  testWidgets('expression editor mirrors calculator selection and caret', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['1', '2', '+', '3', '4']) {
      controller.addToken(token);
    }
    controller.setSelection(1, 4);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('calculator-expression-editor')),
    );

    expect(field.readOnly, isTrue);
    expect(field.showCursor, isTrue);
    expect(field.controller!.text, '12+34');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );

    // CalculatorController intentionally debounces live preview by 100 ms.
    // Drain that production timer before the widget test ends so Flutter's
    // pending-timer invariant observes a clean teardown.
    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('tap and mouse placement update the domain caret', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['1', '2', '3', '4', '5', '6']) {
      controller.addToken(token);
    }
    await tester.pump();

    final editor = find.byKey(const ValueKey('calculator-expression-editor'));
    final rect = tester.getRect(editor);

    await tester.tapAt(Offset(rect.left + 6, rect.center.dy));
    await tester.pump();

    final stateAfterLeftTap = container.read(calculatorProvider);
    expect(
      stateAfterLeftTap.cursorOffset,
      lessThan(stateAfterLeftTap.equation.length),
    );
    expect(stateAfterLeftTap.hasSelection, isFalse);

    final caret = stateAfterLeftTap.cursorOffset;
    final beforeKeypadInsert = stateAfterLeftTap.equation;
    await tester.tap(find.text('9'));
    await tester.pump();
    final expectedAfterInsert =
        '${beforeKeypadInsert.substring(0, caret)}9${beforeKeypadInsert.substring(caret)}';
    expect(container.read(calculatorProvider).equation, expectedAfterInsert);

    final updatedRect = tester.getRect(editor);
    await tester.tapAt(Offset(updatedRect.right - 6, updatedRect.center.dy));
    await tester.pump();

    expect(
      container.read(calculatorProvider).cursorOffset,
      container.read(calculatorProvider).equation.length,
    );

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('long expression remains editable in a narrow display', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(360, 740));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (var i = 0; i < 28; i++) {
      controller.addToken(i.isEven ? '9' : '+');
    }
    await tester.pump();

    controller.moveCursorToStart();
    await tester.pump();
    expect(container.read(calculatorProvider).cursorOffset, 0);

    controller.moveCursorToEnd();
    await tester.pump();
    expect(
      container.read(calculatorProvider).cursorOffset,
      container.read(calculatorProvider).equation.length,
    );
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('hardware Backspace and Delete act on opposite caret sides', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['1', '2', '+', '3', '4']) {
      controller.addToken(token);
    }
    controller.setSelection(3);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(container.read(calculatorProvider).equation, '12+4');
    expect(container.read(calculatorProvider).cursorOffset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(container.read(calculatorProvider).equation, '124');
    expect(container.read(calculatorProvider).cursorOffset, 2);

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('Arrow Home End and Shift+Arrow update domain selection', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['1', '2', '+', '3', '4']) {
      controller.addToken(token);
    }
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(container.read(calculatorProvider).cursorOffset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(container.read(calculatorProvider).cursorOffset, 5);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final selected = container.read(calculatorProvider).selection;
    expect(selected.baseOffset, 5);
    expect(selected.extentOffset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pump();
    expect(container.read(calculatorProvider).equation, '12+9');

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('Ctrl+A selects the full expression through command mapping', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 700));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['4', '2', '+', '8']) {
      controller.addToken(token);
    }
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    final state = container.read(calculatorProvider);
    expect(state.selection.start, 0);
    expect(state.selection.end, state.equation.length);

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('short wide free-form window uses split dense layout', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(900, 500));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(
      find.byKey(const ValueKey('calculator-layout-wide-cramped-split-scroll')),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Keyboard + touch ready'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow short desktop stays stacked and scrollable', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(700, 500));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(
      find.byKey(
        const ValueKey('calculator-layout-medium-cramped-stacked-scroll'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('EXP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('free-form resize preserves expression and caret state', (
    tester,
  ) async {
    final container = await pumpCalculator(tester, const Size(500, 480));
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = container.read(calculatorProvider.notifier);
    for (final token in ['1', '2', '+', '3', '4']) {
      controller.addToken(token);
    }
    controller.setSelection(3);
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('calculator-layout-medium-cramped-stacked-scroll'),
      ),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(const Size(1100, 760));
    await tester.pump(const Duration(milliseconds: 120));

    final state = container.read(calculatorProvider);
    expect(state.equation, '12+34');
    expect(state.cursorOffset, 3);
    expect(
      find.byKey(const ValueKey('calculator-layout-wide-regular-split-fixed')),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
