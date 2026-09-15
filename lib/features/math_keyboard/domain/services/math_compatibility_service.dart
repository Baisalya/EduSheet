import 'dart:collection';

import 'package:flutter_math_fork/tex.dart' as renderer_tex;
import 'package:math_keyboard/math_keyboard.dart' as math_kb;

import '../catalog/math_symbol_catalog.dart';
import '../models/math_edit_command.dart';
import 'math_accessible_text_service.dart';
import 'math_dynamic_structure_codec.dart';
import 'math_export_typesetting.dart';
import 'math_production_policy.dart';

/// The concrete surface on which a formula is expected to be consumed.
enum MathCompatibilitySurface {
  visualEditor,
  screenRenderer,
  pdfExport,
  wordExport,
}

/// Capability level for a particular surface.
///
/// [native] means the surface can consume the TeX source directly.
/// [fallback] means EduSheet can keep the source safely but must use a readable
/// fallback on that surface. [sourceOnly] means the formula remains editable in
/// Advanced Source but cannot currently be reconstructed in the visual editor.
/// [unsupported] is reserved for malformed/empty source with no safe route.
enum MathCompatibilitySupport { native, fallback, sourceOnly, unsupported }

/// How the visual editor can reconstruct a source string.
enum MathVisualEditorStrategy {
  empty,
  dynamicStructure,
  parser,
  normalizedParser,
  catalogSymbol,
  legacyCommand,
  sourceOnly,
  unsupported,
}

class MathSurfaceCompatibility {
  final MathCompatibilitySurface surface;
  final MathCompatibilitySupport support;
  final String message;

  const MathSurfaceCompatibility({
    required this.surface,
    required this.support,
    required this.message,
  });

  bool get isUsable => support != MathCompatibilitySupport.unsupported;
  bool get isNative => support == MathCompatibilitySupport.native;
}

class MathSourceCompatibilityReport {
  final String source;
  final bool syntaxValid;
  final String readableFallback;
  final String? syntaxMessage;
  final bool resourceLimited;
  final String? resourceMessage;
  final MathVisualEditorStrategy visualStrategy;
  final String? normalizedVisualSource;
  final MathSurfaceCompatibility visualEditor;
  final MathSurfaceCompatibility screenRenderer;
  final MathSurfaceCompatibility pdfExport;
  final MathSurfaceCompatibility wordExport;

  const MathSourceCompatibilityReport({
    required this.source,
    required this.syntaxValid,
    required this.readableFallback,
    required this.visualStrategy,
    required this.visualEditor,
    required this.screenRenderer,
    required this.pdfExport,
    required this.wordExport,
    this.syntaxMessage,
    this.resourceLimited = false,
    this.resourceMessage,
    this.normalizedVisualSource,
  });

  MathSurfaceCompatibility forSurface(MathCompatibilitySurface surface) {
    switch (surface) {
      case MathCompatibilitySurface.visualEditor:
        return visualEditor;
      case MathCompatibilitySurface.screenRenderer:
        return screenRenderer;
      case MathCompatibilitySurface.pdfExport:
        return pdfExport;
      case MathCompatibilitySurface.wordExport:
        return wordExport;
    }
  }
}

/// Central compatibility policy for TeX authored in EduSheet.
///
/// This deliberately probes the two parser stacks independently:
/// - `math_keyboard` determines whether a saved source can be reconstructed as
///   an editable visual tree.
/// - `flutter_math_fork` determines whether the on-screen renderer accepts the
///   source before a widget is built.
///
/// PDF and Word are probed through the Phase 8 export-neutral typesetting
/// compiler. Sources inside that deterministic subset are native; everything
/// else keeps the readable Phase 6 fallback rather than being partially
/// interpreted.
class MathCompatibilityService {
  const MathCompatibilityService();

