import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_integer_operator_rewriter.dart';

void main() {
  group('CalculatorIntegerOperatorRewriter', () {
    const rewriter = CalculatorIntegerOperatorRewriter();

    int evaluateOperand(
      String operand, {
      required String operatorName,
      required String operandName,
    }) {
      final known = <String, int>{'(2+3)': 5, '(1+1)': 2, '5!': 120};
      return known[operand] ?? int.parse(operand);
    }

    test('rewrites grouped and factorial combinatoric operands', () {
      expect(
        rewriter.rewriteCombinatorics(
          '(2+3)C2',
          evaluateOperand: evaluateOperand,
        ),
        '10',
      );
      expect(
        rewriter.rewriteCombinatorics('5!C2', evaluateOperand: evaluateOperand),
        '7140',
      );
    });

    test('rewrites factorials and rejects out-of-range factorials', () {
      expect(
        rewriter.rewriteFactorials('5!', evaluateOperand: evaluateOperand),
        '120',
      );
      expect(
        () => rewriter.rewriteFactorials(
          '171!',
          evaluateOperand: evaluateOperand,
        ),
        throwsA(isA<CalculatorIntegerRewriteException>()),
      );
    });
  });
}
