import '../catalog/math_symbol_catalog.dart';
import '../models/math_symbol.dart';

class PlainMathInsertion {
  final String text;

  /// Cursor offset relative to the insertion start.
  final int cursorOffset;

  const PlainMathInsertion({required this.text, required this.cursorOffset});
}

/// Converts textbook TeX keyboard entries into the best practical plain-text
/// representation for normal TextFields and Quill text runs.
///
/// This preserves the existing app behavior while moving serialization out of
/// the keyboard controller. Structured MathField editing remains separate.
class MathPlainTextSerializer {
  const MathPlainTextSerializer();

  PlainMathInsertion serialize(
    String source, {
    required bool powerMode,
    required bool subscriptMode,
  }) {
    var output = _textMapping[source];

    if (output == null &&
        powerMode &&
        (source.length == 1 || source == r'\pi' || source == 'e')) {
      final rawChar = source == r'\pi' ? 'π' : source;
      output = _superscripts[rawChar] ?? '^$rawChar';
    }

    if (output == null &&
        subscriptMode &&
        (source.length == 1 || source == r'\pi' || source == 'e')) {
      final rawChar = source == r'\pi' ? 'π' : source;
      output = _subscripts[rawChar] ?? '_$rawChar';
    }

    if (output == null) {
      final symbol =
          MathSymbolCatalog.findByTex(source) ??
          MathSymbol(
            id: 'adhoc:$source',
            label: source,
            tex: source,
            category: MathCategory.misc,
          );

      output = source;
      if (symbol.label.length == 1 ||
          symbol.category == MathCategory.greek ||
          symbol.category == MathCategory.operators ||
          source.startsWith('\\')) {
        output = symbol.label;
      }
    }

    return PlainMathInsertion(
      text: output,
      cursorOffset: _cursorOffset(output),
    );
  }

  int _cursorOffset(String output) {
    if (_cursorInsideTrailingPair.contains(output)) {
      return output.length - 1;
    }
    if (output == '()⁄()') {
      return 1;
    }
    return output.length;
  }

  static const Set<String> _cursorInsideTrailingPair = <String>{
    '()',
    '[]',
    '{}',
    '||',
    '√()',
    '∛()',
    'ⁿ√()',
    'sin()',
    'cos()',
    'tan()',
    'logₐ()',
    'ln()',
    'arcsin()',
    'arccos()',
    'arctan()',
    'sinh()',
    'cosh()',
    'tanh()',
  };

