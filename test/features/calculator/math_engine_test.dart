import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/data/repositories/math_engine.dart';

void main() {
  group('MathEngine Evaluation Tests', () {
    final engine = MathEngine();

    test('Basic Arithmetic', () {
      expect(engine.evaluate('2+3'), '5');
      expect(engine.evaluate('10-4'), '6');
      expect(engine.evaluate('6×7'), '42');
      expect(engine.evaluate('20÷4'), '5');
    });

    test('Order of Operations', () {
      expect(engine.evaluate('2+3×4'), '14');
      expect(engine.evaluate('(2+3)×4'), '20');
    });

    test('Floating Point Precision', () {
      expect(engine.evaluate('1÷3'), '0.3333333333');
    });

    test('Scientific Constants', () {
      expect(double.parse(engine.evaluate('π')).toStringAsFixed(2), '3.14');
    });

    test('Functions', () {
      // math_expressions uses radians by default
      expect(engine.evaluate('sin(0)'), '0');
      expect(engine.evaluate('cos(0)'), '1');
      expect(engine.evaluate('log(10)'), '1'); // base 10
      expect(engine.evaluate('ln(2.718281828459045)'), '1');
    });

    test('Scientific calculator operations', () {
      expect(engine.evaluate('sin(90)', angleUnit: AngleUnit.degrees), '1');
      expect(engine.evaluate('sin(90', angleUnit: AngleUnit.degrees), '1');
      expect(engine.evaluate('arcsin(1)', angleUnit: AngleUnit.degrees), '90');
      expect(engine.evaluate('5C2'), '10');
      expect(engine.evaluate('5P2'), '20');
      expect(engine.evaluate('5!'), '120');
      expect(engine.evaluate('2EXP3'), '2000');
      expect(engine.evaluate('10^3'), '1000');
      expect(engine.evaluate('cbrt(27)'), '3');
      expect(engine.evaluate('Ans×2', ans: 12), '24');
      expect(engine.evaluate('sinh(0)'), '0');
    });

    test('Calculator-style implicit input', () {
      expect(engine.evaluate('2π'), '6.2831853072');
      expect(engine.evaluate('π2'), '6.2831853072');
      expect(engine.evaluate('2sin(30', angleUnit: AngleUnit.degrees), '1');
      expect(engine.evaluate('3Ans', ans: 4), '12');
      expect(engine.evaluate('(2+3)(4+1)'), '25');
    });

    test('Error Handling', () {
      expect(engine.evaluate('1÷0'), 'Error');
      expect(engine.evaluate('invalid'), 'Error');
    });
  });
}
