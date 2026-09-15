import 'dart:collection';

import 'math_production_policy.dart';

/// Export-neutral mathematical layout tree used by the PDF and Word writers.
///
/// This is intentionally smaller than TeX. The compiler accepts the notation
/// families EduSheet can render deterministically in both export formats and
/// returns `null` for anything outside that contract. Exporters must then use
/// the Phase 6 readable fallback rather than partially interpreting a formula.
sealed class MathExportNode {
  const MathExportNode();
}

final class MathExportSequence extends MathExportNode {
  final List<MathExportNode> children;
  const MathExportSequence(this.children);
}

final class MathExportText extends MathExportNode {
  final String value;
  final bool upright;
  final bool bold;

  const MathExportText(this.value, {this.upright = false, this.bold = false});
}

final class MathExportFraction extends MathExportNode {
  final MathExportNode numerator;
  final MathExportNode denominator;
  const MathExportFraction(this.numerator, this.denominator);
}

final class MathExportBinomial extends MathExportNode {
  final MathExportNode top;
  final MathExportNode bottom;
  const MathExportBinomial(this.top, this.bottom);
}

final class MathExportRoot extends MathExportNode {
  final MathExportNode radicand;
  final MathExportNode? index;
  const MathExportRoot(this.radicand, {this.index});
}

final class MathExportScript extends MathExportNode {
  final MathExportNode base;
  final MathExportNode? subscript;
  final MathExportNode? superscript;

  const MathExportScript(this.base, {this.subscript, this.superscript});
}

final class MathExportAccent extends MathExportNode {
  final MathExportNode body;
  final MathExportAccentKind kind;
  const MathExportAccent(this.body, this.kind);
}

enum MathExportAccentKind { vector, overline, hat, bar, tilde }

final class MathExportDelimited extends MathExportNode {
  final String left;
  final MathExportNode body;
  final String right;
  const MathExportDelimited(this.left, this.body, this.right);
}

final class MathExportMatrix extends MathExportNode {
  final List<List<MathExportNode>> rows;
  final String leftDelimiter;
  final String rightDelimiter;
  final bool casesStyle;

  const MathExportMatrix({
    required this.rows,
    this.leftDelimiter = '',
    this.rightDelimiter = '',
    this.casesStyle = false,
  });
}

/// Deterministic TeX -> export layout compiler.
///
/// Unknown commands, malformed groups and unsupported environments fail the
/// whole compile. This all-or-nothing rule is critical for booklet fidelity:
/// an unsupported formula must remain readable rather than becoming a subtly
/// wrong equation in PDF/Word.
class MathExportTypesettingCompiler {
  const MathExportTypesettingCompiler();

  MathExportNode? compile(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;
    final sourceBudget = const MathSourceBudgetGuard().inspect(trimmed);
    if (!sourceBudget.withinBudget) return null;
    final parser = _MathExportParser(trimmed);
    final node = parser.parse();
    if (node == null || !parser.isAtEnd) return null;
    return _compact(node);
  }

  bool supports(String source) => compile(source) != null;

  static MathExportNode _compact(MathExportNode node) {
    if (node is! MathExportSequence) return node;
    final children = <MathExportNode>[];
    var pendingText = '';
    void flush() {
      if (pendingText.isEmpty) return;
      children.add(MathExportText(pendingText));
      pendingText = '';
    }

    for (final child in node.children) {
      final compacted = _compact(child);
      if (compacted is MathExportText &&
          !compacted.upright &&
          !compacted.bold) {
        pendingText += compacted.value;
      } else {
        flush();
        children.add(compacted);
      }
    }
    flush();
    if (children.length == 1) return children.single;
    return MathExportSequence(children);
  }
}

class MathExportTypesettingCache {
  static final MathExportTypesettingCache shared = MathExportTypesettingCache();

  final int maximumEntries;
  final MathExportTypesettingCompiler compiler;
  final LinkedHashMap<String, _CachedMathExportCompilation> _entries =
      LinkedHashMap<String, _CachedMathExportCompilation>();

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  MathExportTypesettingCache({
    this.maximumEntries = MathProductionLimits.exportCompilationCacheEntries,
    this.compiler = const MathExportTypesettingCompiler(),
  }) : assert(maximumEntries > 0);

