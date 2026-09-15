import 'dart:convert';

import 'package:edusheet/features/math_keyboard/domain/audit/math_catalog_audit.dart';

void main() {
  const auditor = MathCatalogAuditor();
  final snapshot = auditor.capture();

  final report = <String, Object?>{
    'placementCount': snapshot.placementCount,
    'uniqueSemanticIdCount': snapshot.uniqueSemanticIdCount,
    'uniqueTexCount': snapshot.uniqueTexCount,
    'duplicatePlacementCount': snapshot.duplicatePlacementCount,
    'structuralSemanticCount': snapshot.structuralSemanticCount,
    'formulaTemplateSemanticCount': snapshot.formulaTemplateSemanticCount,
    'declarativeCommandPlacementCount':
        snapshot.declarativeCommandPlacementCount,
    'declarativeCommandSemanticCount': snapshot.declarativeCommandSemanticCount,
    'dynamicStructureCommandPlacementCount':
        snapshot.dynamicStructureCommandPlacementCount,
    'dynamicStructureCommandSemanticCount':
        snapshot.dynamicStructureCommandSemanticCount,
    'structuredComposerPlacementCount':
        snapshot.structuredComposerPlacementCount,
    'structuredComposerSemanticCount': snapshot.structuredComposerSemanticCount,
    'sourceSelectionWrapPlacementCount':
        snapshot.sourceSelectionWrapPlacementCount,
    'sourceSelectionWrapSemanticCount':
        snapshot.sourceSelectionWrapSemanticCount,
    'placementsByCategory': <String, int>{
      for (final entry in snapshot.placementsByCategory.entries)
        entry.key.name: entry.value,
    },
    'placementsByKind': <String, int>{
      for (final entry in snapshot.placementsByKind.entries)
        entry.key.name: entry.value,
    },
    'placementsByInputBehavior': <String, int>{
      for (final entry in snapshot.placementsByInputBehavior.entries)
        entry.key.name: entry.value,
    },
    'duplicateSemanticIds': snapshot.duplicateSemanticIds,
    'identityErrors': <String, Object?>{
      'blankIdentityIndexes': snapshot.blankIdentityIndexes,
      'idConflicts': [
        for (final conflict in snapshot.idConflicts)
          <String, Object?>{
            'id': conflict.identity,
            'texValues': conflict.conflictingValues,
          },
      ],
      'texConflicts': [
        for (final conflict in snapshot.texConflicts)
          <String, Object?>{
            'tex': conflict.identity,
            'ids': conflict.conflictingValues,
          },
      ],
    },
  };

  // Developer CLI output is intentional for this audit tool.
  // ignore: avoid_print
  print(const JsonEncoder.withIndent('  ').convert(report));
}
