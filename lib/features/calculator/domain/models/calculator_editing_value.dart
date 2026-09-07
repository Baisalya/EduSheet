class CalculatorSelection {
  final int baseOffset;
  final int extentOffset;

  const CalculatorSelection({
    required this.baseOffset,
    required this.extentOffset,
  });

  const CalculatorSelection.collapsed(int offset)
    : baseOffset = offset,
      extentOffset = offset;

  int get start => baseOffset < extentOffset ? baseOffset : extentOffset;
  int get end => baseOffset > extentOffset ? baseOffset : extentOffset;
  bool get isCollapsed => baseOffset == extentOffset;

  CalculatorSelection clamp(int textLength) {
    final safeLength = textLength < 0 ? 0 : textLength;
    return CalculatorSelection(
      baseOffset: baseOffset.clamp(0, safeLength).toInt(),
      extentOffset: extentOffset.clamp(0, safeLength).toInt(),
    );
  }

  CalculatorSelection collapseTo(int offset) {
    return CalculatorSelection.collapsed(offset);
  }

  @override
  bool operator ==(Object other) {
    return other is CalculatorSelection &&
        other.baseOffset == baseOffset &&
        other.extentOffset == extentOffset;
  }

  @override
  int get hashCode => Object.hash(baseOffset, extentOffset);

  @override
  String toString() {
    return 'CalculatorSelection(base: $baseOffset, extent: $extentOffset)';
  }
}

class CalculatorEditingValue {
  final String text;
  final CalculatorSelection selection;

  const CalculatorEditingValue({
    this.text = '',
    this.selection = const CalculatorSelection.collapsed(0),
  });

  factory CalculatorEditingValue.fromText(String text, {int? cursorOffset}) {
    final offset = (cursorOffset ?? text.length).clamp(0, text.length).toInt();
    return CalculatorEditingValue(
      text: text,
      selection: CalculatorSelection.collapsed(offset),
    );
  }

  int get cursorOffset => selection.extentOffset;
  bool get hasSelection => !selection.isCollapsed;

  CalculatorEditingValue normalized() {
    final safeSelection = selection.clamp(text.length);
    if (safeSelection == selection) return this;
    return CalculatorEditingValue(text: text, selection: safeSelection);
  }

  CalculatorEditingValue copyWith({
    String? text,
    CalculatorSelection? selection,
    bool moveCaretToEnd = false,
  }) {
    final nextText = text ?? this.text;
    final nextSelection = moveCaretToEnd
        ? CalculatorSelection.collapsed(nextText.length)
        : (selection ?? this.selection).clamp(nextText.length);
    return CalculatorEditingValue(text: nextText, selection: nextSelection);
  }

  @override
  bool operator ==(Object other) {
    return other is CalculatorEditingValue &&
        other.text == text &&
        other.selection == selection;
  }

  @override
  int get hashCode => Object.hash(text, selection);

  @override
  String toString() {
    return 'CalculatorEditingValue(text: $text, selection: $selection)';
  }
}
