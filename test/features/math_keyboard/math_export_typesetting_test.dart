import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = MathExportTypesettingCompiler();

  test(
    'Phase 8 compiler covers textbook fraction root scripts and operators',
    () {
      final node = compiler.compile(
        r'\lim_{x\to\infty}\frac{x^2+1}{\sqrt[3]{x}}',
      );

      expect(node, isNotNull);
    },
  );

  test(
    'Phase 8 compiler covers matrices determinants cases and aligned work',
    () {
      for (final source in <String>[
        r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
        r'\begin{vmatrix}a&b\\c&d\end{vmatrix}',
        r'f(x)=\begin{cases}x^2&x\geq0\\-x&x<0\end{cases}',
        r'\begin{aligned}x+1&=2\\x&=1\end{aligned}',
        r'\left[\begin{array}{cc|c}1&0&a\\0&1&b\end{array}\right]',
      ]) {
        expect(compiler.compile(source), isNotNull, reason: source);
      }
    },
  );

  test('unsupported TeX fails closed instead of partial export', () {
    expect(
      compiler.compile(r'\definitelyUnsupportedEduSheetCommand{x}'),
      isNull,
    );
  });

  test('compatibility reports native export only for supported subset', () {
    const service = MathCompatibilityService();
    final native = service.inspectSource(
      r'\frac{x+1}{2}',
      plainFallback: 'x plus 1 over 2',
    );
    final fallback = service.inspectSource(
      r'\definitelyUnsupportedEduSheetCommand{x}',
      plainFallback: 'x with unsupported notation',
    );

    expect(native.pdfExport.support, MathCompatibilitySupport.native);
    expect(native.wordExport.support, MathCompatibilitySupport.native);
    expect(fallback.pdfExport.support, MathCompatibilitySupport.fallback);
    expect(fallback.wordExport.support, MathCompatibilitySupport.fallback);
  });
}
