import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'teacher Build structures resolve to existing canonical catalogue keys',
    () {
      const sources = <String>[
        r'\frac{}{}',
        r'\sqrt{}',
        r'^{}',
        r'_{}',
        r'|{}|',
        r'\int_{}^{}',
        r'\sum_{}^{}',
      ];

      for (final source in sources) {
        final symbol = MathSymbolCatalog.findByTex(source);
        expect(symbol, isNotNull, reason: 'Missing Build source: $source');
        expect(
          symbol!.isStructural,
          isTrue,
          reason: 'Build source must remain structural: $source',
        );
      }
    },
  );

  test(
    'ready-formula lane is backed only by formula-template catalogue data',
    () {
      final templates = MathSymbolCatalog.forCategory(MathCategory.templates)
          .where((symbol) => symbol.kind == MathEntryKind.formulaTemplate)
          .toList(growable: false);

      expect(templates.length, greaterThanOrEqualTo(8));
      expect(templates.any((symbol) => symbol.label == 'Pythagoras'), isTrue);
      expect(templates.any((symbol) => symbol.label == 'Quadratic'), isTrue);
      expect(templates.every((symbol) => symbol.tex.trim().isNotEmpty), isTrue);
    },
  );
}
