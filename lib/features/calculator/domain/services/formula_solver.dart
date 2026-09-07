import '../models/calculation_result.dart';
import '../models/calculator_mode.dart';
import '../models/formula_model.dart';
import 'calculator_numeric_formatter.dart';
import 'math_engine.dart';

class FormulaSolveResult {
  final String? resolvedExpression;
  final CalculationResult? calculation;
  final Map<String, String> fieldErrors;
  final String? configurationError;

  const FormulaSolveResult({
    this.resolvedExpression,
    this.calculation,
    this.fieldErrors = const {},
    this.configurationError,
  });

  bool get isSuccess =>
      configurationError == null &&
      fieldErrors.isEmpty &&
      calculation?.isSuccess == true;

  String? get displayText => isSuccess ? calculation!.displayText : null;
  double? get value => isSuccess ? calculation!.value : null;
}

/// Resolves science-formula placeholders into calculator expressions only
/// after every input has passed MathEngine validation.
class FormulaSolver {
  final MathEngine _engine;
  final CalculatorNumericFormatter _numericFormatter;

  FormulaSolver({
    MathEngine? engine,
    CalculatorNumericFormatter numericFormatter =
        const CalculatorNumericFormatter(),
  }) : _engine = engine ?? MathEngine(),
       _numericFormatter = numericFormatter;

  FormulaSolveResult solve(
    Formula formula,
    Map<String, String> inputs, {
    AngleUnit angleUnit = AngleUnit.radians,
    double ans = 0,
  }) {
    final fieldErrors = <String, String>{};
    final resolvedInputs = <String, String>{};

    for (final variable in formula.variables) {
      final provided = inputs[variable.symbol]?.trim() ?? '';
      final rawValue = provided.isEmpty
          ? variable.defaultValue ?? ''
          : provided;

      if (rawValue.isEmpty) {
        fieldErrors[variable.symbol] = 'Enter ${variable.label.toLowerCase()}.';
        continue;
      }

      final validation = _engine.evaluateDetailed(
        rawValue,
        angleUnit: angleUnit,
        ans: ans,
      );
      if (validation.isFailure) {
        fieldErrors[variable.symbol] =
            validation.errorMessage ?? 'Enter a valid calculator value.';
        continue;
      }

      resolvedInputs[variable.symbol] = rawValue;
    }

    if (fieldErrors.isNotEmpty) {
      return FormulaSolveResult(fieldErrors: fieldErrors);
    }

    var expression = formula.calculationExpression;
    for (final variable in formula.variables) {
      final placeholder = '{${variable.symbol}}';
      if (!expression.contains(placeholder)) {
        return FormulaSolveResult(
          configurationError:
              'Formula template is missing the $placeholder placeholder.',
        );
      }
      expression = expression.replaceAll(
        placeholder,
        '(${resolvedInputs[variable.symbol]})',
      );
    }

    if (expression.contains('{') || expression.contains('}')) {
      return const FormulaSolveResult(
        configurationError: 'Formula template contains an unknown placeholder.',
      );
    }

    final calculation = _engine.evaluateDetailed(
      expression,
      angleUnit: angleUnit,
      ans: ans,
    );
    return FormulaSolveResult(
      resolvedExpression: expression,
      calculation: calculation,
    );
  }

  /// Returns parser-safe calculator syntax for inserting a solved scalar back
  /// into the main calculator, including very large/small scientific values.
  String serializeResult(FormulaSolveResult result) {
    if (!result.isSuccess || result.value == null) return '';
    final display = result.displayText ?? '';
    if (display.isNotEmpty &&
        !display.contains('e') &&
        !display.contains('E')) {
      return display;
    }
    return _numericFormatter.serialize(result.value!);
  }
}
