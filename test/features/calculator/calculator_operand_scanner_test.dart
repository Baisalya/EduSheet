import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_operand_scanner.dart';

void main() {
  group('CalculatorOperandScanner', () {
    const scanner = CalculatorOperandScanner();

    test(
      'finds grouped/function left operands including postfix factorial',
      () {
        const grouped = '(2+3)!C2';
        expect(scanner.findLeftOperandStart(grouped, grouped.indexOf('C')), 0);

        const function = 'sqrt(25)C2';
        expect(
          scanner.findLeftOperandStart(function, function.indexOf('C')),
          0,
        );
      },
    );

    test('finds signed, grouped and factorial right operands', () {
      const signed = '5C-2+9';
      expect(scanner.findRightOperandEnd(signed, signed.indexOf('C') + 1), 4);

      const grouped = '5C(1+1)!+9';
      expect(scanner.findRightOperandEnd(grouped, grouped.indexOf('C') + 1), 8);
    });
  });
}
