/// Pure text helpers used by the manual-first mobile paper authoring workflow.
///
/// These helpers intentionally create ordinary printable text. A teacher can
/// edit or delete the inserted text afterwards exactly as they would in Word.
class QuestionAuthoringTextTools {
  const QuestionAuthoringTextTools._();

  static String blank({int width = 10}) {
    final safeWidth = width.clamp(4, 40).toInt();
    return List.filled(safeWidth, '_').join();
  }

  static String nextSubQuestionInsertion(
    String plainText, {
    String? textBeforeInsertion,
  }) {
    final label = _nextPartLabel(plainText);
    final before = textBeforeInsertion ?? plainText;
    if (before.trim().isEmpty) return '($label) ';
    return before.endsWith('\n') ? '($label) ' : '\n($label) ';
  }

  static String orDividerInsertion(
    String plainText, {
    String? textBeforeInsertion,
  }) {
    final before = textBeforeInsertion ?? plainText;
    if (before.trim().isEmpty) return 'OR\n';
    return before.endsWith('\n') ? '\nOR\n' : '\n\nOR\n';
  }

  static String instructionInsertion(
    String plainText, {
    String? textBeforeInsertion,
  }) {
    final before = textBeforeInsertion ?? plainText;
    if (before.trim().isEmpty) return 'Instruction: ';
    return before.endsWith('\n') ? 'Instruction: ' : '\nInstruction: ';
  }

  static String _nextPartLabel(String plainText) {
    final matches = RegExp(
      r'^\s*\(([a-z]+)\)\s+',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(plainText);
    var largest = 0;
    for (final match in matches) {
      final value = _alphaToNumber(match.group(1) ?? '');
      if (value > largest) largest = value;
    }
    return _numberToAlpha(largest + 1);
  }

  static int _alphaToNumber(String value) {
    var result = 0;
    for (final codeUnit in value.toLowerCase().codeUnits) {
      if (codeUnit < 97 || codeUnit > 122) return 0;
      result = (result * 26) + (codeUnit - 96);
    }
    return result;
  }

  static String _numberToAlpha(int value) {
    var number = value < 1 ? 1 : value;
    final codes = <int>[];
    while (number > 0) {
      number -= 1;
      codes.add(97 + (number % 26));
      number ~/= 26;
    }
    return String.fromCharCodes(codes.reversed);
  }
}
