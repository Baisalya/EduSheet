import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

import '../models/calculation_result.dart';
import '../models/calculator_mode.dart';

class MathEngine {
  // EduSheet normalizes implicit multiplication before parsing, so the modern
  // grammar parser can be used without relying on the legacy parser's own
  // multiplication heuristics. GrammarParser ships with math_expressions 2.7.0
  // and fixes long-standing parsing issues in the maintenance-mode parser.
  final ExpressionParser _parser = GrammarParser();
  final ContextModel _context = ContextModel();

  String evaluate(
    String expression, {
    AngleUnit angleUnit = AngleUnit.radians,
    double ans = 0,
  }) {
    return evaluateDetailed(
      expression,
      angleUnit: angleUnit,
      ans: ans,
    ).displayText;
  }

  /// Evaluates an in-progress expression for the UI's live preview.
  ///
  /// Preview evaluation is intentionally conservative: incomplete or invalid
  /// input produces no preview instead of surfacing an error while the user is
  /// still typing. It is also side-effect free; callers decide whether a
  /// successful result should ever become `Ans` or enter history.
  CalculationResult? evaluatePreview(
    String expression, {
    AngleUnit angleUnit = AngleUnit.radians,
    double ans = 0,
  }) {
    if (!_isPreviewReady(expression)) return null;

    final result = evaluateDetailed(expression, angleUnit: angleUnit, ans: ans);
    return result.isSuccess ? result : null;
  }

  CalculationResult evaluateDetailed(
    String expression, {
    AngleUnit angleUnit = AngleUnit.radians,
    double ans = 0,
  }) {
    try {
      if (!ans.isFinite) {
        return const CalculationResult.failure(
          errorCode: CalculationErrorCode.domain,
          errorMessage: 'Previous answer is not a finite number.',
        );
      }

      final prepared = _prepareExpression(
        expression,
        angleUnit: angleUnit,
        ans: ans,
      );

      if (prepared.isEmpty) {
        return const CalculationResult.success(value: 0, displayText: '0');
      }

      final parsed = _parser.parse(prepared);
      final evaluated = parsed.evaluate(EvaluationType.REAL, _context);
      if (evaluated is! num) {
        return const CalculationResult.failure(
          errorCode: CalculationErrorCode.domain,
          errorMessage: 'The expression did not produce a real number.',
        );
      }

      var value = evaluated.toDouble();
      if (value.abs() < 1e-12) {
        value = 0.0;
      }

      if (!value.isFinite) {
        return _nonFiniteFailure(prepared);
      }

      return CalculationResult.success(
        value: value,
        displayText: _formatResult(value),
      );
    } on _CalculationException catch (error) {
      return CalculationResult.failure(
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on FormatException {
      return const CalculationResult.failure(
        errorCode: CalculationErrorCode.syntax,
        errorMessage: 'The expression is not valid.',
      );
    } catch (_) {
      return const CalculationResult.failure(
        errorCode: CalculationErrorCode.unknown,
        errorMessage: 'The calculation could not be completed.',
      );
    }
  }

  bool _isPreviewReady(String expression) {
    final input = expression.trim();
    if (input.isEmpty) return false;

    // Avoid transient "Error" states for tokens that are obviously waiting
    // for another operand. Unclosed function/group parentheses are allowed;
    // evaluateDetailed() already auto-closes them, enabling useful previews
    // such as `sin(30` while the user is still entering the expression.
    if (RegExp(r'(?:[+\-×÷*/^.,]|\bEXP[+\-]?|[CP])$').hasMatch(input)) {
      return false;
    }

    if (RegExp(
      r'(?:^|[^A-Za-z])(?:sin|cos|tan|arcsin|arccos|arctan|sinh|cosh|tanh|sqrt|cbrt|log|ln|nrt)\($',
    ).hasMatch(input)) {
      return false;
    }

    if (input == '-' || input == '+' || input == '.') return false;
    return true;
  }

  String _prepareExpression(
    String expression, {
    required AngleUnit angleUnit,
    required double ans,
  }) {
    var prepared = _normalizeSymbols(expression);
    if (prepared.isEmpty) return '';

    prepared = _autoCloseParentheses(prepared);
    prepared = _rewriteScientificNotation(prepared);
    prepared = _rewriteCombinatorics(prepared);
    prepared = _rewriteLiteralFactorials(prepared);
    prepared = _insertImplicitMultiplication(prepared);
    prepared = _rewriteHyperbolic(prepared);
    prepared = _rewriteLogarithms(prepared);
    prepared = _applyAngleUnit(prepared, angleUnit);
    prepared = _replaceConstants(prepared, ans: ans);

    return prepared;
  }

  String _normalizeSymbols(String expression) {
    return expression
        .trim()
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('π', 'pi')
        .replaceAll('√(', 'sqrt(')
        .replaceAll('∛(', 'cbrt(')
        .replaceAll('cbrt(', 'nrt(3,');
  }

  String _autoCloseParentheses(String expression) {
    var depth = 0;
    for (final rune in expression.runes) {
      final char = String.fromCharCode(rune);
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
        if (depth < 0) {
          throw const _CalculationException(
            CalculationErrorCode.syntax,
            'There is a closing parenthesis without a matching opening parenthesis.',
          );
        }
      }
    }

    if (depth == 0) return expression;
    return '$expression${List.filled(depth, ')').join()}';
  }

