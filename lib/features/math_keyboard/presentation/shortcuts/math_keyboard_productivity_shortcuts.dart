import 'package:flutter/services.dart';

enum MathKeyboardProductivityCommand {
  toggleKeyboard,
  search,
  showShortcuts,
  insertFraction,
  insertSquareRoot,
  insertPower,
  insertSubscript,
  systemKeyboard,
  nextSlot,
  previousSlot,
}

class MathKeyboardShortcutSpec {
  final MathKeyboardProductivityCommand command;
  final String keys;
  final String title;
  final String description;

  const MathKeyboardShortcutSpec({
    required this.command,
    required this.keys,
    required this.title,
    required this.description,
  });
}

/// Single source of truth for hardware-key productivity actions used by the
/// math editor, the keyboard overlay and the in-product shortcut help panel.
///
/// Keeping resolution independent of a [BuildContext] makes it deterministic
/// and easy to regression-test without synthesizing platform-specific key maps.
class MathKeyboardProductivityShortcuts {
  const MathKeyboardProductivityShortcuts._();

  static const specs = <MathKeyboardShortcutSpec>[
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.toggleKeyboard,
      keys: 'Ctrl+Shift+M',
      title: 'Toggle math keyboard',
      description: 'Open math input, or return to the normal text keyboard.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.search,
      keys: 'Ctrl+K',
      title: 'Find a symbol or formula',
      description:
          'Open teacher-friendly math search without leaving the field.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.showShortcuts,
      keys: 'Ctrl+/',
      title: 'Show keyboard shortcuts',
      description:
          'Open this productivity reference without leaving math input.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.insertFraction,
      keys: 'Ctrl+Shift+1',
      title: 'Insert fraction',
      description: 'Create numerator and denominator boxes immediately.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.insertSquareRoot,
      keys: 'Ctrl+Shift+2',
      title: 'Insert square root',
      description: 'Create a square-root box at the current math cursor.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.insertPower,
      keys: 'Ctrl+Shift+3',
      title: 'Insert power box',
      description: 'Create an exponent box without switching panels.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.insertSubscript,
      keys: 'Ctrl+Shift+4',
      title: 'Insert subscript box',
      description: 'Create a lower-index box at the current math cursor.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.systemKeyboard,
      keys: 'Esc',
      title: 'Return to text keyboard',
      description: 'Leave custom math input while keeping the editor focused.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.nextSlot,
      keys: 'Tab',
      title: 'Next formula box',
      description:
          'Move through fraction, root, script and dynamic-structure slots.',
    ),
    MathKeyboardShortcutSpec(
      command: MathKeyboardProductivityCommand.previousSlot,
      keys: 'Shift+Tab',
      title: 'Previous formula box',
      description: 'Move backward through the current structured formula.',
    ),
  ];

  static MathKeyboardProductivityCommand? resolve({
    required LogicalKeyboardKey key,
    required bool control,
    required bool shift,
    required bool alt,
    required bool meta,
  }) {
    if (meta || alt) return null;

    if (control && shift) {
      if (key == LogicalKeyboardKey.keyM) {
        return MathKeyboardProductivityCommand.toggleKeyboard;
      }
      if (key == LogicalKeyboardKey.digit1) {
        return MathKeyboardProductivityCommand.insertFraction;
      }
      if (key == LogicalKeyboardKey.digit2) {
        return MathKeyboardProductivityCommand.insertSquareRoot;
      }
      if (key == LogicalKeyboardKey.digit3) {
        return MathKeyboardProductivityCommand.insertPower;
      }
      if (key == LogicalKeyboardKey.digit4) {
        return MathKeyboardProductivityCommand.insertSubscript;
      }
      return null;
    }

    if (control && !shift && key == LogicalKeyboardKey.keyK) {
      return MathKeyboardProductivityCommand.search;
    }
    if (control && !shift && key == LogicalKeyboardKey.slash) {
      return MathKeyboardProductivityCommand.showShortcuts;
    }
    if (!control && !shift && key == LogicalKeyboardKey.escape) {
      return MathKeyboardProductivityCommand.systemKeyboard;
    }
    if (!control && key == LogicalKeyboardKey.tab) {
      return shift
          ? MathKeyboardProductivityCommand.previousSlot
          : MathKeyboardProductivityCommand.nextSlot;
    }
    return null;
  }
}
