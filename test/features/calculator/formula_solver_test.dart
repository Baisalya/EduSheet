import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/data/repositories/formula_data.dart';
import 'package:edusheet/features/calculator/domain/models/calculation_result.dart';
import 'package:edusheet/features/calculator/domain/models/formula_model.dart';
import 'package:edusheet/features/calculator/domain/services/formula_solver.dart';

void main() {
  group('FormulaData', () {
    test('every template has explicit variables matching its placeholders', () {
      for (final formula in FormulaData.formulas) {
        expect(formula.targetSymbol, isNotEmpty, reason: formula.name);
        expect(formula.targetLabel, isNotEmpty, reason: formula.name);
        expect(formula.variables, isNotEmpty, reason: formula.name);

        final placeholders = RegExp(r'\{([^}]+)\}')
            .allMatches(formula.calculationExpression)
            .map((match) => match.group(1)!)
            .toSet();
        final variableSymbols = formula.variables
            .map((item) => item.symbol)
            .toSet();

        expect(placeholders, variableSymbols, reason: formula.name);
      }
    });
  });

  group('FormulaSolver', () {
    late FormulaSolver solver;

    setUp(() {
      solver = FormulaSolver();
    });

    Formula formulaNamed(String name) =>
        FormulaData.formulas.firstWhere((formula) => formula.name == name);

    test('solves a simple physics formula with numeric inputs', () {
      final result = solver.solve(formulaNamed('Newton\'s Second Law'), {
        'm': '2',
        'a': '3',
      });

      expect(result.isSuccess, isTrue);
      expect(result.displayText, '6');
      expect(result.value, 6);
      expect(result.resolvedExpression, '(2)*(3)');
    });

    test('accepts calculator expressions inside formula fields', () {
      final result = solver.solve(formulaNamed('Average Velocity'), {
        'd': '40+60',
        't': '4*5',
      });

      expect(result.isSuccess, isTrue);
      expect(result.displayText, '5');
    });

    test('uses editable scientific defaults when a value is omitted', () {
      final result = solver.solve(formulaNamed('Potential Energy'), {
        'm': '2',
        'g': '',
        'h': '5',
      });

      expect(result.isSuccess, isTrue);
      expect(result.value, closeTo(98.0665, 1e-10));
    });

    test('every catalog formula resolves with representative inputs', () {
      final samples = <String, Map<String, String>>{
        'Average Velocity': {'d': '10', 't': '2'},
        'Acceleration': {'v': '10', 'u': '2', 't': '4'},
        "Newton's Second Law": {'m': '2', 'a': '3'},
        'Kinetic Energy': {'m': '2', 'v': '3'},
        'Potential Energy': {'m': '2', 'g': '', 'h': '5'},
        "Ohm's Law": {'I': '2', 'R': '5'},
        "Einstein's Energy": {'m': '1', 'c': ''},
        'Ideal Gas Law': {'n': '1', 'R': '', 'T': '300', 'V': '1'},
        'Molarity': {'n': '2', 'V': '4'},
        'pH Definition': {'H': '0.001'},
        'Specific Heat Capacity': {'m': '2', 'c': '4', 'dT': '3'},
        'Mole Calculation': {'m': '18', 'M': '18'},
      };

      for (final formula in FormulaData.formulas) {
        final result = solver.solve(formula, samples[formula.name]!);
        expect(result.isSuccess, isTrue, reason: formula.name);
      }
    });

    test('ideal gas template solves explicitly for pressure', () {
      final result = solver.solve(formulaNamed('Ideal Gas Law'), {
        'n': '1',
        'R': '',
        'T': '300',
        'V': '0.024',
      });

      expect(result.isSuccess, isTrue);
      expect(result.value, closeTo(103930.7827269155, 1e-6));
    });

    test('pH formula uses the same logarithm semantics as MathEngine', () {
      final result = solver.solve(formulaNamed('pH Definition'), {
        'H': '0.001',
      });

      expect(result.isSuccess, isTrue);
      expect(result.value, closeTo(3, 1e-12));
    });

    test('reports missing and invalid inputs against the specific field', () {
      final missing = solver.solve(formulaNamed('Average Velocity'), {
        'd': '100',
        't': '',
      });
      expect(missing.isSuccess, isFalse);
      expect(missing.fieldErrors, contains('t'));

      final invalid = solver.solve(formulaNamed('Average Velocity'), {
        'd': 'abc',
        't': '2',
      });
      expect(invalid.isSuccess, isFalse);
      expect(invalid.fieldErrors, contains('d'));
    });

    test('propagates calculation-domain failures after inputs validate', () {
      final result = solver.solve(formulaNamed('Average Velocity'), {
        'd': '100',
        't': '0',
      });

      expect(result.isSuccess, isFalse);
      expect(result.fieldErrors, isEmpty);
      expect(
        result.calculation?.errorCode,
        CalculationErrorCode.divisionByZero,
      );
    });

    test('rejects malformed formula metadata instead of leaking symbols', () {
      const malformed = Formula(
        name: 'Broken',
        expression: 'y = x',
        category: 'Test',
        subject: ScienceSubject.physics,
        targetSymbol: 'y',
        targetLabel: 'Y',
        calculationExpression: '2+2',
        variables: [FormulaVariable(symbol: 'x', label: 'X')],
      );

      final result = solver.solve(malformed, {'x': '1'});
      expect(result.isSuccess, isFalse);
      expect(result.configurationError, contains('{x}'));
    });

    test('serializes ordinary solved values without cosmetic .0', () {
      final result = solver.solve(formulaNamed('Newton\'s Second Law'), {
        'm': '2',
        'a': '3',
      });

      expect(result.isSuccess, isTrue);
      expect(solver.serializeResult(result), '6');
    });

    test('serializes solved scientific values back to parser-safe syntax', () {
      final result = solver.solve(formulaNamed('Average Velocity'), {
        'd': '1EXP-13',
        't': '1',
      });

      expect(result.isSuccess, isTrue);
      final serialized = solver.serializeResult(result);
      expect(serialized, isNotEmpty);
      expect(serialized, isNot(contains('e')));
      expect(serialized, contains('10^'));
    });
  });
}
