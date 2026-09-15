import 'package:edusheet/features/pdf/services/math/pdf_math_typesetter.dart';
import 'package:edusheet/features/pdf/services/math/word_omml_math_typesetter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const word = WordOmmlMathTypesetter();
  const pdf = PdfMathTypesetter();

  test('Word typesetter emits native OMML fraction root and scripts', () {
    final xml = word.inlineSource(r'\frac{x^2}{\sqrt{y}}');

    expect(xml, isNotNull);
    expect(xml, contains('<m:oMath>'));
    expect(xml, contains('<m:f>'));
    expect(xml, contains('<m:sSup>'));
    expect(xml, contains('<m:rad>'));
    expect(xml, isNot(contains(r'\frac')));
  });

  test('Word typesetter emits matrix OMML and scalable delimiters', () {
    final xml = word.inlineSource(r'\begin{pmatrix}a&b\\c&d\end{pmatrix}');

    expect(xml, isNotNull);
    expect(xml, contains('<m:m>'));
    expect(xml, contains('<m:d>'));
    expect(xml, contains('m:begChr m:val="("'));
    expect(xml, contains('m:endChr m:val=")"'));
  });

  test('Word augmented matrix preserves the array divider', () {
    final xml = word.inlineSource(
      r'\left[\begin{array}{cc|c}1&0&a\\0&1&b\end{array}\right]',
    );

    expect(xml, isNotNull);
    expect(xml, contains('<m:m>'));
    expect(xml, contains('│'));
  });

  test(
    'PDF typesetter produces widgets for native and rejects unsupported',
    () {
      expect(pdf.buildSource(r'\frac{1}{2}', fontSize: 12), isNotNull);
      expect(
        pdf.buildSource(
          r'\definitelyUnsupportedEduSheetCommand{x}',
          fontSize: 12,
        ),
        isNull,
      );
    },
  );
}
