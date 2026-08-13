import '../catalog/math_symbol_catalog.dart';
import '../models/math_symbol.dart';

/// Curates a small, high-frequency ribbon for the active teaching context.
///
/// This deliberately returns catalogue entries rather than raw TeX so the UI
/// inherits semantic identity, accessibility wording, insertion behavior and
/// future ranking metadata from one source of truth.
class MathSmartPalette {
  const MathSmartPalette._();

  static List<MathSymbol> forCategory(MathCategory category) {
    final sources = _sources[category] ?? _defaultSources;
    return sources
        .map(MathSymbolCatalog.findByTex)
        .whereType<MathSymbol>()
        .toList(growable: false);
  }

  static const List<String> _defaultSources = <String>[
    r'\frac{}{}',
    r'^{}',
    r'_{}',
    r'\sqrt{}',
    '(',
    r'\pm',
    r'\pi',
    r'\leq',
    r'\geq',
  ];

  static const Map<MathCategory, List<String>> _sources =
      <MathCategory, List<String>>{
        MathCategory.calculus: <String>[
          r'\frac{}{}',
          r'^{}',
          r'_{}',
          r'\int_{}^{}',
          r'\frac{d}{dx}',
          r'\partial',
          r'\sum_{}^{}',
          r'\infty',
          r'\pi',
        ],
        MathCategory.physics: <String>[
          r'\frac{}{}',
          r'^{}',
          r'_{}',
          r'\Delta',
          r'\vec{v}',
          r'\lambda',
          r'\rho',
          r'\omega',
          r'\text{m/s}',
        ],
        MathCategory.chemistry: <String>[
          r'_{}',
          r'^{}',
          r'\rightarrow',
          r'\rightleftharpoons',
          r'\Delta',
          r'\mathrm{(s)}',
          r'\mathrm{(l)}',
          r'\mathrm{(g)}',
          r'\mathrm{(aq)}',
        ],
        MathCategory.statistics: <String>[
          r'\frac{}{}',
          r'^{}',
          r'\sqrt{}',
          r'\bar{x}',
          r'\mu',
          r'\sigma',
          r'\sum',
          r'P(A)',
        ],
        MathCategory.geometry: <String>[
          r'\angle',
          r'\triangle',
          r'\perp',
          r'\parallel',
          r'^{\circ}',
          r'\overline{AB}',
          r'\overrightarrow{AB}',
          r'\sqrt{}',
        ],
        MathCategory.trig: <String>[
          r'\sin',
          r'\cos',
          r'\tan',
          r'\theta',
          r'\pi',
          r'^{\circ}',
          r'^{}',
          r'\frac{}{}',
        ],
      };
}
