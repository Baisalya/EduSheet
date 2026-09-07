import 'package:edusheet/features/calculator/presentation/layout/calculator_layout_spec.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculatorLayoutSpec', () {
    test('normal compact phone stays stacked without body scrolling', () {
      final spec = CalculatorLayoutSpec.resolve(
        const BoxConstraints.tightFor(width: 360, height: 740),
      );

      expect(spec.widthClass, CalculatorWidthClass.compact);
      expect(spec.heightClass, CalculatorHeightClass.regular);
      expect(spec.splitKeypad, isFalse);
      expect(spec.scrollBody, isFalse);
      expect(spec.controlDensity, CalculatorControlDensity.comfortable);
      expect(spec.showModeStatus, isFalse);
    });

    test('small Windows free-form surface uses dense bounded scrolling', () {
      final spec = CalculatorLayoutSpec.resolve(
        const BoxConstraints.tightFor(width: 500, height: 480),
      );

      expect(spec.widthClass, CalculatorWidthClass.medium);
      expect(spec.heightClass, CalculatorHeightClass.cramped);
      expect(spec.splitKeypad, isFalse);
      expect(spec.scrollBody, isTrue);
      expect(spec.controlDensity, CalculatorControlDensity.dense);
      expect(spec.compactDisplay, isTrue);
      expect(spec.scrollKeypadHeight, 352);
    });

    test('short wide desktop keeps split keypad with dense controls', () {
      final spec = CalculatorLayoutSpec.resolve(
        const BoxConstraints.tightFor(width: 900, height: 500),
      );

      expect(spec.widthClass, CalculatorWidthClass.wide);
      expect(spec.heightClass, CalculatorHeightClass.cramped);
      expect(spec.splitKeypad, isTrue);
      expect(spec.scrollBody, isTrue);
      expect(spec.controlDensity, CalculatorControlDensity.dense);
      expect(spec.scrollKeypadHeight, 248);
    });

    test('normal desktop uses split fixed layout and status strip', () {
      final spec = CalculatorLayoutSpec.resolve(
        const BoxConstraints.tightFor(width: 1100, height: 760),
      );

      expect(spec.widthClass, CalculatorWidthClass.wide);
      expect(spec.heightClass, CalculatorHeightClass.regular);
      expect(spec.splitKeypad, isTrue);
      expect(spec.scrollBody, isFalse);
      expect(spec.controlDensity, CalculatorControlDensity.comfortable);
      expect(spec.showModeStatus, isTrue);
    });

    test('narrow laptop width does not force an unsafe split', () {
      final spec = CalculatorLayoutSpec.resolve(
        const BoxConstraints.tightFor(width: 700, height: 500),
      );

      expect(spec.widthClass, CalculatorWidthClass.medium);
      expect(spec.splitKeypad, isFalse);
      expect(spec.scrollBody, isTrue);
    });
  });
}
