import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_smart_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'common palette prioritizes teacher-friendly structures and relations',
    () {
      final tex = MathSmartPalette.forCategory(
        MathCategory.basic,
      ).map((symbol) => symbol.tex).toSet();

      expect(tex, contains(r'\frac{}{}'));
      expect(tex, contains(r'\sqrt{}'));
      expect(tex, contains(r'^{}'));
      expect(tex, contains(r'_{}'));
      expect(tex, contains(r'\times'));
      expect(tex, contains(r'\div'));
      expect(tex, contains(r'\neq'));
      expect(tex, contains(r'\leq'));
      expect(tex, contains(r'\geq'));
    },
  );
}
