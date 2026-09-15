import 'package:edusheet/features/math_keyboard/presentation/shortcuts/math_keyboard_productivity_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('productivity shortcuts have unique discoverable key labels', () {
    final labels = MathKeyboardProductivityShortcuts.specs
        .map((spec) => spec.keys)
        .toList(growable: false);

    expect(labels.toSet().length, labels.length);
    expect(
      labels,
      containsAll(<String>['Ctrl+K', 'Ctrl+/', 'Tab', 'Shift+Tab']),
    );
    expect(
      MathKeyboardProductivityShortcuts.specs.every(
        (spec) =>
            spec.title.trim().isNotEmpty && spec.description.trim().isNotEmpty,
      ),
      isTrue,
    );
  });

  test('resolver maps the production shortcut contract deterministically', () {
    MathKeyboardProductivityCommand? resolve(
      LogicalKeyboardKey key, {
      bool control = false,
      bool shift = false,
      bool alt = false,
      bool meta = false,
    }) => MathKeyboardProductivityShortcuts.resolve(
      key: key,
      control: control,
      shift: shift,
      alt: alt,
      meta: meta,
    );

    expect(
      resolve(LogicalKeyboardKey.keyM, control: true, shift: true),
      MathKeyboardProductivityCommand.toggleKeyboard,
    );
    expect(
      resolve(LogicalKeyboardKey.keyK, control: true),
      MathKeyboardProductivityCommand.search,
    );
    expect(
      resolve(LogicalKeyboardKey.slash, control: true),
      MathKeyboardProductivityCommand.showShortcuts,
    );
    expect(
      resolve(LogicalKeyboardKey.digit1, control: true, shift: true),
      MathKeyboardProductivityCommand.insertFraction,
    );
    expect(
      resolve(LogicalKeyboardKey.digit2, control: true, shift: true),
      MathKeyboardProductivityCommand.insertSquareRoot,
    );
    expect(
      resolve(LogicalKeyboardKey.digit3, control: true, shift: true),
      MathKeyboardProductivityCommand.insertPower,
    );
    expect(
      resolve(LogicalKeyboardKey.digit4, control: true, shift: true),
      MathKeyboardProductivityCommand.insertSubscript,
    );
    expect(
      resolve(LogicalKeyboardKey.escape),
      MathKeyboardProductivityCommand.systemKeyboard,
    );
    expect(
      resolve(LogicalKeyboardKey.tab),
      MathKeyboardProductivityCommand.nextSlot,
    );
    expect(
      resolve(LogicalKeyboardKey.tab, shift: true),
      MathKeyboardProductivityCommand.previousSlot,
    );

    expect(
      resolve(LogicalKeyboardKey.keyK, control: true, alt: true),
      isNull,
      reason: 'Alt/AltGr combinations must not be stolen from normal typing.',
    );
    expect(
      resolve(LogicalKeyboardKey.keyK, control: true, meta: true),
      isNull,
      reason: 'Mixed platform modifiers must fail closed.',
    );
  });
}