  int get length => _entries.length;

  MathExportNode? compile(String source) {
    final key = source.trim();
    if (key.isEmpty) return null;
    final cached = _entries.remove(key);
    if (cached != null) {
      _hits += 1;
      _entries[key] = cached;
      return cached.node;
    }

    _misses += 1;
    final node = compiler.compile(key);
    _entries[key] = _CachedMathExportCompilation(node);
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
      _evictions += 1;
    }
    return node;
  }

  bool supports(String source) => compile(source) != null;

  MathCacheSnapshot get snapshot => MathCacheSnapshot(
    entries: _entries.length,
    maximumEntries: maximumEntries,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
  );

  void clear({bool resetStatistics = false}) {
    _entries.clear();
    if (resetStatistics) {
      _hits = 0;
      _misses = 0;
      _evictions = 0;
    }
  }
}

class _CachedMathExportCompilation {
  final MathExportNode? node;
  const _CachedMathExportCompilation(this.node);
}

class _MathExportParser {
  final String source;
  int index = 0;
  bool failed = false;
  int _steps = 0;
  int _depth = 0;

  _MathExportParser(this.source);

  bool get isAtEnd => !failed && index == source.length;
  bool get _eof => index >= source.length;

  MathExportNode? parse() {
    final node = _parseSequence();
    if (failed || !_eof) return null;
    return node;
  }

  MathExportNode _parseSequence({String? stop}) {
    _depth += 1;
    if (_depth > MathProductionLimits.maxExportParserDepth) {
      failed = true;
      _depth -= 1;
      return const MathExportSequence(<MathExportNode>[]);
    }

    final children = <MathExportNode>[];
    try {
      while (!_eof) {
        _steps += 1;
        if (_steps > MathProductionLimits.maxExportParserSteps) {
          failed = true;
          break;
        }
        if (stop != null && source[index] == stop) break;
        final primary = _parsePrimary();
        if (primary == null) {
          failed = true;
          break;
        }
        var node = primary;
        MathExportNode? subscript;
        MathExportNode? superscript;
        while (!_eof && (source[index] == '^' || source[index] == '_')) {
          final marker = source[index++];
          final script = _parseScriptArgument();
          if (script == null) {
            failed = true;
            break;
          }
          if (marker == '^') {
            superscript = script;
          } else {
            subscript = script;
          }
        }
        if (subscript != null || superscript != null) {
          node = MathExportScript(
            node,
            subscript: subscript,
            superscript: superscript,
          );
        }
        children.add(node);
      }
      return MathExportSequence(children);
    } finally {
      _depth -= 1;
    }
  }

