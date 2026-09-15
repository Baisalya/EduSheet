import '../models/math_composer_spec.dart';

class MathSourceSelection {
  final int start;
  final int end;

  const MathSourceSelection({required this.start, required this.end});

  bool get isCollapsed => start == end;
}

class MathSelectionCompositionResult {
  final String source;
  final int cursorOffset;

  const MathSelectionCompositionResult({
    required this.source,
    required this.cursorOffset,
  });
}

/// Pure source-level selection composer.
///
/// It intentionally has no Flutter dependency, making selection wrapping easy
/// to regression-test and usable by any future source editor. Visual MathField
/// nesting remains handled by [MathEditCommand] slot operations.
class MathSelectionComposer {
  const MathSelectionComposer();

  MathSelectionCompositionResult? wrap({
    required String source,
    required MathSourceSelection selection,
    required MathSelectionWrapRecipe recipe,
  }) {
    final rawStart = selection.start;
    final rawEnd = selection.end;
    if (rawStart < 0 || rawEnd < 0) return null;

    final start = rawStart <= rawEnd ? rawStart : rawEnd;
    final end = rawStart <= rawEnd ? rawEnd : rawStart;
    if (start > source.length || end > source.length || start == end) {
      return null;
    }

    final selected = source.substring(start, end);
    final replacement =
        '${recipe.beforeSelection}$selected${recipe.afterSelection}';
    final nextSource = source.replaceRange(start, end, replacement);
    final cursor =
        start +
        recipe.beforeSelection.length +
        selected.length +
        recipe.cursorOffsetInSuffix;

    final safeCursor = cursor < 0
        ? 0
        : (cursor > nextSource.length ? nextSource.length : cursor);
    return MathSelectionCompositionResult(
      source: nextSource,
      cursorOffset: safeCursor,
    );
  }
}