  MathSourceCompatibilityReport inspectSource(
    String source, {
    String plainFallback = '',
  }) {
    final trimmed = source.trim();
    final suppliedFallback = plainFallback.trim();
    final sourceBudget = const MathSourceBudgetGuard().inspect(trimmed);
    final fallback = suppliedFallback.isNotEmpty
        ? suppliedFallback
        : sourceBudget.withinBudget
        ? const MathAccessibleTextService().describe(trimmed)
        : 'Complex mathematical expression';

    if (trimmed.isEmpty) {
      return MathSourceCompatibilityReport(
        source: trimmed,
        syntaxValid: false,
        readableFallback: fallback,
        syntaxMessage: 'Formula source is empty.',
        visualStrategy: MathVisualEditorStrategy.empty,
        visualEditor: const MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.unsupported,
          message: 'There is no formula to edit.',
        ),
        screenRenderer: const MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.screenRenderer,
          support: MathCompatibilitySupport.unsupported,
          message: 'There is no formula to render.',
        ),
        pdfExport: _exportCompatibility(
          MathCompatibilitySurface.pdfExport,
          fallback,
        ),
        wordExport: _exportCompatibility(
          MathCompatibilitySurface.wordExport,
          fallback,
        ),
      );
    }

    if (!sourceBudget.withinBudget) {
      final message =
          sourceBudget.message ??
          'Formula exceeds EduSheet production complexity limits.';
      return MathSourceCompatibilityReport(
        source: trimmed,
        syntaxValid: true,
        readableFallback: fallback,
        resourceLimited: true,
        resourceMessage: message,
        visualStrategy: MathVisualEditorStrategy.sourceOnly,
        visualEditor: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.sourceOnly,
          message: '$message Source is preserved in Advanced Source.',
        ),
        screenRenderer: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.screenRenderer,
          support: MathCompatibilitySupport.fallback,
          message: '$message Readable fallback is used on screen.',
        ),
        pdfExport: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.pdfExport,
          support: MathCompatibilitySupport.fallback,
          message: '$message PDF uses the readable fallback.',
        ),
        wordExport: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.wordExport,
          support: MathCompatibilitySupport.fallback,
          message: '$message Word uses the readable fallback.',
        ),
      );
    }

    final syntaxError = _firstSyntaxError(trimmed);
    if (syntaxError != null) {
      return MathSourceCompatibilityReport(
        source: trimmed,
        syntaxValid: false,
        readableFallback: fallback,
        syntaxMessage: syntaxError,
        visualStrategy: MathVisualEditorStrategy.unsupported,
        visualEditor: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.unsupported,
          message: syntaxError,
        ),
        screenRenderer: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.screenRenderer,
          support: fallback.isEmpty
              ? MathCompatibilitySupport.unsupported
              : MathCompatibilitySupport.fallback,
          message: fallback.isEmpty
              ? syntaxError
              : 'Malformed TeX is not rendered; readable fallback is used.',
        ),
        pdfExport: _exportCompatibility(
          MathCompatibilitySurface.pdfExport,
          fallback,
        ),
        wordExport: _exportCompatibility(
          MathCompatibilitySurface.wordExport,
          fallback,
        ),
      );
    }

    final rendererNative = _rendererParses(trimmed);
    final screen = MathSurfaceCompatibility(
      surface: MathCompatibilitySurface.screenRenderer,
      support: rendererNative
          ? MathCompatibilitySupport.native
          : fallback.isEmpty
          ? MathCompatibilitySupport.unsupported
          : MathCompatibilitySupport.fallback,
      message: rendererNative
          ? 'flutter_math_fork accepts this source directly.'
          : fallback.isEmpty
          ? 'The renderer rejected this source and no readable fallback exists.'
          : 'The renderer rejected this source; readable fallback is used.',
    );

    final visual = _inspectVisual(trimmed, rendererNative: rendererNative);

    return MathSourceCompatibilityReport(
      source: trimmed,
      syntaxValid: true,
      readableFallback: fallback,
      visualStrategy: visual.strategy,
      normalizedVisualSource: visual.normalizedSource,
      visualEditor: visual.surface,
      screenRenderer: screen,
      pdfExport: _exportCompatibility(
        MathCompatibilitySurface.pdfExport,
        fallback,
        source: trimmed,
      ),
      wordExport: _exportCompatibility(
        MathCompatibilitySurface.wordExport,
        fallback,
        source: trimmed,
      ),
    );
  }

  _VisualProbe _inspectVisual(String source, {required bool rendererNative}) {
    final dynamic = const MathDynamicStructureCodec().tryParse(source);
    if (dynamic != null) {
      return const _VisualProbe(
        strategy: MathVisualEditorStrategy.dynamicStructure,
        surface: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.native,
          message:
              'EduSheet can rebuild this dynamic structure as editable slots.',
        ),
      );
    }

    if (_visualParserParses(source)) {
      return const _VisualProbe(
        strategy: MathVisualEditorStrategy.parser,
        surface: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.native,
          message: 'math_keyboard can parse this source directly.',
        ),
      );
    }

    final normalized = _normalizeVisualVariables(source);
    if (normalized != source && _visualParserParses(normalized)) {
      return _VisualProbe(
        strategy: MathVisualEditorStrategy.normalizedParser,
        normalizedSource: normalized,
        surface: const MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.native,
          message:
              'The source can be reopened after safe variable normalization.',
        ),
      );
    }

    final catalogSymbol = MathSymbolCatalog.findByTex(source);
    if (catalogSymbol != null && rendererNative) {
      return const _VisualProbe(
        strategy: MathVisualEditorStrategy.catalogSymbol,
        surface: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.native,
          message:
              'The source is reconstructed from its catalogue insertion recipe.',
        ),
      );
    }

    if (MathLegacyEditCommandRegistry.bySource.containsKey(source) &&
        rendererNative) {
      return const _VisualProbe(
        strategy: MathVisualEditorStrategy.legacyCommand,
        surface: MathSurfaceCompatibility(
          surface: MathCompatibilitySurface.visualEditor,
          support: MathCompatibilitySupport.native,
          message:
              'The source is reconstructed from the declarative compatibility registry.',
        ),
      );
    }

    return const _VisualProbe(
      strategy: MathVisualEditorStrategy.sourceOnly,
      surface: MathSurfaceCompatibility(
        surface: MathCompatibilitySurface.visualEditor,
        support: MathCompatibilitySupport.sourceOnly,
        message:
            'Keep editing this formula in Advanced Source; the visual editor cannot reconstruct it yet.',
      ),
    );
  }

  bool _visualParserParses(String source) {
    try {
      math_kb.TeXParser(source).parse();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _rendererParses(String source) {
    try {
      renderer_tex.TexParser(source, renderer_tex.TexParserSettings()).parse();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _normalizeVisualVariables(String source) {
    return source.replaceAllMapped(
      RegExp(r'(?<![\\A-Za-z{])[A-Za-z]+(?![A-Za-z}])'),
      (match) => '{${match.group(0)}}',
    );
  }

  String? _firstSyntaxError(String source) {
    final delimiterError = _firstBalanceError(source);
    if (delimiterError != null) return delimiterError;
    return _environmentError(source);
  }

  String? _firstBalanceError(String source) {
    final stack = <String>[];
    const opening = <String, String>{'{': '}', '[': ']', '(': ')'};
    const closing = <String, String>{'}': '{', ']': '[', ')': '('};
    var escaped = false;
    for (final codePoint in source.runes) {
      final character = String.fromCharCode(codePoint);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (character == '\\') {
        escaped = true;
        continue;
      }
      if (opening.containsKey(character)) {
        stack.add(character);
      } else if (closing.containsKey(character)) {
        if (stack.isEmpty || stack.last != closing[character]) {
          return 'Formula has an unmatched “$character”.';
        }
        stack.removeLast();
      }
    }
    if (stack.isNotEmpty) {
      return 'Formula is missing “${opening[stack.last]}”.';
    }
    return null;
  }

  String? _environmentError(String source) {
    final stack = <String>[];
    final matches = RegExp(r'\\(begin|end)\{([^{}]+)\}').allMatches(source);
    for (final match in matches) {
      final operation = match.group(1)!;
      final environment = match.group(2)!;
      if (operation == 'begin') {
        stack.add(environment);
        continue;
      }
      if (stack.isEmpty) {
        return 'Formula closes “$environment” without opening it.';
      }
      final opened = stack.removeLast();
      if (opened != environment) {
        return 'Formula opens “$opened” but closes “$environment”.';
      }
    }

    final hasRawBegin = source.contains(r'\begin');
    final hasRawEnd = source.contains(r'\end');
    if (matches.isEmpty && (hasRawBegin || hasRawEnd)) {
      return 'Formula has an incomplete environment declaration.';
    }
    if (stack.isNotEmpty) {
      return 'Formula is missing “\\end{${stack.last}}”.';
    }
    return null;
  }

  static MathSurfaceCompatibility _exportCompatibility(
    MathCompatibilitySurface surface,
    String fallback, {
    String? source,
  }) {
    final label = surface == MathCompatibilitySurface.pdfExport
        ? 'PDF'
        : 'Word';
    if (source != null && MathExportTypesettingCache.shared.supports(source)) {
      return MathSurfaceCompatibility(
        surface: surface,
        support: MathCompatibilitySupport.native,
        message:
            '$label can typeset this source through the Phase 8 export math tree.',
      );
    }
    if (fallback.isEmpty) {
      return MathSurfaceCompatibility(
        surface: surface,
        support: MathCompatibilitySupport.sourceOnly,
        message:
            '$label cannot safely typeset this source and no readable fallback was supplied.',
      );
    }
    return MathSurfaceCompatibility(
      surface: surface,
      support: MathCompatibilitySupport.fallback,
      message:
          '$label uses the readable fallback because this TeX is outside the native export subset.',
    );
  }
}

class _VisualProbe {
  final MathVisualEditorStrategy strategy;
  final MathSurfaceCompatibility surface;
  final String? normalizedSource;

  const _VisualProbe({
    required this.strategy,
    required this.surface,
    this.normalizedSource,
  });
}

class MathCompatibilityCache {
  static final MathCompatibilityCache shared = MathCompatibilityCache();

  final int maximumEntries;
  final MathCompatibilityService service;
  final LinkedHashMap<String, MathSourceCompatibilityReport> _entries =
      LinkedHashMap<String, MathSourceCompatibilityReport>();
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  MathCompatibilityCache({
    this.maximumEntries = MathProductionLimits.compatibilityCacheEntries,
    this.service = const MathCompatibilityService(),
  }) : assert(maximumEntries > 0);

  int get length => _entries.length;

  MathSourceCompatibilityReport inspectSource(
    String source, {
    String plainFallback = '',
  }) {
    final key = '${source.trim()}\u0000${plainFallback.trim()}';
    final cached = _entries.remove(key);
    if (cached != null) {
      _hits += 1;
      _entries[key] = cached;
      return cached;
    }
    _misses += 1;
    final report = service.inspectSource(source, plainFallback: plainFallback);
    _entries[key] = report;
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
      _evictions += 1;
    }
    return report;
  }

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
