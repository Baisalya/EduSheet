import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

enum AngleUnit { radians, degrees }

class MathEngine {
  final ShuntingYardParser _parser = ShuntingYardParser(
    const ParserOptions(implicitMultiplication: true),
  );
  final ContextModel _context = ContextModel();

  String evaluate(
    String expression, {
    AngleUnit angleUnit = AngleUnit.radians,
    double ans = 0,
  }) {
    try {
      String sanitized = expression
          .trim()
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll('π', 'pi')
          .replaceAll('√(', 'sqrt(')
          .replaceAll('cbrt(', 'nrt(3,');

      if (sanitized.isEmpty) return '0';

      sanitized = _autoCloseParentheses(sanitized);
      sanitized = _insertImplicitMultiplication(sanitized);
      sanitized = _rewriteScientificNotation(sanitized);
      sanitized = _rewriteCombinatorics(sanitized);
      sanitized = _rewriteHyperbolic(sanitized);
      sanitized = _rewriteLogarithms(sanitized);
      sanitized = _applyAngleUnit(sanitized, angleUnit);
      sanitized = sanitized
          .replaceAll('Ans', '($ans)')
          .replaceAll('pi', math.pi.toString())
          .replaceAllMapped(RegExp(r'(^|[^A-Za-z])e(?=$|[^A-Za-z])'), (match) {
            return '${match.group(1)}${math.e}';
          });

      Expression exp = _parser.parse(sanitized);
      double result = exp.evaluate(EvaluationType.REAL, _context);

      if (result.abs() < 1e-12) {
        result = 0;
      }

      if (result.isInfinite || result.isNaN) {
        return 'Error';
      }

      return _formatResult(result);
    } catch (e) {
      return 'Error';
    }
  }

