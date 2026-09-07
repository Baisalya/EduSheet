enum ScienceSubject { physics, chemistry }

class FormulaVariable {
  final String symbol;
  final String label;
  final String unit;
  final String description;
  final String? defaultValue;

  const FormulaVariable({
    required this.symbol,
    required this.label,
    this.unit = '',
    this.description = '',
    this.defaultValue,
  });

  bool get hasDefaultValue => defaultValue != null && defaultValue!.isNotEmpty;
}

/// A science formula with an explicit calculator-safe solve target.
///
/// [expression] is the familiar textbook representation shown to the user,
/// while [calculationExpression] contains named placeholders such as `{m}`.
/// The formula solver replaces only those placeholders with validated user
/// input, preventing symbolic variables from leaking into MathEngine.
class Formula {
  final String name;
  final String expression;
  final String category;
  final ScienceSubject subject;
  final String description;
  final String targetSymbol;
  final String targetLabel;
  final String calculationExpression;
  final List<FormulaVariable> variables;
  final String resultUnit;

  const Formula({
    required this.name,
    required this.expression,
    required this.category,
    required this.subject,
    required this.targetSymbol,
    required this.targetLabel,
    required this.calculationExpression,
    required this.variables,
    this.description = '',
    this.resultUnit = '',
  });
}
