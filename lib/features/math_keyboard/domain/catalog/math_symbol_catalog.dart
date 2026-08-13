import '../models/math_symbol.dart';
import 'arrows_catalog.dart';
import 'basic_catalog.dart';
import 'brackets_catalog.dart';
import 'calculus_catalog.dart';
import 'chemistry_catalog.dart';
import 'functions_catalog.dart';
import 'geometry_catalog.dart';
import 'greek_catalog.dart';
import 'matrices_catalog.dart';
import 'misc_catalog.dart';
import 'operators_catalog.dart';
import 'physics_catalog.dart';
import 'sets_catalog.dart';
import 'statistics_catalog.dart';
import 'templates_catalog.dart';
import 'trig_catalog.dart';

/// Domain boundary for keyboard catalogue access.
///
/// Presentation code should query this class instead of scanning category data
/// directly. That keeps identity, ranking and semantic search consistent.
class MathSymbolCatalog {
  const MathSymbolCatalog._();

  static const List<MathSymbol> symbols = <MathSymbol>[
    ...basicMathSymbols,
    ...functionsMathSymbols,
    ...trigMathSymbols,
    ...calculusMathSymbols,
    ...operatorsMathSymbols,
    ...greekMathSymbols,
    ...setsMathSymbols,
    ...bracketsMathSymbols,
    ...geometryMathSymbols,
    ...physicsMathSymbols,
    ...statisticsMathSymbols,
    ...arrowsMathSymbols,
    ...matricesMathSymbols,
    ...templatesMathSymbols,
    ...chemistryMathSymbols,
    ...miscMathSymbols,
  ];

  static List<MathSymbol> forCategory(MathCategory category) {
    if (category == MathCategory.recent ||
        category == MathCategory.favorites ||
        category == MathCategory.format) {
      return const <MathSymbol>[];
    }

    return symbols
        .where((symbol) => symbol.category == category)
        .toList(growable: false);
  }

  static MathSymbol? findById(String id, {MathCategory? category}) {
    for (final symbol in symbols) {
      if (symbol.id == id &&
          (category == null || symbol.category == category)) {
        return symbol;
      }
    }
    return null;
  }

  static MathSymbol? findByTex(String tex, {MathCategory? category}) {
    for (final symbol in symbols) {
      if (symbol.tex == tex &&
          (category == null || symbol.category == category)) {
        return symbol;
      }
    }
    return null;
  }

  static List<MathSymbol> search(
    String query, {
    MathCategory? category,
    MathSubject? subject,
    int? limit,
  }) {
    final normalized = query.trim().toLowerCase();
    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    final scored = <_ScoredMathSymbol>[];
    for (final symbol in symbols) {
      if (category != null && symbol.category != category) continue;
      if (subject != null && !symbol.effectiveSubjects.contains(subject)) {
        continue;
      }

      final haystack = symbol.searchableText;
      if (terms.isNotEmpty && !terms.every(haystack.contains)) continue;

      var score = symbol.priority;
      if (normalized.isNotEmpty) {
        final label = symbol.label.toLowerCase();
        final spoken = symbol.accessibilityLabel.toLowerCase();

        if (label == normalized) {
          score -= 80;
        } else if (spoken == normalized) {
          score -= 70;
        } else if (label.startsWith(normalized)) {
          score -= 50;
        } else if (symbol.effectiveAliases.any(
          (alias) => alias.toLowerCase() == normalized,
        )) {
          score -= 45;
        } else if (spoken.contains(normalized)) {
          score -= 30;
        }
      }

      scored.add(_ScoredMathSymbol(symbol, score));
    }

    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;

      final byLabel = a.symbol.label.compareTo(b.symbol.label);
      if (byLabel != 0) return byLabel;

      return a.symbol.category.index.compareTo(b.symbol.category.index);
    });

    final result = scored.map((item) => item.symbol);
    return (limit == null ? result : result.take(limit)).toList(
      growable: false,
    );
  }

  /// Returns one representative for every semantic id.
  static List<MathSymbol> get canonicalSymbols {
    final seen = <String>{};
    return symbols
        .where((symbol) => seen.add(symbol.id))
        .toList(growable: false);
  }
}

class _ScoredMathSymbol {
  final MathSymbol symbol;
  final int score;

  const _ScoredMathSymbol(this.symbol, this.score);
}

/// Compatibility alias for existing tests/callers during the staged refactor.
const List<MathSymbol> mathSymbols = MathSymbolCatalog.symbols;