  MathExportNode? _parsePrimary() {
    if (_eof) return null;
    final char = source[index];
    if (char == '{') return _parseRequiredGroup();
    if (char == '}') return null;
    if (char == r'\') return _parseCommand();
    if (char == '&') return null;

    if (_isWhitespace(char)) {
      while (!_eof && _isWhitespace(source[index])) {
        index++;
      }
      return const MathExportText(' ');
    }

    final start = index;
    while (!_eof) {
      final current = source[index];
      if (current == r'\' ||
          current == '{' ||
          current == '}' ||
          current == '^' ||
          current == '_' ||
          current == '&' ||
          _isWhitespace(current)) {
        break;
      }
      index++;
    }
    if (index == start) {
      index++;
      return MathExportText(char);
    }
    return MathExportText(source.substring(start, index));
  }

  MathExportNode? _parseCommand() {
    if (_eof || source[index] != r'\') return null;
    index++;
    if (_eof) return null;

    String command;
    if (_isAsciiLetter(source[index])) {
      final start = index;
      while (!_eof && _isAsciiLetter(source[index])) {
        index++;
      }
      command = source.substring(start, index);
    } else {
      command = source[index++];
    }

    switch (command) {
      case r'\':
        return const MathExportText(' ');
      case ',':
      case ':':
      case ';':
        return const MathExportText(' ');
      case '!':
        return const MathExportText('');
      case 'quad':
        return const MathExportText('  ');
      case 'qquad':
        return const MathExportText('    ');
      case '{':
        return const MathExportText('{');
      case '}':
        return const MathExportText('}');
      case '%':
        return const MathExportText('%');
      case '#':
        return const MathExportText('#');
      case '&':
        return const MathExportText('&');
      case '_':
        return const MathExportText('_');
      case 'frac':
      case 'dfrac':
      case 'tfrac':
        final numerator = _parseRequiredGroup();
        final denominator = _parseRequiredGroup();
        if (numerator == null || denominator == null) return null;
        return MathExportFraction(numerator, denominator);
      case 'sqrt':
        MathExportNode? rootIndex;
        _skipTeXWhitespace();
        if (!_eof && source[index] == '[') {
          final raw = _consumeBalanced('[', ']');
          if (raw == null) return null;
          rootIndex = const MathExportTypesettingCompiler().compile(raw);
          if (rootIndex == null) return null;
        }
        final radicand = _parseRequiredGroup();
        if (radicand == null) return null;
        return MathExportRoot(radicand, index: rootIndex);
      case 'pmod':
        final modulus = _parseRequiredGroup();
        if (modulus == null) return null;
        return MathExportSequence([
          const MathExportText('('),
          const MathExportText('mod', upright: true),
          const MathExportText(' '),
          modulus,
          const MathExportText(')'),
        ]);
      case 'xrightarrow':
      case 'xleftarrow':
        final label = _parseRequiredGroup();
        if (label == null) return null;
        return MathExportScript(
          MathExportText(command == 'xrightarrow' ? '→' : '←'),
          superscript: label,
        );
      case 'binom':
        final top = _parseRequiredGroup();
        final bottom = _parseRequiredGroup();
        if (top == null || bottom == null) return null;
        return MathExportBinomial(top, bottom);
      case 'vec':
      case 'overrightarrow':
        final body = _parseRequiredGroup();
        return body == null
            ? null
            : MathExportAccent(body, MathExportAccentKind.vector);
      case 'overline':
        final body = _parseRequiredGroup();
        return body == null
            ? null
            : MathExportAccent(body, MathExportAccentKind.overline);
      case 'bar':
        final body = _parseRequiredGroup();
        return body == null
            ? null
            : MathExportAccent(body, MathExportAccentKind.bar);
      case 'hat':
      case 'widehat':
        final body = _parseRequiredGroup();
        return body == null
            ? null
            : MathExportAccent(body, MathExportAccentKind.hat);
      case 'tilde':
      case 'widetilde':
        final body = _parseRequiredGroup();
        return body == null
            ? null
            : MathExportAccent(body, MathExportAccentKind.tilde);
      case 'mathrm':
      case 'text':
      case 'operatorname':
        final body = _parseRequiredGroup();
        return body == null ? null : _forceUpright(body);
      case 'mathbf':
        final body = _parseRequiredGroup();
        return body == null ? null : _forceBold(body);
      case 'mathit':
        return _parseRequiredGroup();
      case 'mathbb':
        final raw = _consumeRequiredGroupRaw();
        if (raw == null || raw.isEmpty) return null;
        return MathExportText(_doubleStruck(raw));
      case 'big':
      case 'Big':
      case 'bigg':
      case 'Bigg':
      case 'bigl':
      case 'bigr':
      case 'Bigl':
      case 'Bigr':
      case 'biggl':
      case 'biggr':
      case 'Biggl':
      case 'Biggr':
        return _parsePrimary();
      case 'displaystyle':
      case 'textstyle':
      case 'scriptstyle':
        return const MathExportText('');
      case 'left':
      case 'right':
        return _parseDelimiterToken();
      case 'begin':
        return _parseEnvironment();
      case 'end':
        return null;
      case 'overset':
        final over = _parseRequiredGroup();
        final base = _parseRequiredGroup();
        if (over == null || base == null) return null;
        return MathExportScript(base, superscript: over);
      case 'underset':
        final under = _parseRequiredGroup();
        final base = _parseRequiredGroup();
        if (under == null || base == null) return null;
        return MathExportScript(base, subscript: under);
    }

    final mapped = _commandSymbols[command];
    if (mapped != null) return MathExportText(mapped);
    if (_uprightCommands.contains(command)) {
      return MathExportText(command, upright: true);
    }
    return null;
  }

  MathExportNode? _parseEnvironment() {
    final environment = _consumeRequiredGroupRaw();
    if (environment == null) return null;

    List<int> arraySeparators = const [];
    if (environment == 'array') {
      final columnSpec = _consumeRequiredGroupRaw();
      if (columnSpec == null) return null;
      arraySeparators = _arraySeparatorColumns(columnSpec);
    }

    final endMarker = '\\end{$environment}';
    final endIndex = _findEnvironmentEnd(environment, index);
    if (endIndex < 0) return null;
    final body = source.substring(index, endIndex);
    index = endIndex + endMarker.length;

    if (!_supportedEnvironments.contains(environment)) return null;
    final rawRows = _splitEnvironment(body, r'\\');
    if (rawRows.isEmpty ||
        rawRows.length > MathProductionLimits.maxExportEnvironmentRows) {
      failed = true;
      return null;
    }

    var totalCells = 0;
    final rows = <List<MathExportNode>>[];
    for (final rawRow in rawRows) {
      final cells = _splitEnvironment(rawRow, '&');
      totalCells += cells.length;
      if (cells.length > MathProductionLimits.maxExportEnvironmentColumns ||
          totalCells > MathProductionLimits.maxExportEnvironmentCells) {
        failed = true;
        return null;
      }
      final parsedCells = cells
          .map((cell) {
            final parsed = const MathExportTypesettingCompiler().compile(cell);
            if (parsed == null) failed = true;
            return parsed ?? const MathExportText('');
          })
          .toList(growable: false);
      rows.add(
        environment != 'array' || arraySeparators.isEmpty
            ? parsedCells
            : _insertArraySeparators(parsedCells, arraySeparators),
      );
    }
    if (failed) return null;

    return switch (environment) {
      'pmatrix' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '(',
        rightDelimiter: ')',
      ),
      'bmatrix' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '[',
        rightDelimiter: ']',
      ),
      'Bmatrix' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '{',
        rightDelimiter: '}',
      ),
      'vmatrix' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '|',
        rightDelimiter: '|',
      ),
      'Vmatrix' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '‖',
        rightDelimiter: '‖',
      ),
      'cases' => MathExportMatrix(
        rows: rows,
        leftDelimiter: '{',
        casesStyle: true,
      ),
      'matrix' || 'array' || 'aligned' => MathExportMatrix(rows: rows),
      _ => null,
    };
  }

  List<int> _arraySeparatorColumns(String spec) {
    final separators = <int>[];
    var column = 0;
    for (var i = 0; i < spec.length; i++) {
      final char = spec[i];
      if (char == 'l' || char == 'c' || char == 'r') {
        column++;
      } else if (char == '|' && column > 0) {
        separators.add(column);
      }
    }
    return separators;
  }

  List<MathExportNode> _insertArraySeparators(
    List<MathExportNode> cells,
    List<int> separatorsAfterColumn,
  ) {
    final result = <MathExportNode>[];
    for (var index = 0; index < cells.length; index++) {
      result.add(cells[index]);
      final oneBasedColumn = index + 1;
      if (separatorsAfterColumn.contains(oneBasedColumn) &&
          oneBasedColumn < cells.length) {
        result.add(const MathExportText('│', upright: true));
      }
    }
    return result;
  }

  int _findEnvironmentEnd(String environment, int from) {
    final beginMarker = '\\begin{$environment}';
    final endMarker = '\\end{$environment}';
    var depth = 1;
    var cursor = from;
    while (cursor < source.length) {
      final nextBegin = source.indexOf(beginMarker, cursor);
      final nextEnd = source.indexOf(endMarker, cursor);
      if (nextEnd < 0) return -1;
      if (nextBegin >= 0 && nextBegin < nextEnd) {
        depth++;
        cursor = nextBegin + beginMarker.length;
      } else {
        depth--;
        if (depth == 0) return nextEnd;
        cursor = nextEnd + endMarker.length;
      }
    }
    return -1;
  }

  List<String> _splitEnvironment(String value, String delimiter) {
    final result = <String>[];
    var braceDepth = 0;
    var bracketDepth = 0;
    var start = 0;
    var i = 0;
    while (i < value.length) {
      final char = value[i];
      if (char == '{') braceDepth++;
      if (char == '}' && braceDepth > 0) braceDepth--;
      if (char == '[') bracketDepth++;
      if (char == ']' && bracketDepth > 0) bracketDepth--;
      if (braceDepth == 0 &&
          bracketDepth == 0 &&
          value.startsWith(delimiter, i)) {
        result.add(value.substring(start, i).trim());
        i += delimiter.length;
        start = i;
        continue;
      }
      i++;
    }
    result.add(value.substring(start).trim());
    return result;
  }

  MathExportNode? _parseDelimiterToken() {
    _skipTeXWhitespace();
    if (_eof) return null;
    if (source[index] == r'\') {
      index++;
      if (_eof) return null;
      if (_isAsciiLetter(source[index])) {
        final start = index;
        while (!_eof && _isAsciiLetter(source[index])) {
          index++;
        }
        final command = source.substring(start, index);
        final delimiter = _delimiterCommands[command];
        return delimiter == null ? null : MathExportText(delimiter);
      }
      final command = source[index++];
      final delimiter = _delimiterCommands[command] ?? command;
      return MathExportText(delimiter);
    }
    final delimiter = source[index++];
    return MathExportText(delimiter == '.' ? '' : delimiter);
  }

  MathExportNode? _parseRequiredGroup() {
    _skipTeXWhitespace();
    if (_eof || source[index] != '{') return null;
    index++;
    final node = _parseSequence(stop: '}');
    if (_eof || source[index] != '}') return null;
    index++;
    return node;
  }

  String? _consumeRequiredGroupRaw() {
    _skipTeXWhitespace();
    if (_eof || source[index] != '{') return null;
    return _consumeBalanced('{', '}');
  }

  String? _consumeBalanced(String open, String close) {
    if (_eof || source[index] != open) return null;
    index++;
    final start = index;
    var depth = 1;
    while (!_eof) {
      final char = source[index++];
      if (char == open) depth++;
      if (char == close) {
        depth--;
        if (depth == 0) {
          return source.substring(start, index - 1);
        }
      }
    }
    return null;
  }

  MathExportNode? _parseScriptArgument() {
    _skipTeXWhitespace();
    if (_eof) return null;
    if (source[index] == '{') return _parseRequiredGroup();
    return _parsePrimary();
  }

  void _skipTeXWhitespace() {
    while (!_eof && _isWhitespace(source[index])) {
      index++;
    }
  }

  static bool _isWhitespace(String value) =>
      value == ' ' || value == '\n' || value == '\r' || value == '\t';

  static bool _isAsciiLetter(String value) {
    final code = value.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static MathExportNode _forceUpright(MathExportNode node) {
    if (node is MathExportText) {
      return MathExportText(node.value, upright: true, bold: node.bold);
    }
    if (node is MathExportSequence) {
      return MathExportSequence(node.children.map(_forceUpright).toList());
    }
    return node;
  }

  static MathExportNode _forceBold(MathExportNode node) {
    if (node is MathExportText) {
      return MathExportText(node.value, upright: node.upright, bold: true);
    }
    if (node is MathExportSequence) {
      return MathExportSequence(node.children.map(_forceBold).toList());
    }
    return node;
  }

  static String _doubleStruck(String value) {
    const common = <String, String>{
      'N': 'ℕ',
      'Z': 'ℤ',
      'Q': 'ℚ',
      'R': 'ℝ',
      'C': 'ℂ',
      'H': 'ℍ',
      'P': 'ℙ',
    };
    return value.split('').map((char) => common[char] ?? char).join();
  }
}

