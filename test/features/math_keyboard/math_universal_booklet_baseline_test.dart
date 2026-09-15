import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_dynamic_structure_codec.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_expression_validator.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_plain_text_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/math_keyboard/universal_math_booklet_corpus.dart';

void main() {
  const validator = MathExpressionValidator();
  const dynamicCodec = MathDynamicStructureCodec();
  const serializer = MathPlainTextSerializer();

  test('booklet corpus spans the major current subject families', () {
    final subjects = universalMathBookletCorpus
        .map((item) => item.subject)
        .toSet();

    expect(subjects, containsAll(MathSubject.values));
    expect(universalMathBookletCorpus.length, greaterThanOrEqualTo(30));
  });

  test(
    'catalog-backed and fixed-template cases resolve every required key',
    () {
      final cases = universalMathBookletCorpus.where(
        (item) =>
            item.entryPath == BookletEntryPath.catalogBacked ||
            item.entryPath == BookletEntryPath.fixedTemplate,
      );

      for (final item in cases) {
        expect(
          item.requiredCatalogSources,
          isNotEmpty,
          reason:
              '${item.id} must name the keys that make it catalogue-backed.',
        );
        for (final source in item.requiredCatalogSources) {
          expect(
            MathSymbolCatalog.findByTex(source),
            isNotNull,
            reason: '${item.id} lost required catalogue source: $source',
          );
        }
      }
    },
  );

  test('every corpus expression survives canonical JSON persistence', () {
    for (final item in universalMathBookletCorpus) {
      final original = MathExpression(
        id: item.id,
        latex: item.latex,
        plainText: item.plainText,
      );
      final restored = MathExpression.fromJson(original.toJson());

      expect(restored.id, original.id, reason: item.id);
      expect(restored.latex, original.latex, reason: item.id);
      expect(restored.plainText, original.plainText, reason: item.id);
      expect(restored.formatVersion, MathExpression.currentFormatVersion);
    }
  });

  test('Phase 1 shallow validator accepts the balanced regression corpus', () {
    for (final item in universalMathBookletCorpus) {
      final result = validator.validate(
        MathExpression(
          id: item.id,
          latex: item.latex,
          plainText: item.plainText,
        ),
      );

      expect(
        result.isValid,
        isTrue,
        reason: '${item.id}: ${result.message ?? 'validation failed'}',
      );
    }
  });

  test('all required catalogue keys have a non-empty plain-text insertion', () {
    final sources = universalMathBookletCorpus
        .expand((item) => item.requiredCatalogSources)
        .toSet();

    for (final source in sources) {
      final insertion = serializer.serialize(
        source,
        powerMode: false,
        subscriptMode: false,
      );
      expect(insertion.text.trim(), isNotEmpty, reason: source);
      expect(insertion.cursorOffset, greaterThanOrEqualTo(0), reason: source);
      expect(
        insertion.cursorOffset,
        lessThanOrEqualTo(insertion.text.length),
        reason: source,
      );
    }
  });

  test('Phase 4 dynamic-builder corpus is recognized by the runtime codec', () {
    final cases = universalMathBookletCorpus.where(
      (item) => item.entryPath == BookletEntryPath.dynamicBuilder,
    );

    expect(cases.length, greaterThanOrEqualTo(5));
    for (final item in cases) {
      final parsed = dynamicCodec.tryParse(item.latex);
      expect(parsed, isNotNull, reason: item.id);
      expect(parsed!.spec.isValid, isTrue, reason: item.id);
      expect(item.baselineNote?.trim(), isNotEmpty, reason: item.id);
    }
  });

  test('non-first-class cases remain explicitly documented, not hidden', () {
    final limitations = universalMathBookletCorpus.where(
      (item) =>
          item.entryPath == BookletEntryPath.advancedSource ||
          item.entryPath == BookletEntryPath.architecturalGap,
    );

    expect(limitations.length, greaterThanOrEqualTo(4));
    for (final item in limitations) {
      expect(item.baselineNote?.trim(), isNotEmpty, reason: item.id);
    }
  });
}
