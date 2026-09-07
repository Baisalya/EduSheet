import 'package:edusheet/features/calculator/domain/models/calculator_input_command.dart';
import 'package:edusheet/features/calculator/presentation/services/calculator_keyboard_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = CalculatorKeyboardMapper();

  group('CalculatorKeyboardMapper', () {
    test('distinguishes backward and forward delete', () {
      expect(
        mapper.map(key: LogicalKeyboardKey.backspace),
        CalculatorInputCommand.deleteBackward,
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.delete),
        CalculatorInputCommand.deleteForward,
      );
    });

    test('maps navigation with shift selection semantics', () {
      expect(
        mapper.map(key: LogicalKeyboardKey.arrowLeft, shiftPressed: true),
        const CalculatorInputCommand.moveCursorLeft(extendSelection: true),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.arrowRight, shiftPressed: true),
        const CalculatorInputCommand.moveCursorRight(extendSelection: true),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.home),
        const CalculatorInputCommand.moveCursorToStart(),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.end),
        const CalculatorInputCommand.moveCursorToEnd(),
      );
    });

    test('maps Ctrl+A and Command+A to select all', () {
      expect(
        mapper.map(key: LogicalKeyboardKey.keyA, controlPressed: true),
        CalculatorInputCommand.selectAll,
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.keyA, metaPressed: true),
        CalculatorInputCommand.selectAll,
      );
    });

    test('prioritizes printable shifted character over logical digit key', () {
      expect(
        mapper.map(
          key: LogicalKeyboardKey.digit8,
          character: '*',
          shiftPressed: true,
        ),
        const CalculatorInputCommand.insertToken('×'),
      );
      expect(
        mapper.map(
          key: LogicalKeyboardKey.equal,
          character: '+',
          shiftPressed: true,
        ),
        const CalculatorInputCommand.insertToken('+'),
      );
    });

    test('maps numpad digits and operators explicitly', () {
      expect(
        mapper.map(key: LogicalKeyboardKey.numpad7),
        const CalculatorInputCommand.insertToken('7'),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.numpadMultiply),
        const CalculatorInputCommand.insertToken('×'),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.numpadDivide),
        const CalculatorInputCommand.insertToken('÷'),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.numpadDecimal),
        const CalculatorInputCommand.insertToken('.'),
      );
      expect(
        mapper.map(key: LogicalKeyboardKey.numpadEnter),
        CalculatorInputCommand.calculate,
      );
    });

    test('does not turn unrelated control shortcuts into calculator input', () {
      expect(
        mapper.map(
          key: LogicalKeyboardKey.keyC,
          character: 'c',
          controlPressed: true,
        ),
        isNull,
      );
    });
  });
}
