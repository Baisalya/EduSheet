/// Central production budgets for mathematical authoring, validation and export.
///
/// These are intentionally generous for real school/university papers while
/// still placing deterministic ceilings around parser recursion, pathological
/// source strings and cache growth. Hitting a budget must select a safe
/// fallback; it must never crash, hang or partially render a formula.
abstract final class MathProductionLimits {
  /// Maximum TeX source accepted by native parser/renderer/export probes.
  static const int maxSourceCharacters = 32768;

  /// Maximum nested `{}`, `[]` or `()` depth accepted before native parsing.
  static const int maxSourceNestingDepth = 64;

  /// Maximum primary parser operations in one export compilation.
  static const int maxExportParserSteps = 16384;

  /// Maximum recursive parser frames used by the export compiler.
  static const int maxExportParserDepth = 65;

  /// Imported TeX environments can be larger than the 12x12 interactive
  /// builder, but remain bounded so hostile arrays cannot exhaust memory.
  static const int maxExportEnvironmentRows = 128;
  static const int maxExportEnvironmentColumns = 64;
  static const int maxExportEnvironmentCells = 2048;

  /// Question nesting deeper than this is treated as pathological. The
  /// validator stops descending and reports a deterministic safe-failure
  /// boundary instead of risking stack exhaustion.
  static const int maxQuestionNestingDepth = 24;

  /// Booklet-scale budgets. These comfortably cover 500-question stress
  /// papers while preventing accidental unbounded recursive validation.
  static const int maxPaperQuestions = 2000;
  static const int maxPaperMathExpressions = 20000;

  /// Maximum pages a generated question-paper PDF may contain. The pdf
  /// package defaults MultiPage to only 20 pages, which is too small for the
  /// supported large-booklet budget. Keeping this explicit and bounded avoids
  /// both false failures on legitimate papers and unbounded generation.
  static const int maxGeneratedPdfPages = 2000;

  static const int compatibilityCacheEntries = 512;
  static const int exportCompilationCacheEntries = 512;
}

class MathSourceBudgetReport {
  final int characters;
  final int maximumDepth;
  final bool withinBudget;
  final String? message;

  const MathSourceBudgetReport({
    required this.characters,
    required this.maximumDepth,
    required this.withinBudget,
    this.message,
  });
}

/// Cheap linear preflight performed before invoking either parser stack.
class MathSourceBudgetGuard {
  const MathSourceBudgetGuard();

  MathSourceBudgetReport inspect(String source) {
    if (source.length > MathProductionLimits.maxSourceCharacters) {
      return MathSourceBudgetReport(
        characters: source.length,
        maximumDepth: 0,
        withinBudget: false,
        message:
            'Formula is too large for native processing (${source.length} characters; maximum ${MathProductionLimits.maxSourceCharacters}).',
      );
    }

    var depth = 0;
    var maximumDepth = 0;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == '{' || char == '[' || char == '(') {
        depth += 1;
        if (depth > maximumDepth) maximumDepth = depth;
        if (maximumDepth > MathProductionLimits.maxSourceNestingDepth) {
          return MathSourceBudgetReport(
            characters: source.length,
            maximumDepth: maximumDepth,
            withinBudget: false,
            message:
                'Formula nesting is too deep for native processing ($maximumDepth levels; maximum ${MathProductionLimits.maxSourceNestingDepth}).',
          );
        }
      } else if ((char == '}' || char == ']' || char == ')') && depth > 0) {
        depth -= 1;
      }
    }

    return MathSourceBudgetReport(
      characters: source.length,
      maximumDepth: maximumDepth,
      withinBudget: true,
    );
  }
}

class MathCacheSnapshot {
  final int entries;
  final int maximumEntries;
  final int hits;
  final int misses;
  final int evictions;

  const MathCacheSnapshot({
    required this.entries,
    required this.maximumEntries,
    required this.hits,
    required this.misses,
    required this.evictions,
  });

  int get lookups => hits + misses;

  double get hitRate => lookups == 0 ? 0 : hits / lookups;
}
