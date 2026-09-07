/// Finds calculator-sized operands around postfix/infix operators without
/// trying to replace the arithmetic parser.
///
/// It deliberately understands only the operand shapes produced by EduSheet's
/// calculator UI: numeric/constant identifiers, function calls, grouped
/// expressions, optional unary sign on right operands, and postfix factorials.
class CalculatorOperandScanner {
  const CalculatorOperandScanner();

  int findLeftOperandStart(String expression, int endExclusive) {
    if (endExclusive <= 0) return -1;

    var cursor = endExclusive;
    while (cursor > 0 && expression[cursor - 1] == '!') {
      cursor--;
    }
    if (cursor <= 0) return -1;

    final last = expression[cursor - 1];
    if (last == ')') {
      final openIndex = findOpeningParenthesis(expression, cursor - 1);
      if (openIndex == -1) return -1;
      var start = openIndex;
      while (start > 0 && _isAsciiLetter(expression[start - 1])) {
        start--;
      }
      return start;
    }

    if (_isOperandCharacter(last)) {
      var start = cursor - 1;
      while (start > 0 && _isOperandCharacter(expression[start - 1])) {
        start--;
      }
      return start;
    }

    return -1;
  }

  int findRightOperandEnd(String expression, int start) {
    if (start >= expression.length) return -1;

    var cursor = start;
    if (expression[cursor] == '+' || expression[cursor] == '-') {
      cursor++;
      if (cursor >= expression.length) return -1;
    }

    int end;
    if (expression[cursor] == '(') {
      final close = findClosingParenthesis(expression, cursor);
      if (close == -1) return -1;
      end = close + 1;
    } else if (_isAsciiLetter(expression[cursor])) {
      var identifierEnd = cursor + 1;
      while (identifierEnd < expression.length &&
          _isAsciiLetter(expression[identifierEnd])) {
        identifierEnd++;
      }
      if (identifierEnd < expression.length &&
          expression[identifierEnd] == '(') {
        final close = findClosingParenthesis(expression, identifierEnd);
        if (close == -1) return -1;
        end = close + 1;
      } else {
        end = identifierEnd;
      }
    } else if (_isDigitOrDot(expression[cursor])) {
      end = cursor + 1;
      while (end < expression.length && _isDigitOrDot(expression[end])) {
        end++;
      }
    } else {
      return -1;
    }

    while (end < expression.length && expression[end] == '!') {
      end++;
    }
    return end;
  }

  int findClosingParenthesis(String input, int openIndex) {
    var depth = 0;
    for (var i = openIndex; i < input.length; i++) {
      if (input[i] == '(') depth++;
      if (input[i] == ')') depth--;
      if (depth == 0) return i;
    }
    return -1;
  }

  int findOpeningParenthesis(String input, int closeIndex) {
    var depth = 0;
    for (var i = closeIndex; i >= 0; i--) {
      if (input[i] == ')') depth++;
      if (input[i] == '(') depth--;
      if (depth == 0) return i;
    }
    return -1;
  }

  bool _isAsciiLetter(String char) {
    return RegExp(r'[A-Za-z]').hasMatch(char);
  }

  bool _isDigitOrDot(String char) {
    return RegExp(r'[0-9.]').hasMatch(char);
  }

  bool _isOperandCharacter(String char) {
    return RegExp(r'[A-Za-z0-9.]').hasMatch(char);
  }
}
