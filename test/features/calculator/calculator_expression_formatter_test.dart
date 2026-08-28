import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_expression_formatter.dart';

void main() {
  const formatter = CalculatorExpressionFormatter();

  group('CalculatorExpressionFormatter', () {
    test('formats inverse trig before base trig names', () {
      expect(formatter.toLatex('arcsin(1)'), r'\sin^{-1}\left(1\right)');
      expect(formatter.toLatex('arccos(0)'), r'\cos^{-1}\left(0\right)');
    });

    test('produces balanced latex for roots', () {
      expect(formatter.toLatex('sqrt(9)'), r'\sqrt{9}');
      expect(formatter.toLatex('cbrt(8)'), r'\sqrt[3]{8}');
      expect(formatter.toLatex('sqrt(9'), r'\sqrt{9}');
    });

    test('formats powers and calculator symbols structurally', () {
      expect(formatter.toLatex('2^-1'), r'2^{-1}');
      expect(formatter.toLatex('Ans×π'), contains(r'\operatorname{Ans}'));
      expect(formatter.toLatex('Ans×π'), contains(r'\times'));
      expect(formatter.toLatex('Ans×π'), contains(r'\pi'));
    });
  });
}