  static const Map<String, String> _superscripts = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    '=': '⁼',
    '(': '⁽',
    ')': '⁾',
    'n': 'ⁿ',
    'x': 'ˣ',
    'y': 'ʸ',
    'z': 'ᶻ',
    'a': 'ᵃ',
    'b': 'ᵇ',
    'c': 'ᶜ',
    'i': 'ⁱ',
    'π': 'ᵖ',
  };

  static const Map<String, String> _subscripts = <String, String>{
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    '=': '₌',
    '(': '₍',
    ')': '₎',
    'n': 'ₙ',
    'x': 'ₓ',
    'y': 'ᵧ',
    'z': '_z',
    'a': 'ₐ',
    'e': 'ₑ',
    'h': 'ₕ',
    'i': 'ᵢ',
    'j': 'ⱼ',
    'k': 'ₖ',
    'l': 'ₗ',
    'm': 'ₘ',
    'o': 'ₒ',
    'p': 'ₚ',
    'r': 'ᵣ',
    's': 'ₛ',
    't': 'ₜ',
    'u': 'ᵤ',
    'v': 'ᵥ',
  };

  static const Map<String, String> _textMapping = <String, String>{
    r'\sqrt{}': '√()',
    r'\sqrt[3]{}': '∛()',
    r'\sqrt[]{}': 'ⁿ√()',
    r'\frac{}{}': '()⁄()',
    r'\frac{1}{2}': '½',
    r'\frac{1}{3}': '⅓',
    r'\frac{2}{3}': '⅔',
    r'\int_{}^{}^{}': '∫',
    r'\int_{}^{}': '∫ₐᵇ',
    r'\int': '∫',
    r'\iint': '∬',
    r'\iiint': '∭',
    r'\oint': '∮',
    r'\sum_{}^{}': '∑',
    r'\sum': '∑',
    r'\prod_{}^{}^{}': '∏',
    r'\prod_{}^{}': '∏',
    r'\prod': '∏',
    r'\log': 'log',
    r'\log_{}(': 'logₐ()',
    r'\log_{}': 'logₐ()',
    r'\ln': 'ln()',
    r'|{}|': '||',
    r'^{}': '^',
    r'_{}': '_',
    r'^{2}': '²',
    r'^{3}': '³',
    r'e^{}': 'e^',
    r'\frac{d}{dx}': 'd/dx',
    r'\frac{dy}{dx}': 'dy/dx',
    r'\frac{d^2}{dx^2}': 'd²/dx²',
    r'\lim_{x \to \infty}': 'lim x→∞',
    r'\triangle_{A B C}': '△ABC',
    r'\overline{AB}': 'AB̅',
    r'\vec{v}': 'v⃗',
    r'\overset{\frown}{AB}': 'arc AB',
    r'\angle ABC': '∠ABC',
    r'm\angle ABC': 'm∠ABC',
    r'\overrightarrow{AB}': 'AB⃗',
    r'\overleftrightarrow{AB}': 'AB↔',
    r'\rightangle': '∟',
    r'\widehat{AB}': '⌒AB',
    r'\triangle ABC': '△ABC',
    r'\parallelogram': '▱',
    r'\diameter': '⌀',
    r'^{\circ}': '°',
    r'^{\prime}': '′',
    r'^{\prime\prime}': '″',
    r'\text{mm}': 'mm',
    r'\text{cm}': 'cm',
    r'\text{m}': 'm',
    r'\text{km}': 'km',
    r'\text{cm}^{2}': 'cm²',
    r'\text{cm}^{3}': 'cm³',
    r'\Delta t': 'Δt',
    r'\vec{F}': 'F⃗',
    r'^{\circ}\text{C}': '°C',
    r'\text{m/s}': 'm/s',
    r'\text{m/s}^{2}': 'm/s²',
    r'\text{kg}': 'kg',
    r'\text{N}': 'N',
    r'\text{J}': 'J',
    r'\text{W}': 'W',
    r'\text{Pa}': 'Pa',
    r'\text{Hz}': 'Hz',
    r'\text{V}': 'V',
    r'\text{A}': 'A',
    r'\text{C}': 'C',
    r's = ut + \frac{1}{2}at^2': 's = ut + ½at²',
    r'v^2 = u^2 + 2as': 'v² = u² + 2as',
    r'E_k = \frac{1}{2}mv^2': 'Eₖ = ½mv²',
    r'E_p = mgh': 'Eₚ = mgh',
    r'P = \frac{W}{t}': 'P = W/t',
    r'v = f\lambda': 'v = fλ',
    r'\rho = \frac{m}{V}': 'ρ = m/V',
    r'P = \frac{F}{A}': 'P = F/A',
    r'Q = mc\Delta T': 'Q = mcΔT',
    r'\frac{1}{f}=\frac{1}{v}-\frac{1}{u}': '1/f = 1/v - 1/u',
    r'\bar{x}': 'x̄',
    r'\sigma^2': 'σ²',
    r'\sum x': 'Σx',
    r'P(A\cup B)': 'P(A∪B)',
    r'P(A\cap B)': 'P(A∩B)',
    r'\bar{x}=\frac{\sum x}{n}': 'x̄ = Σx/n',
    r'\sigma^2=\frac{\sum(x-\bar{x})^2}{n}': 'σ² = Σ(x-x̄)²/n',
    r'\sigma=\sqrt{\frac{\sum(x-\bar{x})^2}{n}}': 'σ = √(Σ(x-x̄)²/n)',
    r'{}^nC_r': 'ⁿCᵣ',
    r'{}^nP_r': 'ⁿPᵣ',
    r'\begin{pmatrix}  & \\  & \end{pmatrix}': '[2×2 matrix]',
    r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}': '[3×3 matrix]',
    r'\begin{vmatrix}  & \\  & \end{vmatrix}': '|A|',
    r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}': 'x = (-b ± √(b² - 4ac))⁄2a',
    r'a^2 + b^2 = c^2': 'a² + b² = c²',
    r'(x-h)^2 + (y-k)^2 = r^2': '(x-h)² + (y-k)² = r²',
    r'y = mx + c': 'y = mx + c',
    r'm = \frac{y_2-y_1}{x_2-x_1}': 'm = (y₂-y₁)⁄(x₂-x₁)',
    r'd = \sqrt{(x_2-x_1)^2 + (y_2-y_1)^2}': 'd = √((x₂-x₁)² + (y₂-y₁)²)',
    r'a_n = a + (n-1)d': 'aₙ = a + (n-1)d',
    r'S_n = \frac{n}{2}[2a+(n-1)d]': 'Sₙ = n⁄2[2a+(n-1)d]',
    r'a_n = ar^{n-1}': 'aₙ = arⁿ⁻¹',
    r'\bar{x} = \frac{\sum x}{n}': 'x̄ = ∑x⁄n',
    r'P(E)=\frac{\text{Favourable outcomes}}{\text{Total outcomes}}':
        'P(E)= favourable outcomes⁄total outcomes',
    r'A=\pi r^2': 'A = πr²',
    r'V=\frac{4}{3}\pi r^3': 'V = ⁴⁄₃πr³',
    r'\text{Solve: }': 'Solve: ',
    r'\text{Prove that }': 'Prove that ',
    r'\text{Find the value of } x': 'Find the value of x',
    r'\sin': 'sin()',
    r'\cos': 'cos()',
    r'\tan': 'tan()',
    r'\csc': 'csc()',
    r'\sec': 'sec()',
    r'\cot': 'cot()',
    r'\sin^2 \theta': 'sin²θ',
    r'\cos^2 \theta': 'cos²θ',
    r'\tan \theta': 'tanθ',
    r'\arcsin': 'arcsin()',
    r'\arccos': 'arccos()',
    r'\arctan': 'arctan()',
    r'\sinh': 'sinh()',
    r'\cosh': 'cosh()',
    r'\tanh': 'tanh()',
    r'\langle\rangle': '⟨⟩',
    r'\lfloor\rfloor': '⌊⌋',
    r'\lceil\rceil': '⌈⌉',
    r'\theta': 'θ',
    r'\phi': 'φ',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\epsilon': 'ε',
    r'\pi': 'π',
    r'\permil': '‰',
    r'\text{₹}': '₹',
    '(': '()',
    '[': '[]',
    '{': '{}',
  };
}
