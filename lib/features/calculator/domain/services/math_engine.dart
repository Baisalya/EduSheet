import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

import '../models/calculation_result.dart';
import '../models/calculator_mode.dart';
import 'calculator_integer_operator_rewriter.dart';
import 'calculator_numeric_formatter.dart';
import 'calculator_operand_scanner.dart';

class MathEngine {
  // EduSheet normalizes calculator-specific syntax before parsing, so the
  // modern grammar parser can remain the single arithmetic evaluator.
  final ExpressionParser _parser = GrammarParser();
  final ContextModel _context = ContextModel();
  final CalculatorNumericFormatter _numericFormatter;
  final CalculatorIntegerOperatorRewriter _integerOperatorRewriter =
      const CalculatorIntegerOperatorRewriter();
  final CalculatorOperandScanner _operandScanner =
      const CalculatorOperandScanner();

  static const _maxNestedEvaluationDepth = 24;
  static const _maxExactDoubleInteger = 9007199254740991.0; // 2^53 - 1

  MathEngine({
    CalculatorNumericFormatter numericFormatter =
        const CalculatorNumericFormatter(),
  }) : _numericFormatter = numericFormatter;

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
  /// still typing. It is side-effect free; callers decide whether a successful
  /// result should ever become `Ans` or enter history.
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
    return _evaluateDetailed(
      expression,
      angleUnit: angleUnit,
      ans: ans,
      evaluationDepth: 0,
    );
  }

  CalculationResult _evaluateDetailed(
    String expression, {
    required AngleUnit angleUnit,
    required double ans,
    required int evaluationDepth,
  }) {
    try {
      if (evaluationDepth > _maxNestedEvaluationDepth) {
        return const CalculationResult.failure(
          errorCode: CalculationErrorCode.unsupported,
          errorMessage:
              'The expression is nested too deeply to evaluate safely.',
        );
      }

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
        evaluationDepth: evaluationDepth,
      );

      if (prepared.isEmpty) {
        return const CalculationResult.success(value: 0, displayText: '0');
      }

      _validateSimpleDivisionByZero(
        prepared,
        angleUnit: angleUnit,
        ans: ans,
        evaluationDepth: evaluationDepth,
      );

      final parsed = _parser.parse(prepared);
      final evaluated = parsed.evaluate(EvaluationType.REAL, _context);
      if (evaluated is! num) {
        return const CalculationResult.failure(
          errorCode: CalculationErrorCode.domain,
          errorMessage: 'The expression did not produce a real number.',
        );
      }

      var value = evaluated.toDouble();
      // Only normalize IEEE negative zero. Do not globally collapse tiny finite
      // values; `1E-13` is a valid result and must remain visible.
      if (value == 0) value = 0.0;

      if (!value.isFinite) {
        return _nonFiniteFailure(prepared, value);
      }

      return CalculationResult.success(
        value: value,
        displayText: _numericFormatter.format(value),
      );
    } on CalculatorIntegerRewriteException catch (error) {
      return CalculationResult.failure(
        errorCode: error.code,
        errorMessage: error.message,
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
    required int evaluationDepth,
  }) {
    var prepared = _normalizeSymbols(expression);
    if (prepared.isEmpty) return '';

    prepared = _autoCloseParentheses(prepared);
    prepared = _rewriteScientificNotation(prepared);
    int evaluateIntegerOperand(
      String operand, {
      required String operatorName,
      required String operandName,
    }) {
      return _evaluateIntegerOperand(
        operand,
        operatorName: operatorName,
        operandName: operandName,
        angleUnit: angleUnit,
        ans: ans,
        evaluationDepth: evaluationDepth + 1,
      );
    }

    prepared = _integerOperatorRewriter.rewriteCombinatorics(
      prepared,
      evaluateOperand: evaluateIntegerOperand,
    );
    prepared = _integerOperatorRewriter.rewriteFactorials(
      prepared,
      evaluateOperand: evaluateIntegerOperand,
    );
    _validateNoCalculatorOperatorResidue(prepared);

    prepared = _insertImplicitMultiplication(prepared);
    prepared = _rewriteHyperbolic(prepared);
    prepared = _rewriteLogarithms(prepared);
    prepared = _applyAngleUnit(prepared, angleUnit);
    prepared = _replaceConstants(prepared, ans: ans);
    _validateSupportedIdentifiers(prepared);
    _validateBasicSyntax(prepared);

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
    var rewritten = expression;

    // Literal mantissas, including `.5EXP2` and `2.E3`.
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(^|[^\w.])((?:\d+(?:\.\d*)?|\.\d+))(?:E|EXP)([+-]?\d+)'),
      (match) {
        final mantissa = _canonicalizeScientificMantissa(match.group(2)!);
        return '${match.group(1)}$mantissa*10^(${match.group(3)})';
      },
    );

    // `Ans`, pi and e are also useful mantissas when the EXP key follows a
    // previous result or constant.
    rewritten = rewritten.replaceAllMapped(
      RegExp(r'(^|[^\w.])(Ans|pi|e)(?:E|EXP)([+-]?\d+)'),
      (match) => '${match.group(1)}${match.group(2)}*10^(${match.group(3)})',
    );

    return rewritten;
  }

  String _canonicalizeScientificMantissa(String mantissa) {
    if (mantissa.startsWith('.')) return '0$mantissa';
    if (mantissa.endsWith('.')) return '${mantissa}0';
    return mantissa;
  }

  int _evaluateIntegerOperand(
    String operand, {
    required String operatorName,
    required String operandName,
    required AngleUnit angleUnit,
    required double ans,
    required int evaluationDepth,
  }) {
    final directInteger = RegExp(r'^\+?\d+$').hasMatch(operand)
        ? int.tryParse(operand.replaceFirst('+', ''))
        : null;
    if (directInteger != null) return directInteger;

    final result = _evaluateDetailed(
      operand,
      angleUnit: angleUnit,
      ans: ans,
      evaluationDepth: evaluationDepth,
    );
    if (result.isFailure || result.value == null) {
      throw _CalculationException(
        result.errorCode ?? CalculationErrorCode.domain,
        '$operatorName could not evaluate its $operandName operand: '
        '${result.errorMessage ?? 'invalid value'}',
      );
    }

    final value = result.value!;
    if (!value.isFinite || value != value.truncateToDouble()) {
      throw _CalculationException(
        CalculationErrorCode.domain,
        '$operatorName requires integer operands.',
      );
    }
    if (value.abs() > _maxExactDoubleInteger) {
      throw _CalculationException(
        CalculationErrorCode.overflow,
        '$operatorName operand is too large to preserve exact integer precision.',
      );
    }
    return value.toInt();
  }

  void _validateNoCalculatorOperatorResidue(String expression) {
    if (expression.contains('EXP') || expression.contains('E')) {
      throw const _CalculationException(
        CalculationErrorCode.syntax,
        'Scientific notation requires exponent digits after EXP.',
      );
    }
    if (expression.contains('!')) {
      throw const _CalculationException(
        CalculationErrorCode.syntax,
        'Factorial syntax is incomplete.',
      );
    }
    if (expression.contains('C') || expression.contains('P')) {
      throw const _CalculationException(
        CalculationErrorCode.syntax,
        'nCr/nPr syntax is incomplete.',
      );
    }
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
    rewritten = rewritten.replaceAll(
      'Ans',
      '(${_numericFormatter.serialize(ans)})',
    );
    return rewritten;
  }

  void _validateBasicSyntax(String expression) {
    if (RegExp(r'^[*/^,.]').hasMatch(expression) ||
        RegExp(r'[+\-*/^,.]$').hasMatch(expression)) {
      throw const _CalculationException(
        CalculationErrorCode.syntax,
        'The expression ends before an operand is complete.',
      );
    }
    if (expression.contains('()') ||
        expression.contains('(,') ||
        expression.contains(',)')) {
      throw const _CalculationException(
        CalculationErrorCode.syntax,
        'A function or group is missing an operand.',
      );
    }
  }

  void _validateSupportedIdentifiers(String expression) {
    const supported = <String>{
      'sin',
      'cos',
      'tan',
      'arcsin',
      'arccos',
      'arctan',
      'sqrt',
      'nrt',
      'log',
      'ln',
    };

    for (final match in RegExp(r'[A-Za-z_]+').allMatches(expression)) {
      final identifier = match.group(0)!;
      if (!supported.contains(identifier)) {
        throw _CalculationException(
          CalculationErrorCode.unsupported,
          'Unknown symbol or variable "$identifier".',
        );
      }
    }
  }

  void _validateSimpleDivisionByZero(
    String expression, {
    required AngleUnit angleUnit,
    required double ans,
    required int evaluationDepth,
  }) {
    for (var i = 0; i < expression.length; i++) {
      if (expression[i] != '/') continue;
      final denominatorEnd = _operandScanner.findRightOperandEnd(
        expression,
        i + 1,
      );
      if (denominatorEnd == -1) continue;

      final denominatorText = expression.substring(i + 1, denominatorEnd);
      final denominator = _evaluateDetailed(
        denominatorText,
        angleUnit: angleUnit,
        ans: ans,
        evaluationDepth: evaluationDepth + 1,
      );
      if (denominator.isSuccess && denominator.value == 0) {
        throw const _CalculationException(
          CalculationErrorCode.divisionByZero,
          'Division by zero is undefined.',
        );
      }
    }
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

  bool _isIdentifierChar(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);

  CalculationResult _nonFiniteFailure(String prepared, double value) {
    if (RegExp(r'/(?:\(?[+-]?0(?:\.0*)?\)?)($|[^0-9.])').hasMatch(prepared)) {
      return const CalculationResult.failure(
        errorCode: CalculationErrorCode.divisionByZero,
        errorMessage: 'Division by zero is undefined.',
      );
    }

    if (value.isNaN ||
        prepared.contains('sqrt(') ||
        prepared.contains('arcsin(') ||
        prepared.contains('arccos(') ||
        prepared.contains('log(') ||
        prepared.contains('ln(')) {
      return const CalculationResult.failure(
        errorCode: CalculationErrorCode.domain,
        errorMessage:
            'The expression is outside the calculator numeric domain.',
      );
    }

    return const CalculationResult.failure(
      errorCode: CalculationErrorCode.overflow,
      errorMessage: 'The result exceeds the calculator numeric range.',
    );
  }
}

class _CalculationException implements Exception {
  final CalculationErrorCode code;
  final String message;

  const _CalculationException(this.code, this.message);
}
