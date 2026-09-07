import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_numeric_formatter.dart';

void main() {
  group('CalculatorNumericFormatter', () {
    const formatter = CalculatorNumericFormatter();

    test('preserves tiny finite values instead of collapsing them to zero', () {
      expect(formatter.format(1e-13), '1e-13');
      expect(formatter.format(-1e-13), '-1e-13');
      expect(formatter.format(1.23456789e-7), '1.23456789e-7');
      expect(formatter.format(-0.0), '0');
    });

    test('uses scientific notation consistently for large magnitudes', () {
      expect(formatter.format(1e20), '1e+20');
      expect(formatter.format(-2.5e12), '-2.5e+12');
    });

    test('serializes scientific values without colliding with Euler e', () {
      expect(formatter.serialize(1e30), '1*10^(30)');
      expect(formatter.serialize(1e-9), '1*10^(-9)');
    });
  });
}
