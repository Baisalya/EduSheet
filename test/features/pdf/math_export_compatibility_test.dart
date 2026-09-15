import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blank stored fallback never leaks raw TeX into Office text export', () {
    const expression = MathExpression(
      id: 'phase6-generated-fallback',
      latex: r'\frac{x+1}{2}',
      plainText: '',
    );
    final richText = jsonEncode(<Map<String, Object?>>[
      <String, Object?>{
        'insert': <String, Object?>{
          MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
        },
      },
    ]);

    final exported = OfficeTextFormatter.questionText(richText);

    expect(exported.trim(), isNotEmpty);
    expect(exported, isNot(contains(r'\frac')));
  });
}
