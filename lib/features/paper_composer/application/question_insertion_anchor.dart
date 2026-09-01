import 'dart:math' as math;

/// A stable, UI-independent snapshot of where the next authoring action should
/// modify a question document.
///
/// Mobile authoring frequently moves focus away from the rich-text editor to a
/// bottom sheet, toolbar or formula builder. Relying on the editor's *current*
/// selection after that focus transition can silently move an insertion to the
/// end of the question. Capture this value before opening transient UI and use
/// it until the requested action is applied.
class QuestionInsertionAnchor {
  final int start;
  final int length;
  final int lineNumber;
  final int columnNumber;
  final String linePreview;
  final bool isAtDocumentEnd;

  const QuestionInsertionAnchor({
    required this.start,
    required this.length,
    required this.lineNumber,
    required this.columnNumber,
    required this.linePreview,
    required this.isAtDocumentEnd,
  });

  factory QuestionInsertionAnchor.fromDocument({
    required String plainText,
    required int documentEnd,
    required int baseOffset,
    required int extentOffset,
  }) {
    final safeDocumentEnd = math
        .max(0, math.min(documentEnd, plainText.length))
        .toInt();
    final safeBase = baseOffset < 0
        ? safeDocumentEnd
        : baseOffset.clamp(0, safeDocumentEnd).toInt();
    final safeExtent = extentOffset < 0
        ? safeBase
        : extentOffset.clamp(0, safeDocumentEnd).toInt();
    final start = math.min(safeBase, safeExtent);
    final end = math.max(safeBase, safeExtent);

    final before = plainText.substring(0, start);
    final previousBreak = before.lastIndexOf('\n');
    final nextBreak = plainText.indexOf('\n', start);
    final lineStart = previousBreak < 0 ? 0 : previousBreak + 1;
    final lineEnd = nextBreak < 0 ? plainText.length : nextBreak;
    final preview = plainText
        .substring(lineStart, lineEnd)
        .replaceAll('\uFFFC', '[item]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return QuestionInsertionAnchor(
      start: start,
      length: end - start,
      lineNumber: '\n'.allMatches(before).length + 1,
      columnNumber: start - lineStart + 1,
      linePreview: _shorten(preview),
      isAtDocumentEnd: start >= safeDocumentEnd,
    );
  }

  bool get hasSelection => length > 0;

  String get compactLocation => hasSelection
      ? 'Line $lineNumber · $length selected'
      : 'Line $lineNumber · position $columnNumber';

  String get actionLabel => hasSelection
      ? 'Replace selection · $compactLocation'
      : 'Insert at $compactLocation';

  String get contextLabel {
    if (linePreview.isEmpty) {
      return isAtDocumentEnd
          ? 'The cursor is at the end of this question.'
          : 'The cursor is on an empty line.';
    }
    return 'Current line: “$linePreview”';
  }

  static String _shorten(String value) {
    const limit = 52;
    final runes = value.runes.toList(growable: false);
    if (runes.length <= limit) return value;
    return '${String.fromCharCodes(runes.take(limit - 1))}…';
  }

  @override
  bool operator ==(Object other) {
    return other is QuestionInsertionAnchor &&
        other.start == start &&
        other.length == length &&
        other.lineNumber == lineNumber &&
        other.columnNumber == columnNumber &&
        other.linePreview == linePreview &&
        other.isAtDocumentEnd == isAtDocumentEnd;
  }

  @override
  int get hashCode => Object.hash(
    start,
    length,
    lineNumber,
    columnNumber,
    linePreview,
    isAtDocumentEnd,
  );
}