const _supportedEnvironments = <String>{
  'matrix',
  'pmatrix',
  'bmatrix',
  'Bmatrix',
  'vmatrix',
  'Vmatrix',
  'array',
  'cases',
  'aligned',
};

const _uprightCommands = <String>{
  'sin',
  'cos',
  'tan',
  'cot',
  'sec',
  'csc',
  'arcsin',
  'arccos',
  'arctan',
  'sinh',
  'cosh',
  'tanh',
  'log',
  'ln',
  'exp',
  'lim',
  'max',
  'min',
  'gcd',
  'lcm',
  'arg',
  'det',
  'mod',
  'bmod',
  'Pr',
};

const _delimiterCommands = <String, String>{
  '{': '{',
  '}': '}',
  'lbrace': '{',
  'rbrace': '}',
  'langle': '⟨',
  'rangle': '⟩',
  'lvert': '|',
  'rvert': '|',
  'lVert': '‖',
  'rVert': '‖',
  'vert': '|',
  'Vert': '‖',
  '|': '‖',
  '.': '',
};

const _commandSymbols = <String, String>{
  // Greek.
  'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ',
  'epsilon': 'ε', 'varepsilon': 'ϵ', 'zeta': 'ζ', 'eta': 'η',
  'theta': 'θ', 'vartheta': 'ϑ', 'iota': 'ι', 'kappa': 'κ',
  'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'omicron': 'ο',
  'pi': 'π', 'varpi': 'ϖ', 'rho': 'ρ', 'varrho': 'ϱ', 'sigma': 'σ',
  'varsigma': 'ς', 'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ',
  'varphi': 'ϕ', 'chi': 'χ', 'psi': 'ψ', 'omega': 'ω',
  'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Xi': 'Ξ',
  'Pi': 'Π', 'Sigma': 'Σ', 'Upsilon': 'Υ', 'Phi': 'Φ', 'Psi': 'Ψ',
  'Omega': 'Ω',
  // Arithmetic/operators.
  'times': '×', 'div': '÷', 'cdot': '·', 'pm': '±', 'mp': '∓',
  'ast': '∗', 'star': '⋆', 'circ': '∘', 'bullet': '•',
  'oplus': '⊕', 'otimes': '⊗', 'ominus': '⊖', 'oslash': '⊘',
  'sum': '∑', 'prod': '∏', 'coprod': '∐', 'int': '∫', 'iint': '∬',
  'iiint': '∭', 'oint': '∮', 'oiint': '∯', 'oiiint': '∰',
  'partial': '∂', 'nabla': '∇',
  'infty': '∞',
  // Relations and sets.
  'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'ne': '≠',
  'neq': '≠', 'approx': '≈', 'sim': '∼', 'simeq': '≃', 'equiv': '≡',
  'propto': '∝', 'cong': '≅', 'll': '≪', 'gg': '≫',
  'in': '∈', 'notin': '∉', 'ni': '∋', 'subset': '⊂', 'subseteq': '⊆',
  'supset': '⊃', 'supseteq': '⊇', 'nsubseteq': '⊈', 'nsupseteq': '⊉',
  'cup': '∪', 'cap': '∩', 'bigcup': '⋃', 'bigcap': '⋂',
  'setminus': '∖', 'emptyset': '∅', 'varnothing': '∅',
  'forall': '∀', 'exists': '∃', 'nexists': '∄', 'neg': '¬',
  'land': '∧', 'lor': '∨', 'therefore': '∴', 'because': '∵',
  'vdash': '⊢', 'dashv': '⊣', 'models': '⊨', 'perp': '⊥', 'parallel': '∥',
  'mid': '∣', 'nmid': '∤',
  // Arrows/mappings.
  'to': '→', 'rightarrow': '→', 'leftarrow': '←', 'leftrightarrow': '↔',
  'Rightarrow': '⇒', 'Leftarrow': '⇐', 'Leftrightarrow': '⇔',
  'mapsto': '↦', 'longmapsto': '⟼', 'longrightarrow': '⟶',
  'longleftarrow': '⟵', 'longleftrightarrow': '⟷',
  'uparrow': '↑', 'downarrow': '↓', 'updownarrow': '↕',
  'hookrightarrow': '↪', 'hookleftarrow': '↩', 'rightleftharpoons': '⇌',
  'rightharpoonup': '⇀', 'rightharpoondown': '⇁',
  'leftharpoonup': '↼', 'leftharpoondown': '↽',
  // Misc.
  'angle': '∠',
  'triangle': '△',
  'square': '□',
  'degree': '°',
  'ell': 'ℓ',
  'hbar': 'ℏ',
  'colon': ':', 'dots': '…', 'langle': '⟨', 'rangle': '⟩',
  'lvert': '|',
  'rvert': '|',
  'lVert': '‖',
  'rVert': '‖',
  'vert': '|',
  'Vert': '‖',
  'Re': 'ℜ', 'Im': 'ℑ', 'prime': '′', 'cdots': '⋯', 'ldots': '…',
  'vdots': '⋮', 'ddots': '⋱',
};
