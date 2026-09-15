import 'package:edusheet/features/math_keyboard/domain/audit/math_catalog_audit.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const auditor = MathCatalogAuditor();

  test(
    'catalogue inventory includes the Phase 5 symbol universe expansion',
    () {
      final snapshot = auditor.capture();

      expect(snapshot.placementCount, 386);
      expect(snapshot.uniqueSemanticIdCount, 356);
      expect(snapshot.uniqueTexCount, 356);
      expect(snapshot.duplicatePlacementCount, 30);
      expect(snapshot.duplicateSemanticIds, hasLength(27));

      expect(snapshot.placementsByCategory, <MathCategory, int>{
        MathCategory.basic: 33,
        MathCategory.functions: 35,
        MathCategory.trig: 18,
        MathCategory.calculus: 20,
        MathCategory.operators: 47,
        MathCategory.greek: 40,
        MathCategory.sets: 32,
        MathCategory.brackets: 6,
        MathCategory.geometry: 29,
        MathCategory.physics: 38,
        MathCategory.statistics: 17,
        MathCategory.arrows: 19,
        MathCategory.matrices: 4,
        MathCategory.templates: 16,
        MathCategory.chemistry: 20,
        MathCategory.misc: 12,
      });
    },
  );

  test('semantic ids and TeX identities have no conflicts', () {
    final snapshot = auditor.capture();

    expect(snapshot.idConflicts, isEmpty);
    expect(snapshot.texConflicts, isEmpty);
    expect(snapshot.blankIdentityIndexes, isEmpty);
    expect(snapshot.hasIdentityErrors, isFalse);
  });

  test('catalogue preserves structural and input-behaviour metadata', () {
    final snapshot = auditor.capture();

    expect(snapshot.structuralSemanticCount, 95);
    expect(snapshot.formulaTemplateSemanticCount, 35);
    expect(snapshot.declarativeCommandPlacementCount, 85);
    expect(snapshot.declarativeCommandSemanticCount, 76);
    expect(snapshot.dynamicStructureCommandPlacementCount, 4);
    expect(snapshot.dynamicStructureCommandSemanticCount, 4);
    expect(snapshot.structuredComposerPlacementCount, 36);
    expect(snapshot.structuredComposerSemanticCount, 30);
    expect(snapshot.sourceSelectionWrapPlacementCount, 27);
    expect(snapshot.sourceSelectionWrapSemanticCount, 21);
    expect(snapshot.placementsByKind, <MathEntryKind, int>{
      MathEntryKind.symbol: 162,
      MathEntryKind.structure: 68,
      MathEntryKind.formulaTemplate: 35,
      MathEntryKind.operator: 58,
      MathEntryKind.function: 23,
      MathEntryKind.relation: 38,
      MathEntryKind.constant: 2,
    });
    expect(snapshot.placementsByInputBehavior[MathInputBehavior.powerMode], 3);
    expect(
      snapshot.placementsByInputBehavior[MathInputBehavior.subscriptMode],
      6,
    );
  });
}
