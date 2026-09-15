import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/audit/math_compatibility_audit.dart';
import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/math_keyboard/universal_math_booklet_corpus.dart';

void main() {
  const service = MathCompatibilityService();

  test('simple textbook TeX is native on the screen renderer', () {
    final report = service.inspectSource(
      r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}',
      plainFallback:
          'x equals negative b plus or minus root discriminant over 2a',
    );

    expect(report.syntaxValid, isTrue);
    expect(report.screenRenderer.support, MathCompatibilitySupport.native);
    expect(report.pdfExport.support, MathCompatibilitySupport.native);
    expect(report.wordExport.support, MathCompatibilitySupport.native);
  });

  test('dynamic structures are recognized before the visual TeX parser', () {
    final report = service.inspectSource(
      r'\begin{pmatrix}  &  \\  &  \end{pmatrix}',
      plainFallback: '[2 by 2 matrix]',
    );

    expect(report.syntaxValid, isTrue);
    expect(report.visualStrategy, MathVisualEditorStrategy.dynamicStructure);
    expect(report.visualEditor.support, MathCompatibilitySupport.native);
  });

  test(
    'renderer rejection becomes a safe fallback instead of a crash path',
    () {
      final report = service.inspectSource(
        r'\definitelyUnsupportedEduSheetCommand{z}',
        plainFallback: 'z with unsupported notation',
      );

      expect(report.syntaxValid, isTrue);
      expect(report.screenRenderer.support, MathCompatibilitySupport.fallback);
      expect(report.screenRenderer.isUsable, isTrue);
    },
  );

  test('malformed environment is rejected before parser or renderer use', () {
    final report = service.inspectSource(
      r'\begin{pmatrix}a&b\end{vmatrix}',
      plainFallback: 'matrix',
    );

    expect(report.syntaxValid, isFalse);
    expect(report.syntaxMessage, contains('opens “pmatrix”'));
    expect(report.visualEditor.support, MathCompatibilitySupport.unsupported);
  });

  test('all canonical catalogue entries have a safe screen route', () {
    final audit = const MathCompatibilityAuditor().capture();

    expect(audit.semanticCount, MathSymbolCatalog.canonicalSymbols.length);
    expect(audit.semanticCount, 356);
    expect(audit.syntaxInvalidIds, isEmpty);
    expect(audit.intentionalFragmentCount, 3);
    expect(
      audit.intentionalFragmentIds,
      containsAll(<String>[
        'math.28ed3a797da3',
        'math.1e5c2f367f02',
        'math.60ba4b2daa4e',
      ]),
    );
    expect(
      audit.visualNativeCount + audit.visualSourceOnlyCount,
      audit.semanticCount,
    );
    expect(
      audit.rendererNativeCount + audit.rendererFallbackCount,
      audit.semanticCount,
    );
    expect(audit.pdfNativeCount + audit.pdfFallbackCount, audit.semanticCount);
    expect(
      audit.wordNativeCount + audit.wordFallbackCount,
      audit.semanticCount,
    );
    expect(audit.pdfNativeCount, greaterThan(0));
    expect(audit.wordNativeCount, greaterThan(0));
  });

  test('universal booklet corpus has a safe renderer and export route', () {
    for (final sample in universalMathBookletCorpus) {
      final report = service.inspectSource(
        sample.latex,
        plainFallback: sample.plainText,
      );
      expect(report.syntaxValid, isTrue, reason: sample.id);
      expect(report.screenRenderer.isUsable, isTrue, reason: sample.id);
      expect(report.pdfExport.isUsable, isTrue, reason: sample.id);
      expect(report.wordExport.isUsable, isTrue, reason: sample.id);
    }
  });

  test('compatibility cache preserves reports and stays bounded', () {
    final cache = MathCompatibilityCache(maximumEntries: 2);
    final first = cache.inspectSource('x+1', plainFallback: 'x plus 1');
    final again = cache.inspectSource('x+1', plainFallback: 'x plus 1');
    expect(identical(first, again), isTrue);

    cache.inspectSource('y+1', plainFallback: 'y plus 1');
    cache.inspectSource('z+1', plainFallback: 'z plus 1');
    expect(cache.length, 2);
  });

  testWidgets('SafeMathExpression preflights renderer and shows fallback', (
    tester,
  ) async {
    const expression = MathExpression(
      id: 'unsupported-renderer',
      latex: r'\definitelyUnsupportedEduSheetCommand{z}',
      plainText: 'safe readable z',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SafeMathExpression(expression: expression)),
      ),
    );

    expect(find.text('safe readable z'), findsOneWidget);
  });
}
