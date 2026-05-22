import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

class MathEngine {
  final Parser _parser = Parser();
  final ContextModel _context = ContextModel();

  String evaluate(String expression) {
    try {
      String sanitized = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793');

      // Handle Factorials (x!)
      final factorialRegex = RegExp(r'(\d+)!');
      sanitized = sanitized.replaceAllMapped(factorialRegex, (match) {
        int n = int.parse(match.group(1)!);
        return _factorial(n).toString();
      });

      // Handle nCr and nPr
      final nCrRegex = RegExp(r'(\d+)C(\d+)');
      sanitized = sanitized.replaceAllMapped(nCrRegex, (match) {
        int n = int.parse(match.group(1)!);
        int r = int.parse(match.group(2)!);
        return _nCr(n, r).toString();
      });

      final nPrRegex = RegExp(r'(\d+)P(\d+)');
      sanitized = sanitized.replaceAllMapped(nPrRegex, (match) {
        int n = int.parse(match.group(1)!);
        int r = int.parse(match.group(2)!);
        return _nPr(n, r).toString();
      });

      // Hyperbolic functions - convert to exponential form for math_expressions
      // sinh(x) -> (e^(x) - e^(-x)) / 2
      sanitized = sanitized.replaceAllMapped(RegExp(r'sinh\(([^)]+)\)'), (match) {
        final x = match.group(1);
        return '((e^($x) - e^(-($x))) / 2)';
      });
      // cosh(x) -> (e^(x) + e^(-x)) / 2
      sanitized = sanitized.replaceAllMapped(RegExp(r'cosh\(([^)]+)\)'), (match) {
        final x = match.group(1);
        return '((e^($x) + e^(-($x))) / 2)';
      });
      // tanh(x) -> (e^(2x) - 1) / (e^(2x) + 1)
      sanitized = sanitized.replaceAllMapped(RegExp(r'tanh\(([^)]+)\)'), (match) {
        final x = match.group(1);
        return '((e^(2*($x)) - 1) / (e^(2*($x)) + 1))';
      });

      sanitized = sanitized.replaceAll('log(', 'LOG_INTERNAL(');
      sanitized = sanitized.replaceAll('ln(', 'LN_INTERNAL(');

      if (sanitized.contains('e')) {
        sanitized = sanitized.replaceAll('e', '2.718281828459045');
      }

      sanitized = sanitized.replaceAll('LOG_INTERNAL(', 'log(10,');
      sanitized = sanitized.replaceAll('LN_INTERNAL(', 'log(2.718281828459045,');

      Expression exp = _parser.parse(sanitized);
      double result = exp.evaluate(EvaluationType.REAL, _context);
      
      if (result.isInfinite || result.isNaN) {
        return 'Error';
      }
      
      if (result == result.toInt()) {
        return result.toInt().toString();
      }
      
      String resultStr = result.toStringAsFixed(10);
      while (resultStr.contains('.') && (resultStr.endsWith('0') || resultStr.endsWith('.'))) {
        if (resultStr.endsWith('.')) {
          resultStr = resultStr.substring(0, resultStr.length - 1);
          break;
        }
        resultStr = resultStr.substring(0, resultStr.length - 1);
      }
      
      return resultStr;
    } catch (e) {
      return 'Error';
    }
  }

  double _factorial(int n) {
    if (n < 0) return 0;
    if (n > 20) return 2.432902e+18; // Cap for safety or use double
    double res = 1;
    for (int i = 2; i <= n; i++) res *= i;
    return res;
  }

  double _nCr(int n, int r) {
    if (r < 0 || r > n) return 0;
    return _factorial(n) / (_factorial(r) * _factorial(n - r));
  }

  double _nPr(int n, int r) {
    if (r < 0 || r > n) return 0;
    return _factorial(n) / _factorial(n - r);
  }

  String toLaTeX(String expression) {
    return expression
        .replaceAll('*', r' \times ')
        .replaceAll('×', r' \times ')
        .replaceAll('/', r' \div ')
        .replaceAll('÷', r' \div ')
        .replaceAll('sqrt(', r'\sqrt{')
        .replaceAll('^2', r'^2')
        .replaceAll('pi', r'\pi')
        .replaceAll('sin(', r'\sin(')
        .replaceAll('cos(', r'\cos(')
        .replaceAll('tan(', r'\tan(')
        .replaceAll('log(', r'\log(')
        .replaceAll('ln(', r'\ln(')
        .replaceAll('C', r'C')
        .replaceAll('P', r'P');
  }
}
