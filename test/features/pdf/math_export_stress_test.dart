import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_production_policy.dart';
import 'package:edusheet/features/pdf/services/math/pdf_math_typesetter.dart';
import 'package:edusheet/features/pdf/services/math/word_omml_math_typesetter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  tearDown(() {
    MathExportTypesettingCache.shared.clear(resetStatistics: true);
  });

  test(
    'repeated PDF and Word native typesetting reuses bounded export cache',
    () {
      const pdf = PdfMathTypesetter();
      const word = WordOmmlMathTypesetter();
      const sources = <String>[
        r'\frac{x+1}{2}',
        r'x^2+y^2',
        r'\sqrt{x+4}',
        r'\sum_{i=1}^{n}i',
        r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
      ];

      for (var index = 0; index < 1000; index++) {
        final source = sources[index % sources.length];
        expect(pdf.buildSource(source, fontSize: 12), isNotNull);
        expect(word.inlineSource(source), isNotNull);
      }

      final snapshot = MathExportTypesettingCache.shared.snapshot;
      expect(snapshot.entries, sources.length);
      expect(snapshot.misses, sources.length);
      expect(snapshot.hits, 1995);
      expect(snapshot.evictions, 0);
    },
  );

  test('oversized formula refuses native PDF and Word typesetting', () {
    const pdf = PdfMathTypesetter();
    const word = WordOmmlMathTypesetter();
    final source = List.filled(
      MathProductionLimits.maxSourceCharacters + 1,
      'x',
    ).join();

    expect(pdf.buildSource(source, fontSize: 12), isNull);
    expect(word.inlineSource(source), isNull);
  });
}
