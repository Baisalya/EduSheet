import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/data/repositories/formula_data.dart';
import 'package:edusheet/features/calculator/domain/models/calculation_result.dart';
import 'package:edusheet/features/calculator/domain/models/calculator_input_command.dart';
import 'package:edusheet/features/calculator/domain/models/calculator_mode.dart';
import 'package:edusheet/features/calculator/domain/models/formula_model.dart';
import 'package:edusheet/features/calculator/domain/services/formula_solver.dart';
import 'package:edusheet/features/calculator/domain/services/math_engine.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';

void main() {
  group('Calculator release gate', () {
    Formula formulaNamed(String name) =>
        FormulaData.formulas.firstWhere((formula) => formula.name == name);

    test(
      'editing preview equals Ans and history remain one coherent workflow',
      () async {
        final controller = CalculatorController(previewDebounce: Duration.zero);
        addTearDown(controller.dispose);

        controller.dispatch(const CalculatorInputCommand.insertToken('2'));
        controller.dispatch(const CalculatorInputCommand.insertToken('+'));
        controller.dispatch(const CalculatorInputCommand.insertToken('3'));
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.equation, '2+3');
        expect(controller.state.previewResult, '5');
        expect(controller.state.history, isEmpty);
        expect(controller.state.lastAnswer, 0);

        controller.dispatch(CalculatorInputCommand.calculate);
        expect(controller.state.result, '5');
        expect(controller.state.lastAnswer, 5);
        expect(controller.state.history, hasLength(1));

        controller.dispatch(const CalculatorInputCommand.insertToken('×'));
        controller.dispatch(const CalculatorInputCommand.insertToken('4'));
        expect(controller.state.equation, 'Ans×4');
        controller.dispatch(CalculatorInputCommand.calculate);

        expect(controller.state.result, '20');
        expect(controller.state.lastAnswer, 20);
        expect(controller.state.history, hasLength(2));
      },
    );

    test(
      'resolved formula expression replaces a selection and remains calculable',
      () {
        final solver = FormulaSolver();
        final solved = solver.solve(formulaNamed("Newton's Second Law"), {
          'm': '2',
          'a': '3',
        });
        expect(solved.isSuccess, isTrue);

        final controller = CalculatorController();
        addTearDown(controller.dispose);
        for (final token in ['9', '9', '+', '1']) {
          controller.addToken(token);
        }
        controller.setSelection(0, 2);
        controller.dispatch(
          CalculatorInputCommand.insertFormula(
            '(${solved.resolvedExpression!})',
          ),
        );

        expect(controller.state.equation, '((2)*(3))+1');
        expect(controller.state.cursorOffset, 9);
        controller.calculate();
        expect(controller.state.result, '7');
      },
    );

    test(
      'every catalog formula resolves to a parser-safe finite calculation',
      () {
        final solver = FormulaSolver();
        final engine = MathEngine();
        final samples = <String, Map<String, String>>{
          'Average Velocity': {'d': '100', 't': '5'},
          'Acceleration': {'v': '20', 'u': '5', 't': '3'},
          "Newton's Second Law": {'m': '2', 'a': '3'},
          'Kinetic Energy': {'m': '2', 'v': '4'},
          'Potential Energy': {'m': '2', 'g': '', 'h': '5'},
          "Ohm's Law": {'I': '2', 'R': '5'},
          "Einstein's Energy": {'m': '1', 'c': ''},
          'Ideal Gas Law': {'n': '1', 'R': '', 'T': '300', 'V': '1'},
          'Molarity': {'n': '2', 'V': '4'},
          'pH Definition': {'H': '0.001'},
          'Specific Heat Capacity': {'m': '2', 'c': '4', 'dT': '3'},
          'Mole Calculation': {'m': '18', 'M': '18'},
        };

        expect(
          samples.keys,
          unorderedEquals(FormulaData.formulas.map((formula) => formula.name)),
        );

        for (final formula in FormulaData.formulas) {
          final solved = solver.solve(formula, samples[formula.name]!);
          expect(solved.isSuccess, isTrue, reason: formula.name);
          expect(solved.value!.isFinite, isTrue, reason: formula.name);
          expect(solved.resolvedExpression, isNotEmpty, reason: formula.name);

          final replay = engine.evaluateDetailed(solved.resolvedExpression!);
          expect(replay.isSuccess, isTrue, reason: formula.name);
          expect(
            replay.value,
            closeTo(solved.value!, 1e-9),
            reason: formula.name,
          );
        }
      },
    );

    test('scientific error and precision contracts stay release-safe', () {
      final engine = MathEngine();

      expect(engine.evaluate('1EXP-13'), '1e-13');
      expect(engine.evaluate('.5EXP2'), '50');
      expect(engine.evaluate('(2+3)!'), '120');
      expect(engine.evaluate('(2+3)C2'), '10');
      expect(engine.evaluate('sin(90)', angleUnit: AngleUnit.degrees), '1');

      expect(
        engine.evaluateDetailed('1÷(2-2)').errorCode,
        CalculationErrorCode.divisionByZero,
      );
      expect(
        engine.evaluateDetailed('sqrt(-1)').errorCode,
        CalculationErrorCode.domain,
      );
      expect(
        engine.evaluateDetailed('10^400').errorCode,
        CalculationErrorCode.overflow,
      );
      expect(
        engine.evaluateDetailed('m*a').errorCode,
        CalculationErrorCode.unsupported,
      );
    });

    test(
      'history is deduplicated and capped at fifty completed calculations',
      () {
        final controller = CalculatorController();
        addTearDown(controller.dispose);

        controller.addToken('1');
        controller.addToken('+');
        controller.addToken('1');
        controller.calculate();
        controller.calculate();
        expect(controller.state.history, hasLength(1));

        for (var i = 0; i < 55; i++) {
          controller.clear();
          for (final rune in '$i+1'.runes) {
            controller.addToken(String.fromCharCode(rune));
          }
          controller.calculate();
        }

        expect(controller.state.history, hasLength(50));
        expect(controller.state.history.last.expression, '54+1');
        expect(controller.state.history.last.result, '55');
      },
    );
  });
}
