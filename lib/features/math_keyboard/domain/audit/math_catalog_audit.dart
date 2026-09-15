import '../catalog/math_symbol_catalog.dart';
import '../models/math_edit_command.dart';
import '../models/math_symbol.dart';

/// Read-only catalogue diagnostics used by regression tests and developer
/// tooling. It deliberately does not change keyboard insertion or rendering.
class MathCatalogAuditor {
  const MathCatalogAuditor();

  MathCatalogAuditSnapshot capture({
    List<MathSymbol> symbols = MathSymbolCatalog.symbols,
  }) {
    final placementsByCategory = <MathCategory, int>{};
    final placementsByKind = <MathEntryKind, int>{};
    final placementsByInputBehavior = <MathInputBehavior, int>{};
    final texById = <String, Set<String>>{};
    final idsByTex = <String, Set<String>>{};
    final placementsById = <String, int>{};
    final structuralIds = <String>{};
    final formulaTemplateIds = <String>{};
    final declarativeCommandIds = <String>{};
    final structuredComposerIds = <String>{};
    final sourceSelectionWrapIds = <String>{};
    final dynamicStructureCommandIds = <String>{};
    var declarativeCommandPlacementCount = 0;
    var dynamicStructureCommandPlacementCount = 0;
    var structuredComposerPlacementCount = 0;
    var sourceSelectionWrapPlacementCount = 0;
    final blankIdentityIndexes = <int>[];

    for (var index = 0; index < symbols.length; index++) {
      final symbol = symbols[index];
      placementsByCategory.update(
        symbol.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      placementsByKind.update(
        symbol.kind,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      placementsByInputBehavior.update(
        symbol.inputBehavior,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      placementsById.update(symbol.id, (value) => value + 1, ifAbsent: () => 1);
      texById.putIfAbsent(symbol.id, () => <String>{}).add(symbol.tex);
      idsByTex.putIfAbsent(symbol.tex, () => <String>{}).add(symbol.id);

      if (symbol.isStructural) structuralIds.add(symbol.id);
      if (symbol.kind == MathEntryKind.formulaTemplate) {
        formulaTemplateIds.add(symbol.id);
      }
      final editorCommand = symbol.editorCommand;
      if (editorCommand != null) {
        declarativeCommandPlacementCount++;
        declarativeCommandIds.add(symbol.id);
        if (editorCommand.operations.any(
          (operation) => operation is MathInsertDynamicStructure,
        )) {
          dynamicStructureCommandPlacementCount++;
          dynamicStructureCommandIds.add(symbol.id);
        }
      }
      if (symbol.composer != null) {
        structuredComposerPlacementCount++;
        structuredComposerIds.add(symbol.id);
      }
      if (symbol.supportsSourceSelectionWrap) {
        sourceSelectionWrapPlacementCount++;
        sourceSelectionWrapIds.add(symbol.id);
      }
      if (symbol.id.trim().isEmpty ||
          symbol.label.trim().isEmpty ||
          symbol.tex.trim().isEmpty) {
        blankIdentityIndexes.add(index);
      }
    }

    final idConflicts =
        texById.entries
            .where((entry) => entry.value.length > 1)
            .map(
              (entry) => MathCatalogIdentityConflict(
                identity: entry.key,
                conflictingValues: entry.value.toList(growable: false)..sort(),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.identity.compareTo(b.identity));

    final texConflicts =
        idsByTex.entries
            .where((entry) => entry.value.length > 1)
            .map(
              (entry) => MathCatalogIdentityConflict(
                identity: entry.key,
                conflictingValues: entry.value.toList(growable: false)..sort(),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.identity.compareTo(b.identity));

    final duplicateSemanticIds =
        placementsById.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toList(growable: false)
          ..sort();

    return MathCatalogAuditSnapshot(
      placementCount: symbols.length,
      uniqueSemanticIdCount: texById.length,
      uniqueTexCount: idsByTex.length,
      duplicatePlacementCount: symbols.length - texById.length,
      structuralSemanticCount: structuralIds.length,
      formulaTemplateSemanticCount: formulaTemplateIds.length,
      declarativeCommandPlacementCount: declarativeCommandPlacementCount,
      declarativeCommandSemanticCount: declarativeCommandIds.length,
      dynamicStructureCommandPlacementCount:
          dynamicStructureCommandPlacementCount,
      dynamicStructureCommandSemanticCount: dynamicStructureCommandIds.length,
      structuredComposerPlacementCount: structuredComposerPlacementCount,
      structuredComposerSemanticCount: structuredComposerIds.length,
      sourceSelectionWrapPlacementCount: sourceSelectionWrapPlacementCount,
      sourceSelectionWrapSemanticCount: sourceSelectionWrapIds.length,
      placementsByCategory: Map.unmodifiable(placementsByCategory),
      placementsByKind: Map.unmodifiable(placementsByKind),
      placementsByInputBehavior: Map.unmodifiable(placementsByInputBehavior),
      duplicateSemanticIds: List.unmodifiable(duplicateSemanticIds),
      idConflicts: List.unmodifiable(idConflicts),
      texConflicts: List.unmodifiable(texConflicts),
      blankIdentityIndexes: List.unmodifiable(blankIdentityIndexes),
    );
  }
}

class MathCatalogAuditSnapshot {
  final int placementCount;
  final int uniqueSemanticIdCount;
  final int uniqueTexCount;
  final int duplicatePlacementCount;
  final int structuralSemanticCount;
  final int formulaTemplateSemanticCount;
  final int declarativeCommandPlacementCount;
  final int declarativeCommandSemanticCount;
  final int dynamicStructureCommandPlacementCount;
  final int dynamicStructureCommandSemanticCount;
  final int structuredComposerPlacementCount;
  final int structuredComposerSemanticCount;
  final int sourceSelectionWrapPlacementCount;
  final int sourceSelectionWrapSemanticCount;
  final Map<MathCategory, int> placementsByCategory;
  final Map<MathEntryKind, int> placementsByKind;
  final Map<MathInputBehavior, int> placementsByInputBehavior;
  final List<String> duplicateSemanticIds;
  final List<MathCatalogIdentityConflict> idConflicts;
  final List<MathCatalogIdentityConflict> texConflicts;
  final List<int> blankIdentityIndexes;

  const MathCatalogAuditSnapshot({
    required this.placementCount,
    required this.uniqueSemanticIdCount,
    required this.uniqueTexCount,
    required this.duplicatePlacementCount,
    required this.structuralSemanticCount,
    required this.formulaTemplateSemanticCount,
    required this.declarativeCommandPlacementCount,
    required this.declarativeCommandSemanticCount,
    required this.dynamicStructureCommandPlacementCount,
    required this.dynamicStructureCommandSemanticCount,
    required this.structuredComposerPlacementCount,
    required this.structuredComposerSemanticCount,
    required this.sourceSelectionWrapPlacementCount,
    required this.sourceSelectionWrapSemanticCount,
    required this.placementsByCategory,
    required this.placementsByKind,
    required this.placementsByInputBehavior,
    required this.duplicateSemanticIds,
    required this.idConflicts,
    required this.texConflicts,
    required this.blankIdentityIndexes,
  });

  bool get hasIdentityErrors =>
      idConflicts.isNotEmpty ||
      texConflicts.isNotEmpty ||
      blankIdentityIndexes.isNotEmpty;
}

class MathCatalogIdentityConflict {
  final String identity;
  final List<String> conflictingValues;

  const MathCatalogIdentityConflict({
    required this.identity,
    required this.conflictingValues,
  });
}