  String _rewriteScientificNotation(String expression) {
    return expression.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)(?:E|EXP)([+-]?\d+)'),
      (match) => '${match.group(1)}*10^(${match.group(2)})',
    );
  }

  String _rewriteCombinatorics(String expression) {
    var rewritten = expression;

    rewritten = rewritten.replaceAllMapped(RegExp(r'(^|[^\w.])(\d+)C(\d+)'), (
      match,
    ) {
      final n = int.parse(match.group(2)!);
      final r = int.parse(match.group(3)!);
      return '${match.group(1)}${_nCr(n, r)}';
    });

    rewritten = rewritten.replaceAllMapped(RegExp(r'(^|[^\w.])(\d+)P(\d+)'), (
      match,
    ) {
      final n = int.parse(match.group(2)!);
      final r = int.parse(match.group(3)!);
      return '${match.group(1)}${_nPr(n, r)}';
    });

    return rewritten;
  }

  String _rewriteLiteralFactorials(String expression) {
    return expression.replaceAllMapped(RegExp(r'(^|[^\w.])(\d+)!'), (match) {
      final n = int.parse(match.group(2)!);
      if (n > 170) {
        throw const _CalculationException(
          CalculationErrorCode.overflow,
          'Factorial results above 170! exceed the calculator numeric range.',
        );
      }
      return '${match.group(1)}${_factorial(n)}';
    });
  }

  String _insertImplicitMultiplication(String expression) {
    const functions =
        r'sin|cos|tan|arcsin|arccos|arctan|sinh|cosh|tanh|sqrt|cbrt|log|ln|nrt';
    var rewritten = expression;

    rewritten = rewritten.replaceAllMapped(
      RegExp('([0-9.)!])(?=(π|pi|e|Ans|$functions)\\b|\\()'),
      (match) => '${match.group(1)}*',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(π|pi|e|Ans|\)|!)(?=[0-9])'),
      (match) => '${match.group(1)}*',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(π|pi|e|Ans|\)|!)(?=(π|pi|e|Ans)\b)'),
      (match) => '${match.group(1)}*',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp('(?:π|pi|e|Ans|\\))(?=($functions)\\b|\\()'),
      (match) => '${match.group(0)}*',
    );

    return rewritten;
  }

  String _rewriteHyperbolic(String expression) {
    return _rewriteFunctionCalls(expression, {
      // Avoid a unary-minus exponent (e^(-x)) here. The legacy
      // ShuntingYardParser has special handling around unary minus and powers,
      // so expressing the same exponent as (0 - x) is more robust while
      // preserving the exact hyperbolic identities.
      'sinh': (x) => '((e^($x)-e^((0)-($x)))/2)',
      'cosh': (x) => '((e^($x)+e^((0)-($x)))/2)',
      'tanh': (x) => '((e^(2*($x))-1)/(e^(2*($x))+1))',
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

  String _replaceConstants(String expression, {required double ans}) {
    var rewritten = expression.replaceAll('π', '(${math.pi})');
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(^|[^A-Za-z])pi(?=$|[^A-Za-z])'),
      (match) => '${match.group(1)}(${math.pi})',
    );
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(^|[^A-Za-z])e(?=$|[^A-Za-z])'),
      (match) => '${match.group(1)}(${math.e})',
    );
    rewritten = rewritten.replaceAll('Ans', '(${_serializeNumber(ans)})');
    return rewritten;
  }

  String _serializeNumber(double value) {
    final text = value.toString();
    final exponentMarker = text.contains('e')
        ? 'e'
        : (text.contains('E') ? 'E' : null);
    if (exponentMarker == null) return text;

    final parts = text.split(exponentMarker);
    if (parts.length != 2) return text;
    final exponent = int.tryParse(parts[1]);
    if (exponent == null) return text;
    return '${parts[0]}*10^($exponent)';
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
        final prefix = '$name(';
        final isBoundary = index == 0 || !_isIdentifierChar(input[index - 1]);
        if (isBoundary && input.startsWith(prefix, index)) {
          matchedName = name;
          break;
        }
      }

      if (matchedName == null) {
        buffer.write(input[index]);
        index++;
        continue;
      }

      final openIndex = index + matchedName.length;
      final closeIndex = _findClosingParenthesis(input, openIndex);
      if (closeIndex == -1) {
        throw const _CalculationException(
          CalculationErrorCode.syntax,
          'A function call is missing its closing parenthesis.',
        );
      }

      final argumentStart = openIndex + 1;
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
      if (input[i] == '(') depth++;
      if (input[i] == ')') depth--;
      if (depth == 0) return i;
    }
    return -1;
  }

  bool _isIdentifierChar(String char) {
    return RegExp(r'[A-Za-z0-9_]').hasMatch(char);
  }

  CalculationResult _nonFiniteFailure(String prepared) {
    if (RegExp(r'/(?:\(?0(?:\.0*)?\)?)($|[^0-9.])').hasMatch(prepared)) {
      return const CalculationResult.failure(
        errorCode: CalculationErrorCode.divisionByZero,
        errorMessage: 'Division by zero is undefined.',
      );
    }
    return const CalculationResult.failure(
      errorCode: CalculationErrorCode.domain,
      errorMessage: 'The expression is outside the calculator numeric domain.',
    );
  }

  String _formatResult(double result) {
    if (result == result.truncateToDouble() && result.abs() < 1e21) {
      return result.toInt().toString();
    }

    final absolute = result.abs();
    if (absolute >= 1e10 || (absolute > 0 && absolute < 1e-8)) {
      return _trimExponential(result.toStringAsExponential(10));
    }

    var resultText = result.toStringAsFixed(10);
    while (resultText.contains('.') && resultText.endsWith('0')) {
      resultText = resultText.substring(0, resultText.length - 1);
    }
    if (resultText.endsWith('.')) {
      resultText = resultText.substring(0, resultText.length - 1);
    }
    return resultText;
  }

  String _trimExponential(String value) {
    final parts = value.split('e');
    var mantissa = parts[0];
    while (mantissa.contains('.') && mantissa.endsWith('0')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
    }
    if (mantissa.endsWith('.')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
    }
    final exponent = int.parse(parts[1]);
    return '${mantissa}e${exponent >= 0 ? '+' : ''}$exponent';
  }

  BigInt _factorial(int n) {
    var result = BigInt.one;
    for (var i = 2; i <= n; i++) {
      result *= BigInt.from(i);
    }
    return result;
  }

  BigInt _nCr(int n, int r) {
    if (r < 0 || r > n) {
      throw const _CalculationException(
        CalculationErrorCode.domain,
        'nCr requires 0 ≤ r ≤ n.',
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
    if (r < 0 || r > n) {
      throw const _CalculationException(
        CalculationErrorCode.domain,
        'nPr requires 0 ≤ r ≤ n.',
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
      throw const _CalculationException(
        CalculationErrorCode.overflow,
        'This combinatoric operation is too large for an interactive calculation.',
      );
    }
  }

  void _guardParserRange(BigInt value) {
    if (value.toString().length > 308) {
      throw const _CalculationException(
        CalculationErrorCode.overflow,
        'The result exceeds the calculator numeric range.',
      );
    }
  }
}

class _CalculationException implements Exception {
  final CalculationErrorCode code;
  final String message;

  const _CalculationException(this.code, this.message);
}
