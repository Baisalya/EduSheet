import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/models/calculator_mode.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';

void main() {
  group('CalculatorController', () {
    late CalculatorController controller;

    setUp(() {
      controller = CalculatorController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('calculates and stores typed expression/result history', () {
      controller.addToken('2');
      controller.addToken('+');
      controller.addToken('3');
      controller.calculate();

      expect(controller.state.result, '5');
      expect(controller.state.lastAnswer, 5);
      expect(controller.state.justEvaluated, isTrue);
      expect(controller.state.history, hasLength(1));
      expect(controller.state.history.single.expression, '2+3');
      expect(controller.state.history.single.result, '5');
    });

    test('shift is one-shot and changes the actual inserted token', () {
      controller.toggleShift();
      controller.addToken('sin(');

      expect(controller.state.equation, 'arcsin(');
      expect(controller.state.isShift, isFalse);
    });

    test('operator after equals continues from Ans while number starts fresh', () {
      controller.addToken('2');
      controller.addToken('+');
      controller.addToken('3');
      controller.calculate();
      controller.addToken('×');

      expect(controller.state.equation, 'Ans×');

      controller.clear();
      controller.addToken('4');
      controller.calculate();
      controller.addToken('7');
      expect(controller.state.equation, '7');
    });

    test('history navigation preserves the draft expression', () {
      controller.addToken('1');
      controller.addToken('+');
      controller.addToken('1');
      controller.calculate();
      controller.clear();
      controller.addToken('2');
      controller.addToken('+');
      controller.addToken('2');
      controller.calculate();
      controller.clear();
      controller.addToken('9');

      controller.previousHistory();
      expect(controller.state.equation, '2+2');
      controller.previousHistory();
      expect(controller.state.equation, '1+1');
      controller.nextHistory();
      expect(controller.state.equation, '2+2');
      controller.nextHistory();
      expect(controller.state.equation, '9');
    });

    test('history restores angle mode with reused calculation', () {
      controller.toggleAngleUnit();
      expect(controller.state.angleUnit, AngleUnit.degrees);
      controller.addToken('sin(');
      controller.addToken('9');
      controller.addToken('0');
      controller.calculate();
      final entry = controller.state.history.single;

      controller.toggleAngleUnit();
      expect(controller.state.angleUnit, AngleUnit.radians);
      controller.reuseHistory(entry);
      expect(controller.state.angleUnit, AngleUnit.degrees);
      expect(controller.state.result, '1');
    });

    test('errors expose a useful message and are not added to history', () {
      controller.addToken('1');
      controller.addToken('÷');
      controller.addToken('0');
      controller.calculate();

      expect(controller.state.result, 'Error');
      expect(controller.state.errorMessage, isNotEmpty);
      expect(controller.state.history, isEmpty);
    });

    test('live preview never commits Ans or history before equals', () async {
      final previewController = CalculatorController(
        previewDebounce: Duration.zero,
      );
      addTearDown(previewController.dispose);

      previewController.addToken('2');
      previewController.addToken('+');
      previewController.addToken('3');
      await Future<void>.delayed(Duration.zero);

      expect(previewController.state.previewResult, '5');
      expect(previewController.state.result, '0');
      expect(previewController.state.lastAnswer, 0);
      expect(previewController.state.history, isEmpty);

      previewController.calculate();

      expect(previewController.state.previewResult, isNull);
      expect(previewController.state.result, '5');
      expect(previewController.state.lastAnswer, 5);
      expect(previewController.state.history, hasLength(1));
    });

    test('live preview hides incomplete input and reacts to DEG/RAD', () async {
      final previewController = CalculatorController(
        previewDebounce: Duration.zero,
      );
      addTearDown(previewController.dispose);

      previewController.addToken('2');
      previewController.addToken('+');
      await Future<void>.delayed(Duration.zero);
      expect(previewController.state.previewResult, isNull);

      previewController.clear();
      previewController.toggleAngleUnit();
      previewController.addToken('sin(');
      previewController.addToken('3');
      previewController.addToken('0');
      await Future<void>.delayed(Duration.zero);

      expect(previewController.state.angleUnit, AngleUnit.degrees);
      expect(previewController.state.previewResult, '0.5');
      expect(previewController.state.history, isEmpty);
    });
  });
}
