class CalculatorExpressionFormatter {
  const CalculatorExpressionFormatter();

  static const _functionLatex = <String, String>{
    'arcsin': r'\sin^{-1}',
    'arccos': r'\cos^{-1}',
    'arctan': r'\tan^{-1}',
    'sinh': r'\sinh',
    'cosh': r'\cosh',
    'tanh': r'\tanh',
    'sin': r'\sin',
    'cos': r'\cos',
    'tan': r'\tan',
    'log': r'\log',
    'ln': r'\ln',
  };

  String toLatex(String expression) {
    if (expression.trim().isEmpty) return ' ';
    return _formatSegment(expression, 0, expression.length);
  }

  String _formatSegment(String input, int start, int end) {
    final output = StringBuffer();
    var index = start;

    while (index < end) {
      final function = _matchFunction(input, index, end);
      if (function != null) {
        final openIndex = index + function.length;
        final closeIndex = _findClosingParenthesis(input, openIndex, end);
        final argumentEnd = closeIndex == -1 ? end : closeIndex;
        final argument = _formatSegment(input, openIndex + 1, argumentEnd);

        if (function == 'sqrt') {
          output.write(r'\sqrt{');
          output.write(argument);
          output.write('}');
        } else if (function == 'cbrt') {
          output.write(r'\sqrt[3]{');
          output.write(argument);
          output.write('}');
        } else {
          output.write(_functionLatex[function]);
          output.write(r'\left(');
          output.write(argument);
          output.write(r'\right)');
        }

        index = closeIndex == -1 ? end : closeIndex + 1;
        continue;
      }

      if (input.startsWith('Ans', index)) {
        output.write(r'\operatorname{Ans}');
        index += 3;
        continue;
      }
      if (input.startsWith('EXP', index)) {
        output.write(r'\operatorname{EXP}');
        index += 3;
        continue;
      }

      final char = input[index];
      if (char == '^') {
        final power = _formatPower(input, index + 1, end);
        output.write('^{${power.latex}}');
        index = power.nextIndex;
        continue;
      }

      switch (char) {
        case '*':
        case '×':
          output.write(r'\,\times\,');
          break;
        case '/':
        case '÷':
          output.write(r'\,\div\,');
          break;
        case 'π':
          output.write(r'\pi');
          break;
        case '−':
          output.write('-');
          break;
        case 'C':
          output.write(r'\,\mathrm{C}\,');
          break;
        case 'P':
          output.write(r'\,\mathrm{P}\,');
          break;
        case '%':
          output.write(r'\%');
          break;
        default:
          output.write(char);
      }
      index++;
    }

    return output.toString();
  }

  String? _matchFunction(String input, int index, int end) {
    const names = <String>[
      'arcsin',
      'arccos',
      'arctan',
      'sqrt',
      'cbrt',
      'sinh',
      'cosh',
      'tanh',
      'sin',
      'cos',
      'tan',
      'log',
      'ln',
    ];

    for (final name in names) {
      final openIndex = index + name.length;
      if (openIndex < end &&
          input.startsWith(name, index) &&
          input[openIndex] == '(' &&
          (index == 0 || !_isIdentifierChar(input[index - 1]))) {
        return name;
      }
    }
    return null;
  }

  _FormattedPower _formatPower(String input, int start, int end) {
    if (start >= end) {
      return _FormattedPower('', start);
    }

    if (input[start] == '(') {
      final close = _findClosingParenthesis(input, start, end);
      if (close != -1) {
        return _FormattedPower(
          _formatSegment(input, start + 1, close),
          close + 1,
        );
      }
      return _FormattedPower(_formatSegment(input, start + 1, end), end);
    }

    var index = start;
    if (index < end && (input[index] == '-' || input[index] == '+')) {
      index++;
    }
    while (index < end && _isNumeric(input[index])) {
      index++;
    }

    if (index == start ||
        (index == start + 1 && (input[start] == '-' || input[start] == '+'))) {
      final valueStart = input[start] == '-' || input[start] == '+'
          ? start + 1
          : start;
      index = valueStart + 1 > end ? end : valueStart + 1;
    }

    return _FormattedPower(_formatSegment(input, start, index), index);
  }

  int _findClosingParenthesis(String input, int openIndex, int end) {
    var depth = 0;
    for (var i = openIndex; i < end; i++) {
      if (input[i] == '(') depth++;
      if (input[i] == ')') depth--;
      if (depth == 0) return i;
    }
    return -1;
  }

  bool _isIdentifierChar(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);

  bool _isNumeric(String char) => RegExp(r'[0-9.]').hasMatch(char);
}

class _FormattedPower {
  final String latex;
  final int nextIndex;

  const _FormattedPower(this.latex, this.nextIndex);
}
