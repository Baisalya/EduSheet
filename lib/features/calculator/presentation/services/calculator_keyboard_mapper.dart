import 'package:flutter/services.dart';

import '../../domain/models/calculator_input_command.dart';

/// Converts desktop/web hardware-key details into platform-agnostic calculator
/// commands. The controller never needs to know about Flutter key codes.
class CalculatorKeyboardMapper {
  const CalculatorKeyboardMapper();

  CalculatorInputCommand? map({
    required LogicalKeyboardKey key,
    String? character,
    bool shiftPressed = false,
    bool controlPressed = false,
    bool metaPressed = false,
  }) {
    final shortcutModifier = controlPressed || metaPressed;

    if (shortcutModifier && key == LogicalKeyboardKey.keyA) {
      return CalculatorInputCommand.selectAll;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return CalculatorInputCommand.calculate;
    }
    if (key == LogicalKeyboardKey.backspace) {
      return CalculatorInputCommand.deleteBackward;
    }
    if (key == LogicalKeyboardKey.delete) {
      return CalculatorInputCommand.deleteForward;
    }
    if (key == LogicalKeyboardKey.escape) {
      return CalculatorInputCommand.clear;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return CalculatorInputCommand.moveCursorLeft(
        extendSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return CalculatorInputCommand.moveCursorRight(
        extendSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.home) {
      return CalculatorInputCommand.moveCursorToStart(
        extendSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.end) {
      return CalculatorInputCommand.moveCursorToEnd(
        extendSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return CalculatorInputCommand.previousHistory;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return CalculatorInputCommand.nextHistory;
    }

    if (shortcutModifier) return null;

    final numpadCommand = _mapNumpadKey(key);
    if (numpadCommand != null) return numpadCommand;

    // Prefer the produced character for printable main-keyboard input. This is
    // important for Shift+8 -> "*" and Shift+= -> "+" instead of incorrectly
    // treating those keys as the underlying digit/equal key.
    final characterCommand = _mapCharacter(character);
    if (characterCommand != null) return characterCommand;

    final digit = _fallbackDigitForKey(key);
    return digit == null ? null : CalculatorInputCommand.insertToken(digit);
  }

  CalculatorInputCommand? _mapNumpadKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.numpadAdd) {
      return const CalculatorInputCommand.insertToken('+');
    }
    if (key == LogicalKeyboardKey.numpadSubtract) {
      return const CalculatorInputCommand.insertToken('-');
    }
    if (key == LogicalKeyboardKey.numpadMultiply) {
      return const CalculatorInputCommand.insertToken('×');
    }
    if (key == LogicalKeyboardKey.numpadDivide) {
      return const CalculatorInputCommand.insertToken('÷');
    }
    if (key == LogicalKeyboardKey.numpadDecimal) {
      return const CalculatorInputCommand.insertToken('.');
    }

    final digit = _numpadDigitForKey(key);
    return digit == null ? null : CalculatorInputCommand.insertToken(digit);
  }

  CalculatorInputCommand? _mapCharacter(String? character) {
    if (character == null || character.isEmpty) return null;

    if (RegExp(r'^[0-9]$').hasMatch(character)) {
      return CalculatorInputCommand.insertToken(character);
    }

    switch (character) {
      case '+':
      case '-':
      case '(':
      case ')':
      case '.':
      case '^':
        return CalculatorInputCommand.insertToken(character);
      case '*':
        return const CalculatorInputCommand.insertToken('×');
      case '/':
        return const CalculatorInputCommand.insertToken('÷');
      case '=':
        return CalculatorInputCommand.calculate;
    }

    return null;
  }

  String? _fallbackDigitForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit0) return '0';
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    if (key == LogicalKeyboardKey.digit3) return '3';
    if (key == LogicalKeyboardKey.digit4) return '4';
    if (key == LogicalKeyboardKey.digit5) return '5';
    if (key == LogicalKeyboardKey.digit6) return '6';
    if (key == LogicalKeyboardKey.digit7) return '7';
    if (key == LogicalKeyboardKey.digit8) return '8';
    if (key == LogicalKeyboardKey.digit9) return '9';
    return null;
  }

  String? _numpadDigitForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.numpad0) return '0';
    if (key == LogicalKeyboardKey.numpad1) return '1';
    if (key == LogicalKeyboardKey.numpad2) return '2';
    if (key == LogicalKeyboardKey.numpad3) return '3';
    if (key == LogicalKeyboardKey.numpad4) return '4';
    if (key == LogicalKeyboardKey.numpad5) return '5';
    if (key == LogicalKeyboardKey.numpad6) return '6';
    if (key == LogicalKeyboardKey.numpad7) return '7';
    if (key == LogicalKeyboardKey.numpad8) return '8';
    if (key == LogicalKeyboardKey.numpad9) return '9';
    return null;
  }
}
