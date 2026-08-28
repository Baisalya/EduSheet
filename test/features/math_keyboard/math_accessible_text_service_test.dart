import 'package:edusheet/features/math_keyboard/domain/services/math_accessible_text_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MathAccessibleTextService();

  test('reuses known textbook plain-text forms', () {
    expect(
      service.describe(r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'),
      contains('√'),
    );
  });

  test(
    'describes common nested visual formula without requiring teacher text',
    () {
      final description = service.describe(r'hey \sqrt{1223^{1}}');

      expect(description, contains('square root of'));
      expect(description, contains('to the power 1'));
      expect(description, isNot(contains(r'\sqrt')));
    },
  );

  test('empty formula produces empty fallback', () {
    expect(service.describe('   '), isEmpty);
  });
}
