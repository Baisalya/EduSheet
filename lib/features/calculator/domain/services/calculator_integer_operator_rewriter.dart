import '../models/calculation_result.dart';
import 'calculator_operand_scanner.dart';

typedef CalculatorIntegerOperandEvaluator =
    int Function(
      String operand, {
      required String operatorName,
      required String operandName,
    });

/// Rewrites calculator-only integer operators into parser-friendly literals.
///
/// The arithmetic parser remains responsible for normal math. This service is
/// limited to syntax it does not natively understand: postfix factorial and
/// infix nCr/nPr. Operands are evaluated by MathEngine through the supplied
/// callback, which makes grouped values and `Ans` work without introducing a
/// second parser.
class CalculatorIntegerOperatorRewriter {
  final CalculatorOperandScanner operandScanner;

  const CalculatorIntegerOperatorRewriter({
    this.operandScanner = const CalculatorOperandScanner(),
  });

  String rewriteCombinatorics(
    String expression, {
    required CalculatorIntegerOperandEvaluator evaluateOperand,
  }) {
    var rewritten = expression;
    var safety = 0;

    while (true) {
      final operatorIndex = _findCombinatoricOperator(rewritten);
      if (operatorIndex == -1) return rewritten;
      if (++safety > 64) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.unsupported,
          'Too many combinatoric operators are chained in this expression.',
        );
      }

      final leftStart = operandScanner.findLeftOperandStart(
        rewritten,
        operatorIndex,
      );
      final rightEnd = operandScanner.findRightOperandEnd(
        rewritten,
        operatorIndex + 1,
      );
      if (leftStart == -1 || rightEnd == -1) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.syntax,
          'nCr/nPr requires a value on both sides of the operator.',
        );
      }

      final operatorName = rewritten[operatorIndex] == 'C' ? 'nCr' : 'nPr';
      final n = evaluateOperand(
        rewritten.substring(leftStart, operatorIndex),
        operatorName: operatorName,
        operandName: 'n',
      );
      final r = evaluateOperand(
        rewritten.substring(operatorIndex + 1, rightEnd),
        operatorName: operatorName,
        operandName: 'r',
      );

      final result = rewritten[operatorIndex] == 'C' ? _nCr(n, r) : _nPr(n, r);
      rewritten = rewritten.replaceRange(
        leftStart,
        rightEnd,
        result.toString(),
      );
    }
  }

  String rewriteFactorials(
    String expression, {
    required CalculatorIntegerOperandEvaluator evaluateOperand,
  }) {
    var rewritten = expression;
    var safety = 0;

    while (true) {
      final factorialIndex = rewritten.indexOf('!');
      if (factorialIndex == -1) return rewritten;
      if (++safety > 64) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.unsupported,
          'Too many factorial operators are chained in this expression.',
        );
      }

      final operandStart = operandScanner.findLeftOperandStart(
        rewritten,
        factorialIndex,
      );
      if (operandStart == -1) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.syntax,
          'Factorial requires a value before !.',
        );
      }

      final n = evaluateOperand(
        rewritten.substring(operandStart, factorialIndex),
        operatorName: 'factorial',
        operandName: 'value',
      );
      if (n < 0) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.domain,
          'Factorial is defined here only for non-negative integers.',
        );
      }
      if (n > 170) {
        throw const CalculatorIntegerRewriteException(
          CalculationErrorCode.overflow,
          'Factorial results above 170! exceed the calculator numeric range.',
        );
      }

      rewritten = rewritten.replaceRange(
        operandStart,
        factorialIndex + 1,
        _factorial(n).toString(),
      );
    }
  }

  int _findCombinatoricOperator(String expression) {
    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == 'C') return i;
      if (char != 'P') continue;

      // P is also the final character of EXP. Valid EXP forms are rewritten
      // before this service runs; incomplete EXP should remain a syntax error.
      if (i >= 2 && expression.substring(i - 2, i + 1) == 'EXP') continue;
      return i;
    }
    return -1;
  }

  BigInt _factorial(int n) {
    var result = BigInt.one;
    for (var i = 2; i <= n; i++) {
      result *= BigInt.from(i);
    }
    return result;
  }

  BigInt _nCr(int n, int r) {
    if (n < 0 || r < 0 || r > n) {
      throw const CalculatorIntegerRewriteException(
        CalculationErrorCode.domain,
        'nCr requires non-negative integers with 0 ≤ r ≤ n.',
      );
    }
    final iterations = r < n - r ? r : n - r;
    _guardCombinatoricWork(iterations);

    var result = BigInt.one;
    for (var i = 1; i <= iterations; i++) {
      result = result * BigInt.from(n - iterations + i) ~/ BigInt.from(i);
    }
    _guardParserRange(result);
    return result;
  }

  BigInt _nPr(int n, int r) {
    if (n < 0 || r < 0 || r > n) {
      throw const CalculatorIntegerRewriteException(
        CalculationErrorCode.domain,
        'nPr requires non-negative integers with 0 ≤ r ≤ n.',
      );
    }
    _guardCombinatoricWork(r);

    var result = BigInt.one;
    for (var i = 0; i < r; i++) {
      result *= BigInt.from(n - i);
    }
    _guardParserRange(result);
    return result;
  }

  void _guardCombinatoricWork(int iterations) {
    if (iterations > 10000) {
      throw const CalculatorIntegerRewriteException(
        CalculationErrorCode.overflow,
        'This combinatoric operation is too large for an interactive calculation.',
      );
    }
  }

  void _guardParserRange(BigInt value) {
    if (value.toString().length > 308) {
      throw const CalculatorIntegerRewriteException(
        CalculationErrorCode.overflow,
        'The result exceeds the calculator numeric range.',
      );
    }
  }
}

class CalculatorIntegerRewriteException implements Exception {
  final CalculationErrorCode code;
  final String message;

  const CalculatorIntegerRewriteException(this.code, this.message);
}
