import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_expression_validator.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_smart_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathExpressionValidator', () {
    const validator = MathExpressionValidator();

    test('accepts a balanced textbook formula', () {
      const expression = MathExpression(
        id: 'quadratic',
        latex: r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}',
        plainText: 'x equals negative b plus or minus the square root...',
      );

      final result = validator.validate(expression);

      expect(result.isValid, isTrue);
      expect(result.renderSource, expression.latex);
    });

    test('returns editable fallback for malformed source', () {
      const expression = MathExpression(
        id: 'broken',
        latex: r'\frac{x{2}',
        plainText: 'x divided by 2',
      );

      final result = validator.validate(expression);

      expect(result.isValid, isFalse);
      expect(result.message, isNotEmpty);
      expect(result.renderSource, expression.latex);
      expect(result.accessibleFallback, 'x divided by 2');
    });

    test('rejects an empty formula without dropping description', () {
      const expression = MathExpression(
        id: 'empty',
        latex: ' ',
        plainText: 'teacher-entered description',
      );

      final result = validator.validate(expression);

      expect(result.isValid, isFalse);
      expect(result.accessibleFallback, 'teacher-entered description');
    });
  });

  group('math symbol catalogue', () {
    test('contains school mathematics, physics and chemistry structures', () {
      final sources = mathSymbols.map((symbol) => symbol.tex).toSet();

      expect(sources, contains(r'\frac{}{}'));
      expect(sources, contains(r'\begin{pmatrix}  & \\  & \end{pmatrix}'));
      expect(sources, contains(r'\int_{}^{}'));
      expect(sources, contains(r'\rightleftharpoons'));
      expect(sources, contains(r'{}^{A}_{Z}X'));
      expect(sources, contains(r'X\sim N(\mu,\sigma^2)'));
    });

    test('provides human-readable labels for structural keys', () {
      final fraction = mathSymbols.firstWhere(
        (symbol) => symbol.tex == r'\frac{}{}',
      );
      final equilibrium = mathSymbols.firstWhere(
        (symbol) => symbol.tex == r'\rightleftharpoons',
      );

      expect(fraction.accessibilityLabel, contains('numerator'));
      expect(equilibrium.accessibilityLabel, contains('equilibrium'));
    });

    test('uses stable semantic ids across category placements', () {
      final fractions = MathSymbolCatalog.symbols
          .where((symbol) => symbol.tex == r'\frac{}{}')
          .toList();

      expect(fractions.length, greaterThan(1));
      expect(fractions.map((symbol) => symbol.id).toSet(), hasLength(1));
    });

    test('supports teacher-friendly semantic search', () {
      final fractionResults = MathSymbolCatalog.search('numerator');
      final wavelengthResults = MathSymbolCatalog.search(
        'wavelength',
        subject: MathSubject.physics,
      );
      final equilibriumResults = MathSymbolCatalog.search('equilibrium');

      expect(
        fractionResults.map((symbol) => symbol.tex),
        contains(r'\frac{}{}'),
      );
      expect(
        wavelengthResults.map((symbol) => symbol.tex),
        contains(r'\lambda'),
      );
      expect(
        equilibriumResults.map((symbol) => symbol.tex),
        contains(r'\rightleftharpoons'),
      );
    });

    test(
      'catalogue keeps all existing placements while exposing canonical entries',
      () {
        expect(MathSymbolCatalog.symbols, hasLength(293));
        expect(
          MathSymbolCatalog.canonicalSymbols.length,
          lessThan(MathSymbolCatalog.symbols.length),
        );
        expect(
          MathSymbolCatalog.forCategory(MathCategory.physics),
          isNotEmpty,
        );
      },
    );

    test('builder mode is domain metadata instead of UI TeX matching', () {
      final power = MathSymbolCatalog.findByTex(r'^{}');
      final integral = MathSymbolCatalog.findByTex(r'\int_{}^{}');

      expect(power?.inputBehavior, MathInputBehavior.powerMode);
      expect(integral?.inputBehavior, MathInputBehavior.subscriptMode);
      expect(integral?.modeBaseSource, r'\int');
    });

    test('smart palette exposes contextual textbook keys', () {
      final calculus = MathSmartPalette.forCategory(MathCategory.calculus);
      final physics = MathSmartPalette.forCategory(MathCategory.physics);

      expect(calculus.map((symbol) => symbol.tex), contains(r'\frac{d}{dx}'));
      expect(calculus.map((symbol) => symbol.tex), contains(r'\int_{}^{}'));
      expect(physics.map((symbol) => symbol.tex), contains(r'\lambda'));
      expect(physics.map((symbol) => symbol.tex), contains(r'\vec{v}'));
    });
  });
}
