import '../models/calculator_editing_value.dart';

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

  /// Cursor/selection-aware insertion used by every calculator input surface.
  CalculatorEditingValue insert(
    CalculatorEditingValue value,
    String token, {
    required bool justEvaluated,
  }) {
    var editingValue = value.normalized();

    if (justEvaluated) {
      editingValue = _continuesPreviousAnswer(token)
          ? CalculatorEditingValue.fromText('Ans')
          : const CalculatorEditingValue();
    }

    if (editingValue.text == 'Error') {
      editingValue = const CalculatorEditingValue();
    }

    if (_shouldReplaceLeadingZero(editingValue, token)) {
      editingValue = const CalculatorEditingValue();
    }

    if (token == '.') {
      return _insertDecimal(editingValue);
    }

    if (_isBinaryOperatorToken(token)) {
      return _insertBinaryOperator(editingValue, token);
    }

    return _replaceSelection(editingValue, token);
  }

  /// Compatibility helper for callers that still model calculator input as an
  /// append-only string. New controller code uses [insert] instead.
  String append(
    String expression,
    String token, {
    required bool justEvaluated,
  }) {
    return insert(
      CalculatorEditingValue.fromText(expression),
      token,
      justEvaluated: justEvaluated,
    ).text;
  }

  CalculatorEditingValue deleteBackward(CalculatorEditingValue value) {
    final editingValue = value.normalized();
    if (editingValue.hasSelection) {
      return _replaceSelection(editingValue, '');
    }

    final cursor = editingValue.cursorOffset;
    if (cursor <= 0 || editingValue.text.isEmpty) return editingValue;

    for (final token in _removableTokens) {
      final start = cursor - token.length;
      if (start >= 0 && editingValue.text.substring(start, cursor) == token) {
        return _replaceRange(editingValue, start, cursor, '');
      }
    }

    return _replaceRange(editingValue, cursor - 1, cursor, '');
  }

  CalculatorEditingValue deleteForward(CalculatorEditingValue value) {
    final editingValue = value.normalized();
    if (editingValue.hasSelection) {
      return _replaceSelection(editingValue, '');
    }

    final cursor = editingValue.cursorOffset;
    if (cursor >= editingValue.text.length || editingValue.text.isEmpty) {
      return editingValue;
    }

    for (final token in _removableTokens) {
      final end = cursor + token.length;
      if (end <= editingValue.text.length &&
          editingValue.text.substring(cursor, end) == token) {
        return _replaceRange(editingValue, cursor, end, '');
      }
    }

    return _replaceRange(editingValue, cursor, cursor + 1, '');
  }

  /// Compatibility helper for the previous append-only delete behavior.
  String deleteLastToken(String expression) {
    return deleteBackward(CalculatorEditingValue.fromText(expression)).text;
  }

  CalculatorEditingValue toggleSignAtCaret(CalculatorEditingValue value) {
    final editingValue = value.normalized();
    final text = editingValue.text;
    final cursor = editingValue.cursorOffset;

    if (text.isEmpty || text == 'Error') {
      return CalculatorEditingValue.fromText('-');
    }

    final start = _currentEntryStartAt(text, cursor);
    if (start >= cursor) {
      return _replaceRange(editingValue, cursor, cursor, '-');
    }

    if (text[start] == '-') {
      final edited = _replaceRange(editingValue, start, start + 1, '');
      return setSelection(
        edited,
        CalculatorSelection.collapsed(
          (cursor - 1).clamp(0, edited.text.length).toInt(),
        ),
      );
    }

    final edited = _replaceRange(editingValue, start, start, '-');
    return setSelection(
      edited,
      CalculatorSelection.collapsed(
        (cursor + 1).clamp(0, edited.text.length).toInt(),
      ),
    );
  }

  /// Compatibility helper for the previous end-of-expression sign toggle.
  String toggleSign(String expression) {
    return toggleSignAtCaret(CalculatorEditingValue.fromText(expression)).text;
  }

  CalculatorEditingValue setSelection(
    CalculatorEditingValue value,
    CalculatorSelection selection,
  ) {
    final editingValue = value.normalized();
    return CalculatorEditingValue(
      text: editingValue.text,
      selection: selection.clamp(editingValue.text.length),
    );
  }

  CalculatorEditingValue moveCaretBackward(
    CalculatorEditingValue value, {
    bool extendSelection = false,
  }) {
    final editingValue = value.normalized();
    final selection = editingValue.selection;

    if (!extendSelection && !selection.isCollapsed) {
      return setSelection(
        editingValue,
        CalculatorSelection.collapsed(selection.start),
      );
    }

    final extent = selection.extentOffset;
    final nextExtent = _previousCaretOffset(editingValue.text, extent);
    return setSelection(
      editingValue,
      extendSelection
          ? CalculatorSelection(
              baseOffset: selection.baseOffset,
              extentOffset: nextExtent,
            )
          : CalculatorSelection.collapsed(nextExtent),
    );
  }

  CalculatorEditingValue moveCaretForward(
    CalculatorEditingValue value, {
    bool extendSelection = false,
  }) {
    final editingValue = value.normalized();
    final selection = editingValue.selection;

    if (!extendSelection && !selection.isCollapsed) {
      return setSelection(
        editingValue,
        CalculatorSelection.collapsed(selection.end),
      );
    }

    final extent = selection.extentOffset;
    final nextExtent = _nextCaretOffset(editingValue.text, extent);
    return setSelection(
      editingValue,
      extendSelection
          ? CalculatorSelection(
              baseOffset: selection.baseOffset,
              extentOffset: nextExtent,
            )
          : CalculatorSelection.collapsed(nextExtent),
    );
  }

  CalculatorEditingValue moveCaretToStart(
    CalculatorEditingValue value, {
    bool extendSelection = false,
  }) {
    final editingValue = value.normalized();
    return setSelection(
      editingValue,
      extendSelection
          ? CalculatorSelection(
              baseOffset: editingValue.selection.baseOffset,
              extentOffset: 0,
            )
          : const CalculatorSelection.collapsed(0),
    );
  }

  CalculatorEditingValue moveCaretToEnd(
    CalculatorEditingValue value, {
    bool extendSelection = false,
  }) {
    final editingValue = value.normalized();
    final end = editingValue.text.length;
    return setSelection(
      editingValue,
      extendSelection
          ? CalculatorSelection(
              baseOffset: editingValue.selection.baseOffset,
              extentOffset: end,
            )
          : CalculatorSelection.collapsed(end),
    );
  }

  CalculatorEditingValue _insertDecimal(CalculatorEditingValue value) {
    final selection = value.selection;
    final withoutSelection = value.text.replaceRange(
      selection.start,
      selection.end,
      '',
    );
    final cursor = selection.start;
    final entryStart = _currentEntryStartAt(withoutSelection, cursor);
    final entryEnd = _currentEntryEndAt(withoutSelection, cursor);
    final entry = withoutSelection.substring(entryStart, entryEnd);

    if (entry.contains('.')) return value;

    final shouldPrefixZero =
        cursor == entryStart ||
        (entry.startsWith('-') && cursor == entryStart + 1);
    return _replaceSelection(value, shouldPrefixZero ? '0.' : '.');
  }

  CalculatorEditingValue _insertBinaryOperator(
    CalculatorEditingValue value,
    String token,
  ) {
    var editingValue = value;
    if (editingValue.hasSelection) {
      editingValue = _replaceSelection(editingValue, '');
    }

    final text = editingValue.text;
    final cursor = editingValue.cursorOffset;

    if (text.isEmpty) {
      return token == '-'
          ? _replaceRange(editingValue, 0, 0, '-')
          : editingValue;
    }

    if (cursor > 0) {
      final previous = text[cursor - 1];
      if (_isBinaryOperatorToken(previous)) {
        final canStartNegativeOperand =
            token == '-' && _supportsNegativeOperandAfter(previous);
        if (canStartNegativeOperand) {
          if (cursor < text.length && text[cursor] == '-') {
            return editingValue;
          }
          return _replaceRange(editingValue, cursor, cursor, '-');
        }

        if (previous == '-' &&
            cursor > 1 &&
            _supportsNegativeOperandAfter(text[cursor - 2])) {
          final operatorStart = cursor - 2;
          return _replaceRange(editingValue, operatorStart, cursor - 1, token);
        }

        return _replaceRange(editingValue, cursor - 1, cursor, token);
      }
    }

    if (cursor < text.length && _isBinaryOperatorToken(text[cursor])) {
      final next = text[cursor];
      final canStartNegativeOperand =
          token == '-' && _supportsNegativeOperandAfter(next);
      if (canStartNegativeOperand) {
        return _replaceRange(editingValue, cursor + 1, cursor + 1, '-');
      }
      return _replaceRange(editingValue, cursor, cursor + 1, token);
    }

    return _replaceRange(editingValue, cursor, cursor, token);
  }

  CalculatorEditingValue _replaceSelection(
    CalculatorEditingValue value,
    String replacement,
  ) {
    final selection = value.selection;
    return _replaceRange(value, selection.start, selection.end, replacement);
  }

  CalculatorEditingValue _replaceRange(
    CalculatorEditingValue value,
    int start,
    int end,
    String replacement,
  ) {
    final safeStart = start.clamp(0, value.text.length).toInt();
    final safeEnd = end.clamp(safeStart, value.text.length).toInt();
    final text = value.text.replaceRange(safeStart, safeEnd, replacement);
    return CalculatorEditingValue(
      text: text,
      selection: CalculatorSelection.collapsed(safeStart + replacement.length),
    );
  }

  int _currentEntryStartAt(String expression, int cursor) {
    final safeCursor = cursor.clamp(0, expression.length).toInt();
    for (var i = safeCursor - 1; i >= 0; i--) {
      final char = expression[i];
      if (char == '(' || char == ',') return i + 1;
      if (_isBinaryOperator(expression, i)) return i + 1;
    }
    return 0;
  }

  int _currentEntryEndAt(String expression, int cursor) {
    final safeCursor = cursor.clamp(0, expression.length).toInt();
    for (var i = safeCursor; i < expression.length; i++) {
      final char = expression[i];
      if (char == ')' || char == ',') return i;
      if (_isBinaryOperator(expression, i)) return i;
    }
    return expression.length;
  }

  bool _isBinaryOperator(String expression, int index) {
    final char = expression[index];
    if (!'+-×÷*/'.contains(char)) return false;
    if (index == 0) return false;
    final previous = expression[index - 1];
    return previous != '(' && previous != ',' && !'+-×÷*/'.contains(previous);
  }

  int _previousCaretOffset(String text, int cursor) {
    if (cursor <= 0) return 0;
    for (final token in _removableTokens) {
      final start = cursor - token.length;
      if (start >= 0 && text.substring(start, cursor) == token) {
        return start;
      }
    }
    return cursor - 1;
  }

  int _nextCaretOffset(String text, int cursor) {
    if (cursor >= text.length) return text.length;
    for (final token in _removableTokens) {
      final end = cursor + token.length;
      if (end <= text.length && text.substring(cursor, end) == token) {
        return end;
      }
    }
    return cursor + 1;
  }

  bool _shouldReplaceLeadingZero(CalculatorEditingValue value, String token) {
    return value.text == '0' &&
        value.selection.isCollapsed &&
        value.cursorOffset == 1 &&
        RegExp(r'^[0-9]$').hasMatch(token);
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

  bool _supportsNegativeOperandAfter(String token) {
    return token == '×' ||
        token == '÷' ||
        token == '*' ||
        token == '/' ||
        token == '^';
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
