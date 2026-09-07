enum CalculatorInputCommandType {
  insertToken,
  insertFormula,
  deleteBackward,
  deleteForward,
  toggleSign,
  moveCursorLeft,
  moveCursorRight,
  moveCursorToStart,
  moveCursorToEnd,
  selectAll,
  calculate,
  clear,
  previousHistory,
  nextHistory,
  toggleShift,
  toggleHyp,
  toggleAngleUnit,
}

/// Typed input intent shared by touch, keyboard, numpad, and formula surfaces.
///
/// Formula commands carry only calculator-ready numeric expressions. Science
/// symbols/variables are resolved by FormulaSolver before dispatch.
///
/// The command intentionally contains no Flutter key details. Platform-specific
/// input is translated at the presentation boundary before reaching the
/// calculator controller.
class CalculatorInputCommand {
  final CalculatorInputCommandType type;
  final String? text;
  final bool extendSelection;

  const CalculatorInputCommand._(
    this.type, {
    this.text,
    this.extendSelection = false,
  });

  const CalculatorInputCommand.insertToken(String token)
    : this._(CalculatorInputCommandType.insertToken, text: token);

  const CalculatorInputCommand.insertFormula(String formula)
    : this._(CalculatorInputCommandType.insertFormula, text: formula);

  const CalculatorInputCommand.moveCursorLeft({bool extendSelection = false})
    : this._(
        CalculatorInputCommandType.moveCursorLeft,
        extendSelection: extendSelection,
      );

  const CalculatorInputCommand.moveCursorRight({bool extendSelection = false})
    : this._(
        CalculatorInputCommandType.moveCursorRight,
        extendSelection: extendSelection,
      );

  const CalculatorInputCommand.moveCursorToStart({bool extendSelection = false})
    : this._(
        CalculatorInputCommandType.moveCursorToStart,
        extendSelection: extendSelection,
      );

  const CalculatorInputCommand.moveCursorToEnd({bool extendSelection = false})
    : this._(
        CalculatorInputCommandType.moveCursorToEnd,
        extendSelection: extendSelection,
      );

  static const deleteBackward = CalculatorInputCommand._(
    CalculatorInputCommandType.deleteBackward,
  );
  static const deleteForward = CalculatorInputCommand._(
    CalculatorInputCommandType.deleteForward,
  );
  static const toggleSign = CalculatorInputCommand._(
    CalculatorInputCommandType.toggleSign,
  );
  static const selectAll = CalculatorInputCommand._(
    CalculatorInputCommandType.selectAll,
  );
  static const calculate = CalculatorInputCommand._(
    CalculatorInputCommandType.calculate,
  );
  static const clear = CalculatorInputCommand._(
    CalculatorInputCommandType.clear,
  );
  static const previousHistory = CalculatorInputCommand._(
    CalculatorInputCommandType.previousHistory,
  );
  static const nextHistory = CalculatorInputCommand._(
    CalculatorInputCommandType.nextHistory,
  );
  static const toggleShift = CalculatorInputCommand._(
    CalculatorInputCommandType.toggleShift,
  );
  static const toggleHyp = CalculatorInputCommand._(
    CalculatorInputCommandType.toggleHyp,
  );
  static const toggleAngleUnit = CalculatorInputCommand._(
    CalculatorInputCommandType.toggleAngleUnit,
  );

  @override
  bool operator ==(Object other) {
    return other is CalculatorInputCommand &&
        other.type == type &&
        other.text == text &&
        other.extendSelection == extendSelection;
  }

  @override
  int get hashCode => Object.hash(type, text, extendSelection);

  @override
  String toString() {
    return 'CalculatorInputCommand(type: $type, text: $text, '
        'extendSelection: $extendSelection)';
  }
}
