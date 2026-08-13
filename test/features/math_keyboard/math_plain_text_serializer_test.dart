import 'package:edusheet/features/math_keyboard/domain/services/math_plain_text_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serializer = MathPlainTextSerializer();

  group('MathPlainTextSerializer', () {
    test('keeps the cursor inside a new fraction numerator', () {
      final result = serializer.serialize(
        r'\frac{}{}',
        powerMode: false,
        subscriptMode: false,
      );

      expect(result.text, '()⁄()');
      expect(result.cursorOffset, 1);
    });

    test('keeps the cursor inside paired function brackets', () {
      final result = serializer.serialize(
        r'\sin',
        powerMode: false,
        subscriptMode: false,
      );

      expect(result.text, 'sin()');
      expect(result.cursorOffset, 4);
    });

    test('serializes power mode digits as superscripts', () {
      final result = serializer.serialize(
        '2',
        powerMode: true,
        subscriptMode: false,
      );

      expect(result.text, '²');
      expect(result.cursorOffset, 1);
    });

    test('serializes subscript mode digits as subscripts', () {
      final result = serializer.serialize(
        '3',
        powerMode: false,
        subscriptMode: true,
      );

      expect(result.text, '₃');
      expect(result.cursorOffset, 1);
    });

    test('uses catalogue labels for known symbols', () {
      final result = serializer.serialize(
        r'\lambda',
        powerMode: false,
        subscriptMode: false,
      );

      expect(result.text, 'λ');
    });
  });
}
