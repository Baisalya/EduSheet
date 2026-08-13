import 'math_plain_text_serializer.dart';

/// Produces a useful accessibility/export fallback from the formula source.
///
/// This deliberately stays deterministic and dependency-free. It first reuses
/// the keyboard's existing textbook-to-plain serializer for known entries,
/// then expands common TeX structures into readable words. Unknown commands
/// degrade to their command name instead of blocking a teacher from saving.
class MathAccessibleTextService {
  const MathAccessibleTextService({
    this.serializer = const MathPlainTextSerializer(),
  });

  final MathPlainTextSerializer serializer;

  String describe(String latex) {
    final source = latex.trim();
    if (source.isEmpty) return '';

    final known = serializer
        .serialize(
          source,
          powerMode: false,
          subscriptMode: false,
        )
        .text
        .trim();
    if (known.isNotEmpty && known != source) {
      return _normalize(known);
    }

    var text = source;

    // Resolve the simple nested structures teachers use most often before
    // stripping braces. Powers/subscripts first make sqrt/fraction groups
    // easier to read in common nested formulas.
    text = text.replaceAllMapped(
      RegExp(r'\^\{([^{}]+)\}'),
      (match) => ' to the power ${match.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'_\{([^{}]+)\}'),
      (match) => ' subscript ${match.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\^([A-Za-z0-9])'),
      (match) => ' to the power ${match.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'_([A-Za-z0-9])'),
      (match) => ' subscript ${match.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sqrt\[([^{}\]]+)\]\{([^{}]+)\}'),
      (match) => '${match.group(1)} root of ${match.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]+)\}'),
      (match) => 'square root of ${match.group(1)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) => '${match.group(1)} divided by ${match.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\\text\{([^{}]+)\}'),
      (match) => match.group(1) ?? '',
    );

    const replacements = <String, String>{
      r'\left': '',
      r'\right': '',
      r'\times': ' multiplied by ',
      r'\cdot': ' times ',
      r'\div': ' divided by ',
      r'\pm': ' plus or minus ',
      r'\mp': ' minus or plus ',
      r'\leq': ' less than or equal to ',
      r'\le': ' less than or equal to ',
      r'\geq': ' greater than or equal to ',
      r'\ge': ' greater than or equal to ',
      r'\neq': ' not equal to ',
      r'\ne': ' not equal to ',
      r'\approx': ' approximately ',
      r'\equiv': ' equivalent to ',
      r'\to': ' approaches ',
      r'\infty': ' infinity ',
      r'\int': ' integral ',
      r'\iint': ' double integral ',
      r'\iiint': ' triple integral ',
      r'\oint': ' contour integral ',
      r'\sum': ' sum ',
      r'\prod': ' product ',
      r'\partial': ' partial ',
      r'\pi': ' pi ',
      r'\theta': ' theta ',
      r'\alpha': ' alpha ',
      r'\beta': ' beta ',
      r'\gamma': ' gamma ',
      r'\delta': ' delta ',
      r'\Delta': ' delta ',
      r'\lambda': ' lambda ',
      r'\mu': ' mu ',
      r'\rho': ' rho ',
      r'\sigma': ' sigma ',
      r'\omega': ' omega ',
      r'\Omega': ' omega ',
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    // Unknown TeX commands are still more useful to a screen reader without
    // the leading slash. Grouping braces become spoken-friendly parentheses.
    text = text.replaceAllMapped(
      RegExp(r'\\([A-Za-z]+)'),
      (match) => ' ${match.group(1)} ',
    );
    text = text.replaceAll('{', '(').replaceAll('}', ')');
    text = text.replaceAll(r'\,', ' ');
    text = text.replaceAll(r'\;', ' ');
    text = text.replaceAll(r'\!', ' ');

    return _normalize(text);
  }

  String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' (', ' (')
        .replaceAll('( ', '(')
        .replaceAll(' )', ')')
        .trim();
  }
}
