import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/pdf/services/office_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('questionText preserves inline formula position using readable fallback', () {
    const expression = MathExpression(
      id: 'm1',
      latex: r'x=\frac{-b}{2a}',
      plainText: 'x equals negative b over 2 a',
    );
    final delta = jsonEncode([
      {'insert': 'The equation is '},
      {
        'insert': {
          MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
        },
      },
      {'insert': '. Solve it.\n'},
    ]);

    expect(
      OfficeTextFormatter.questionText(delta),
      'The equation is x equals negative b over 2 a. Solve it.',
    );
  });
}
