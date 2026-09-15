import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Phase 1 records that office text formatting exports math fallback text',
    () {
      const expression = MathExpression(
        id: 'fraction-export-baseline',
        latex: r'\frac{x+1}{2}',
        plainText: '(x + 1) / 2',
      );
      final richText = jsonEncode(<Map<String, Object?>>[
        <String, Object?>{'insert': 'Solve '},
        <String, Object?>{
          'insert': <String, Object?>{
            MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
          },
        },
        <String, Object?>{'insert': '\n'},
      ]);

      final exported = OfficeTextFormatter.questionText(richText);

      expect(exported, 'Solve (x + 1) / 2');
      expect(exported, isNot(contains(r'\frac')));
    },
  );

  test('Phase 1 records the current fixed-matrix plain-text placeholder', () {
    const expression = MathExpression(
      id: 'matrix-export-baseline',
      latex: r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
      plainText: '[2×2 matrix]',
    );
    final richText = jsonEncode(<Map<String, Object?>>[
      <String, Object?>{
        'insert': <String, Object?>{
          MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
        },
      },
    ]);

    expect(OfficeTextFormatter.questionText(richText), '[2×2 matrix]');
  });
}