  String _autoCloseParentheses(String expression) {
    var depth = 0;
    for (final rune in expression.runes) {
      final char = String.fromCharCode(rune);
      if (char == '(') {
        depth++;
      } else if (char == ')' && depth > 0) {
        depth--;
      }
    }

    if (depth == 0) return expression;
    return '$expression${List.filled(depth, ')').join()}';
  }

  String _insertImplicitMultiplication(String expression) {
    const functions =
        r'sin|cos|tan|arcsin|arccos|arctan|sinh|cosh|tanh|sqrt|cbrt|log|ln|nrt';
    String rewritten = expression;

    rewritten = rewritten.replaceAllMapped(
      RegExp('([0-9.)!])(?=(pi|e|Ans|$functions)\\b|\\()'),
      (match) => '${match.group(1)}*',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(pi|e|Ans|\)|!)(?=[0-9])'),
      (match) => '${match.group(1)}*',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(pi|e|Ans|\)|!)(?=(pi|e|Ans)\b)'),
      (match) => '${match.group(1)}*',
    );

    return rewritten;
  }

  String _rewriteScientificNotation(String expression) {
    return expression.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)(?:E|EXP)([+-]?\d+)'),
      (match) => '${match.group(1)}*10^${match.group(2)}',
    );
  }

  String _rewriteCombinatorics(String expression) {
    String rewritten = expression;

    final nCrRegex = RegExp(r'(\d+)C(\d+)');
    rewritten = rewritten.replaceAllMapped(nCrRegex, (match) {
      final n = int.parse(match.group(1)!);
      final r = int.parse(match.group(2)!);
      return _nCr(n, r).toString();
    });

    final nPrRegex = RegExp(r'(\d+)P(\d+)');
    rewritten = rewritten.replaceAllMapped(nPrRegex, (match) {
      final n = int.parse(match.group(1)!);
      final r = int.parse(match.group(2)!);
      return _nPr(n, r).toString();
    });

    return rewritten;
  }

  String _rewriteHyperbolic(String expression) {
    return _rewriteFunctionCalls(expression, {
      'sinh': (x) => '((e^($x) - e^(-($x))) / 2)',
      'cosh': (x) => '((e^($x) + e^(-($x))) / 2)',
      'tanh': (x) => '((e^(2*($x)) - 1) / (e^(2*($x)) + 1))',
    });
  }

  String _rewriteLogarithms(String expression) {
    return _rewriteFunctionCalls(expression, {'log': (x) => 'log(10,$x)'});
  }

  String _applyAngleUnit(String expression, AngleUnit angleUnit) {
    if (angleUnit == AngleUnit.radians) return expression;

    const pi = '3.141592653589793';
    return _rewriteFunctionCalls(expression, {
      'sin': (x) => 'sin(($x)*$pi/180)',
      'cos': (x) => 'cos(($x)*$pi/180)',
      'tan': (x) => 'tan(($x)*$pi/180)',
      'arcsin': (x) => '(arcsin($x)*180/$pi)',
      'arccos': (x) => '(arccos($x)*180/$pi)',
      'arctan': (x) => '(arctan($x)*180/$pi)',
    });
  }

  String _rewriteFunctionCalls(
    String input,
    Map<String, String Function(String argument)> rewrites,
  ) {
    final names = rewrites.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final buffer = StringBuffer();
    var index = 0;

    while (index < input.length) {
      String? matchedName;
      for (final name in names) {
        final callPrefix = '$name(';
        final isNameBoundary =
            index == 0 || !RegExp(r'[A-Za-z]').hasMatch(input[index - 1]);
        if (isNameBoundary && input.startsWith(callPrefix, index)) {
          matchedName = name;
          break;
        }
      }

      if (matchedName == null) {
        buffer.write(input[index]);
        index++;
        continue;
      }

      final argumentStart = index + matchedName.length + 1;
      final closeIndex = _findClosingParenthesis(input, argumentStart - 1);
      if (closeIndex == -1) {
        buffer.write(input[index]);
        index++;
        continue;
      }

      final argument = input.substring(argumentStart, closeIndex);
      final rewrittenArgument = _rewriteFunctionCalls(argument, rewrites);
      buffer.write(rewrites[matchedName]!(rewrittenArgument));
      index = closeIndex + 1;
    }

    return buffer.toString();
  }

  int _findClosingParenthesis(String input, int openIndex) {
    var depth = 0;
    for (var i = openIndex; i < input.length; i++) {
      if (input[i] == '(') {
        depth++;
      }
      if (input[i] == ')') {
        depth--;
      }
      if (depth == 0) {
        return i;
      }
    }
    return -1;
  }

  String _formatResult(double result) {
    if (result == result.toInt()) {
      return result.toInt().toString();
    }

    if (result.abs() >= 1e10 || result.abs() < 1e-8) {
      return result.toStringAsExponential(8);
    }

    String resultStr = result.toStringAsFixed(10);
    while (resultStr.contains('.') &&
        (resultStr.endsWith('0') || resultStr.endsWith('.'))) {
      if (resultStr.endsWith('.')) {
        resultStr = resultStr.substring(0, resultStr.length - 1);
        break;
      }
      resultStr = resultStr.substring(0, resultStr.length - 1);
    }

    return resultStr;
  }

  double _factorial(int n) {
    if (n < 0) return 0;
    if (n > 20) return 2.432902e+18; // Cap for safety or use double
    double res = 1;
    for (int i = 2; i <= n; i++) {
      res *= i;
    }
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
        .replaceAll('Ans', r'\operatorname{Ans}')
        .replaceAll('*', r' \times ')
        .replaceAll('×', r' \times ')
        .replaceAll('/', r' \div ')
        .replaceAll('÷', r' \div ')
        .replaceAll('sqrt(', r'\sqrt{')
        .replaceAll('cbrt(', r'\sqrt[3]{')
        .replaceAll('^2', r'^2')
        .replaceAll('π', r'\pi')
        .replaceAll('sin(', r'\sin(')
        .replaceAll('cos(', r'\cos(')
        .replaceAll('tan(', r'\tan(')
        .replaceAll('arcsin(', r'\sin^{-1}(')
        .replaceAll('arccos(', r'\cos^{-1}(')
        .replaceAll('arctan(', r'\tan^{-1}(')
        .replaceAll('log(', r'\log(')
        .replaceAll('ln(', r'\ln(')
        .replaceAll('C', r'C')
        .replaceAll('P', r'P');
  }
}
