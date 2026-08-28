import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/data/repositories/math_engine.dart';

void main() {
  group('MathEngine evaluation', () {
    final engine = MathEngine();

    test('basic arithmetic and precedence', () {
      expect(engine.evaluate('2+3'), '5');
      expect(engine.evaluate('10-4'), '6');
      expect(engine.evaluate('6×7'), '42');
      expect(engine.evaluate('20÷4'), '5');
      expect(engine.evaluate('2+3×4'), '14');
      expect(engine.evaluate('(2+3)×4'), '20');
    });

    test('formats ordinary floating point results cleanly', () {
      expect(engine.evaluate('1÷3'), '0.3333333333');
      expect(engine.evaluate('0.000000001'), '1e-9');
    });

    test('supports constants, Ans and implicit multiplication', () {
      expect(double.parse(engine.evaluate('π')).toStringAsFixed(2), '3.14');
      expect(engine.evaluate('Ans×2', ans: 12), '24');
      expect(engine.evaluate('2π'), '6.2831853072');
      expect(engine.evaluate('π2'), '6.2831853072');
      expect(engine.evaluate('3Ans', ans: 4), '12');
      expect(engine.evaluate('(2+3)(4+1)'), '25');
      expect(engine.evaluate('(2)^3'), '8');
      expect(engine.evaluate('π^2'), '9.8696044011');
      expect(engine.evaluate('e^1'), '2.7182818285');
      expect(engine.evaluate('Ans^2', ans: -3), '9');
      expect(engine.evaluate('Ans÷1', ans: 1e20), isNot('Error'));
    });

    test('supports scientific and logarithmic functions', () {
      final zeroResult = engine.evaluateDetailed('sin(0)');
      expect(zeroResult.isSuccess, isTrue);
      expect(zeroResult.value, 0.0);
      expect(zeroResult.displayText, '0');

      expect(engine.evaluate('sin(0)'), '0');
      expect(engine.evaluate('cos(0)'), '1');
      expect(engine.evaluate('log(10)'), '1');
      expect(engine.evaluate('ln(2.718281828459045)'), '1');
      expect(engine.evaluate('2EXP3'), '2000');
      expect(engine.evaluate('2EXP-3'), '0.002');
      expect(engine.evaluate('10^3'), '1000');
      expect(engine.evaluate('cbrt(27)'), '3');
      expect(engine.evaluate('sinh(0)'), '0');
      expect(engine.evaluate('cosh(0)'), '1');
      expect(engine.evaluate('tanh(0)'), '0');
      expect(engine.evaluate('sinh(1)'), isNot('Error'));
      expect(engine.evaluate('sinh(-1)'), isNot('Error'));
    });

    test('supports degree mode including nested trig functions', () {
      expect(engine.evaluate('sin(90)', angleUnit: AngleUnit.degrees), '1');
      expect(engine.evaluate('sin(90', angleUnit: AngleUnit.degrees), '1');
      expect(engine.evaluate('arcsin(1)', angleUnit: AngleUnit.degrees), '90');
      expect(
        engine.evaluate('sin(arcsin(0.5))', angleUnit: AngleUnit.degrees),
        '0.5',
      );
      expect(
        engine.evaluate('arcsin(sin(30))', angleUnit: AngleUnit.degrees),
        '30',
      );
      expect(engine.evaluate('2sin(30', angleUnit: AngleUnit.degrees), '1');
    });

    test('calculates factorial and combinatorics without the old 20 cap', () {
      expect(engine.evaluate('5!'), '120');
      expect(engine.evaluate('5C2'), '10');
      expect(engine.evaluate('5P2'), '20');
      expect(engine.evaluate('21C1'), '21');
      expect(engine.evaluate('21P1'), '21');
      expect(engine.evaluate('100C2'), '4950');
    });

    test('reports honest errors for invalid domains and overflow', () {
      expect(engine.evaluate('1÷0'), 'Error');
      expect(engine.evaluate('invalid'), 'Error');
      expect(engine.evaluate('5C9'), 'Error');
      expect(engine.evaluate('171!'), 'Error');
      expect(engine.evaluate('sqrt(-1)'), 'Error');
      expect(engine.evaluate('log(0)'), 'Error');
      expect(engine.evaluate('arcsin(2)'), 'Error');
      expect(engine.evaluate('2+3)'), 'Error');
    });

    test('detailed result distinguishes success from failure', () {
      final success = engine.evaluateDetailed('4×5');
      final failure = engine.evaluateDetailed('171!');

      expect(success.isSuccess, isTrue);
      expect(success.value, 20);
      expect(success.errorMessage, isNull);
      expect(failure.isFailure, isTrue);
      expect(failure.errorCode, CalculationErrorCode.overflow);
      expect(failure.errorMessage, isNotEmpty);
    });

    test('live preview is side-effect free and hides incomplete input', () {
      final preview = engine.evaluatePreview('25×18+100');

      expect(preview, isNotNull);
      expect(preview!.displayText, '550');
      expect(engine.evaluatePreview('25×'), isNull);
      expect(engine.evaluatePreview('sin('), isNull);
      expect(engine.evaluatePreview('1÷0'), isNull);
    });

    test('live preview supports auto-closed scientific input', () {
      final preview = engine.evaluatePreview(
        'sin(30',
        angleUnit: AngleUnit.degrees,
      );

      expect(preview, isNotNull);
      expect(preview!.displayText, '0.5');
    });
  });
}
