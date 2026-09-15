import '../catalog/math_symbol_catalog.dart';
import '../models/math_symbol.dart';
import '../services/math_compatibility_service.dart';

class MathCompatibilityAuditor {
  final MathCompatibilityService service;

  const MathCompatibilityAuditor({
    this.service = const MathCompatibilityService(),
  });

  MathCompatibilityAuditSnapshot capture({List<MathSymbol>? symbols}) {
    final inspected = symbols ?? MathSymbolCatalog.canonicalSymbols;
    final visualNativeIds = <String>[];
    final visualSourceOnlyIds = <String>[];
    final rendererNativeIds = <String>[];
    final rendererFallbackIds = <String>[];
    final pdfNativeIds = <String>[];
    final pdfFallbackIds = <String>[];
    final wordNativeIds = <String>[];
    final wordFallbackIds = <String>[];
    final syntaxInvalidIds = <String>[];
    final intentionalFragmentIds = <String>[];

    for (final symbol in inspected) {
      final report = service.inspectSource(
        symbol.tex,
        plainFallback: symbol.accessibilityLabel,
      );
      final isIntentionalFragment =
          !report.syntaxValid &&
          symbol.isStructural &&
          symbol.editorCommand != null;
      if (isIntentionalFragment) {
        intentionalFragmentIds.add(symbol.id);
      } else if (!report.syntaxValid) {
        syntaxInvalidIds.add(symbol.id);
      }

      if (isIntentionalFragment) {
        // Some builder catalogue entries intentionally store an insertion seed
        // such as `(`, `[` or `{` rather than a finished standalone formula.
        // Their declarative command is the visual-editor contract; treating the
        // seed as malformed would conflate insertion metadata with persisted TeX.
        visualNativeIds.add(symbol.id);
      } else {
        switch (report.visualEditor.support) {
          case MathCompatibilitySupport.native:
            visualNativeIds.add(symbol.id);
          case MathCompatibilitySupport.sourceOnly:
          case MathCompatibilitySupport.fallback:
            visualSourceOnlyIds.add(symbol.id);
          case MathCompatibilitySupport.unsupported:
            if (!syntaxInvalidIds.contains(symbol.id)) {
              syntaxInvalidIds.add(symbol.id);
            }
        }
      }

      switch (report.screenRenderer.support) {
        case MathCompatibilitySupport.native:
          rendererNativeIds.add(symbol.id);
        case MathCompatibilitySupport.fallback:
        case MathCompatibilitySupport.sourceOnly:
          rendererFallbackIds.add(symbol.id);
        case MathCompatibilitySupport.unsupported:
          rendererFallbackIds.add(symbol.id);
      }

      switch (report.pdfExport.support) {
        case MathCompatibilitySupport.native:
          pdfNativeIds.add(symbol.id);
        case MathCompatibilitySupport.fallback:
        case MathCompatibilitySupport.sourceOnly:
        case MathCompatibilitySupport.unsupported:
          pdfFallbackIds.add(symbol.id);
      }
      switch (report.wordExport.support) {
        case MathCompatibilitySupport.native:
          wordNativeIds.add(symbol.id);
        case MathCompatibilitySupport.fallback:
        case MathCompatibilitySupport.sourceOnly:
        case MathCompatibilitySupport.unsupported:
          wordFallbackIds.add(symbol.id);
      }
    }

    return MathCompatibilityAuditSnapshot(
      semanticCount: inspected.length,
      visualNativeIds: List.unmodifiable(visualNativeIds..sort()),
      visualSourceOnlyIds: List.unmodifiable(visualSourceOnlyIds..sort()),
      rendererNativeIds: List.unmodifiable(rendererNativeIds..sort()),
      rendererFallbackIds: List.unmodifiable(rendererFallbackIds..sort()),
      pdfNativeIds: List.unmodifiable(pdfNativeIds..sort()),
      pdfFallbackIds: List.unmodifiable(pdfFallbackIds..sort()),
      wordNativeIds: List.unmodifiable(wordNativeIds..sort()),
      wordFallbackIds: List.unmodifiable(wordFallbackIds..sort()),
      syntaxInvalidIds: List.unmodifiable(syntaxInvalidIds..sort()),
      intentionalFragmentIds: List.unmodifiable(intentionalFragmentIds..sort()),
    );
  }
}

class MathCompatibilityAuditSnapshot {
  final int semanticCount;
  final List<String> visualNativeIds;
  final List<String> visualSourceOnlyIds;
  final List<String> rendererNativeIds;
  final List<String> rendererFallbackIds;
  final List<String> pdfNativeIds;
  final List<String> pdfFallbackIds;
  final List<String> wordNativeIds;
  final List<String> wordFallbackIds;
  final List<String> syntaxInvalidIds;

  /// Catalogue entries whose raw [MathSymbol.tex] is intentionally only an
  /// insertion seed. They are safe because a declarative editor command owns
  /// construction of the completed visual structure.
  final List<String> intentionalFragmentIds;

  const MathCompatibilityAuditSnapshot({
    required this.semanticCount,
    required this.visualNativeIds,
    required this.visualSourceOnlyIds,
    required this.rendererNativeIds,
    required this.rendererFallbackIds,
    required this.pdfNativeIds,
    required this.pdfFallbackIds,
    required this.wordNativeIds,
    required this.wordFallbackIds,
    required this.syntaxInvalidIds,
    required this.intentionalFragmentIds,
  });

  int get visualNativeCount => visualNativeIds.length;
  int get visualSourceOnlyCount => visualSourceOnlyIds.length;
  int get rendererNativeCount => rendererNativeIds.length;
  int get rendererFallbackCount => rendererFallbackIds.length;
  int get pdfNativeCount => pdfNativeIds.length;
  int get pdfFallbackCount => pdfFallbackIds.length;
  int get wordNativeCount => wordNativeIds.length;
  int get wordFallbackCount => wordFallbackIds.length;
  int get intentionalFragmentCount => intentionalFragmentIds.length;
  bool get hasUnsafeCatalogSources => syntaxInvalidIds.isNotEmpty;
}
