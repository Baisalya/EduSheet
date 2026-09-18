import 'package:edusheet/features/document_reader/presentation/responsive/document_viewport_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentViewportPolicy', () {
    test('320px phone never forces a 320px Word page into a smaller viewport', () {
      const policy = DocumentViewportPolicy(width: 320, height: 720);

      expect(policy.isPhone, isTrue);
      expect(policy.preferWordFitWidth, isTrue);
      expect(policy.wordHorizontalGutter, 8);
      expect(policy.wordAvailableWidth, 304);
      expect(policy.wordFitWidthPageWidth, 304);
      expect(
        policy.wordFitWidthPageWidth + policy.wordHorizontalGutter * 2,
        lessThanOrEqualTo(policy.width),
      );
    });

    test('phone and tablet use fit width while desktop defaults to print layout', () {
      const phone = DocumentViewportPolicy(width: 390, height: 844);
      const tablet = DocumentViewportPolicy(width: 800, height: 1100);
      const desktop = DocumentViewportPolicy(width: 1280, height: 800);

      expect(phone.preferWordFitWidth, isTrue);
      expect(tablet.preferWordFitWidth, isTrue);
      expect(desktop.preferWordFitWidth, isFalse);
      expect(desktop.wordPrintLayoutPageWidth, 794);
    });

    test('fit width stays bounded on a large resizable workspace', () {
      const policy = DocumentViewportPolicy(width: 1600, height: 900);

      expect(policy.wordFitWidthPageWidth, 860);
      expect(policy.wordPrintLayoutPageWidth, 794);
      expect(policy.documentToolbarHeight, 52);
    });

    test('small reader toolbar remains touch-friendly', () {
      const policy = DocumentViewportPolicy(width: 360, height: 800);

      expect(policy.documentToolbarHeight, 48);
      expect(policy.isCompactToolbar, isTrue);
      expect(policy.isVeryCompactToolbar, isTrue);
    });
  });
}
