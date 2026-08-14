class CalculatorInputEditor {
  const CalculatorInputEditor();

  static const _removableTokens = <String>[
    'arcsin(',
    'arccos(',
    'arctan(',
    'sinh(',
    'cosh(',
    'tanh(',
    'sqrt(',
    'cbrt(',
    'EXP',
    'Ans',
    '10^',
    'e^',
    '^-1',
    '^2',
    '^3',
    'log(',
    'ln(',
    'sin(',
    'cos(',
    'tan(',
  ];

  String resolveModeToken(
    String token, {
    required bool isShift,
    required bool isHyp,
  }) {
    if (token == 'sin(') {
      return isHyp ? 'sinh(' : (isShift ? 'arcsin(' : token);
    }
    if (token == 'cos(') {
      return isHyp ? 'cosh(' : (isShift ? 'arccos(' : token);
    }
    if (token == 'tan(') {
      return isHyp ? 'tanh(' : (isShift ? 'arctan(' : token);
    }
    if (token == 'sqrt(' && isShift) return 'cbrt(';
    if (token == '^2' && isShift) return '^3';
    if (token == '^' && isShift) return '^-1';
    if (token == 'log(' && isShift) return '10^';
    if (token == 'ln(' && isShift) return 'e^';
    if (token == 'C' && isShift) return 'P';
    return token;
  }

  String append(
    String expression,
    String token, {
    required bool justEvaluated,
  }) {
    if (justEvaluated) {
      if (_continuesPreviousAnswer(token)) {
        return 'Ans$token';
      }
      expression = '';
    }

    if (expression == 'Error' || expression == '0') {
      expression = '';
    }

    if (token == '.') {
      return _appendDecimal(expression);
    }

    if (_isBinaryOperatorToken(token)) {
      if (expression.isEmpty) {
        return token == '-' ? '-' : expression;
      }

      final last = expression[expression.length - 1];
      if (_isBinaryOperatorToken(last)) {
        final canStartNegativeOperand =
            token == '-' &&
            (last == '×' ||
                last == '÷' ||
                last == '*' ||
                last == '/' ||
                last == '^');
        if (canStartNegativeOperand) {
          return '$expression-';
        }
        return '${expression.substring(0, expression.length - 1)}$token';
      }
    }

    return '$expression$token';
  }

  String deleteLastToken(String expression) {
    if (expression.isEmpty) return expression;

    for (final token in _removableTokens) {
      if (expression.endsWith(token)) {
        return expression.substring(0, expression.length - token.length);
      }
    }

    return expression.substring(0, expression.length - 1);
  }

  String toggleSign(String expression) {
    if (expression.isEmpty || expression == 'Error') return '-';

    final start = _currentEntryStart(expression);
    final entry = expression.substring(start);
    if (entry.isEmpty) return '$expression-';

    return entry.startsWith('-')
        ? expression.replaceRange(start, start + 1, '')
        : expression.replaceRange(start, start, '-');
  }

  String _appendDecimal(String expression) {
    final start = _currentEntryStart(expression);
    final entry = expression.substring(start);
    if (entry.contains('.')) return expression;

    if (entry.isEmpty || entry == '-') {
      return '${expression}0.';
    }
    return '$expression.';
  }

  int _currentEntryStart(String expression) {
    for (var i = expression.length - 1; i >= 0; i--) {
      final char = expression[i];
      if (char == '(' || char == ',') return i + 1;
      if (_isBinaryOperator(expression, i)) return i + 1;
    }
    return 0;
  }

  bool _isBinaryOperator(String expression, int index) {
    final char = expression[index];
    if (!'+-×÷*/'.contains(char)) return false;
    if (index == 0) return false;
    final previous = expression[index - 1];
    return previous != '(' &&
        previous != ',' &&
        !'+-×÷*/'.contains(previous);
  }

  bool _continuesPreviousAnswer(String token) {
    return _isBinaryOperatorToken(token) ||
        token == '^2' ||
        token == '^3' ||
        token == '^-1' ||
        token == '!' ||
        token == 'C' ||
        token == 'P';
  }

  bool _isBinaryOperatorToken(String token) {
    return token == '+' ||
        token == '-' ||
        token == '×' ||
        token == '÷' ||
        token == '*' ||
        token == '/' ||
        token == '^';
  }
}
