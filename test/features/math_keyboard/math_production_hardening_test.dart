import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_production_policy.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_safety_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MathCompatibilityCache.shared.clear(resetStatistics: true);
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  tearDown(() {
    MathCompatibilityCache.shared.clear(resetStatistics: true);
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  test('normal textbook formulas stay inside production source budgets', () {
    const guard = MathSourceBudgetGuard();
    final report = guard.inspect(r'\frac{x^2+1}{\sqrt{y}}');

    expect(report.withinBudget, isTrue);
    expect(report.characters, greaterThan(0));
    expect(report.maximumDepth, lessThanOrEqualTo(4));
  });

  test(
    'oversized source uses deterministic safe fallback without parser probe',
    () {
      final source = List.filled(
        MathProductionLimits.maxSourceCharacters + 1,
        'x',
      ).join();
      final compatibility = const MathCompatibilityService().inspectSource(
        source,
        plainFallback: 'very large expression',
      );

      expect(compatibility.resourceLimited, isTrue);
      expect(compatibility.readableFallback, 'very large expression');
      expect(
        compatibility.screenRenderer.support,
        MathCompatibilitySupport.fallback,
      );
      expect(
        compatibility.pdfExport.support,
        MathCompatibilitySupport.fallback,
      );
      expect(
        compatibility.wordExport.support,
        MathCompatibilitySupport.fallback,
      );

      final safety = const MathSafetyValidationService().inspect(
        MathExpression(
          id: 'large',
          latex: source,
          plainText: 'very large expression',
        ),
      );
      expect(
        safety.issues.any(
          (issue) =>
              issue.code == MathValidationIssueCode.resourceBudgetExceeded,
        ),
        isTrue,
      );
      expect(safety.canPersist, isTrue);
    },
  );

  test(
    'deep nesting fails native export closed instead of recursing forever',
    () {
      final depth = MathProductionLimits.maxSourceNestingDepth + 1;
      final source =
          '${List.filled(depth, '{').join()}x${List.filled(depth, '}').join()}';

      final budget = const MathSourceBudgetGuard().inspect(source);
      expect(budget.withinBudget, isFalse);
      expect(const MathExportTypesettingCompiler().compile(source), isNull);
    },
  );

  test('large legitimate 12 by 12 matrix stays native', () {
    final rows = List.generate(
      12,
      (row) => List.generate(12, (column) => 'x${row}_$column').join('&'),
    ).join(r'\\');
    final source = '\\begin{pmatrix}$rows\\end{pmatrix}';

    expect(const MathExportTypesettingCompiler().compile(source), isNotNull);
  });

  test('pathological environment column count is rejected as one unit', () {
    final row = List.generate(
      MathProductionLimits.maxExportEnvironmentColumns + 1,
      (index) => 'x$index',
    ).join('&');
    final source = '\\begin{matrix}$row\\end{matrix}';

    expect(const MathExportTypesettingCompiler().compile(source), isNull);
  });

  test('export cache is bounded and records negative compilation hits', () {
    final cache = MathExportTypesettingCache(maximumEntries: 2);

    expect(cache.compile(r'\frac{1}{2}'), isNotNull);
    expect(cache.compile(r'\definitelyUnsupportedEduSheetCommand{x}'), isNull);
    expect(cache.compile(r'\definitelyUnsupportedEduSheetCommand{x}'), isNull);
    expect(cache.compile(r'x^2'), isNotNull);

    final snapshot = cache.snapshot;
    expect(snapshot.entries, 2);
    expect(snapshot.hits, 1);
    expect(snapshot.misses, 3);
    expect(snapshot.evictions, 1);
    expect(snapshot.hitRate, closeTo(0.25, 0.0001));
  });

  test('compatibility cache is LRU bounded and observable', () {
    final cache = MathCompatibilityCache(maximumEntries: 2);

    cache.inspectSource('x', plainFallback: 'x');
    cache.inspectSource('x', plainFallback: 'x');
    cache.inspectSource('y', plainFallback: 'y');
    cache.inspectSource('z', plainFallback: 'z');

    final snapshot = cache.snapshot;
    expect(snapshot.entries, 2);
    expect(snapshot.hits, 1);
    expect(snapshot.misses, 3);
    expect(snapshot.evictions, 1);
  });
}
