import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_expression_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses unchanged validation and evicts least-recent entries', () {
    final cache = MathExpressionValidationCache(maximumEntries: 2);
    const first = MathExpression(
      id: '1',
      latex: r'x^2',
      plainText: 'x squared',
    );
    const second = MathExpression(
      id: '2',
      latex: r'y^2',
      plainText: 'y squared',
    );
    const third = MathExpression(
      id: '3',
      latex: r'z^2',
      plainText: 'z squared',
    );

    final firstResult = cache.validate(first);
    expect(identical(cache.validate(first), firstResult), isTrue);
    cache.validate(second);
    cache.validate(third);

    expect(cache.length, 2);
    expect(identical(cache.validate(first), firstResult), isFalse);
  });
}
