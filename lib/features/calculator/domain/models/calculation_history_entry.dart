import 'calculator_mode.dart';

class CalculationHistoryEntry {
  final String expression;
  final String result;
  final AngleUnit angleUnit;
  final DateTime createdAt;

  const CalculationHistoryEntry({
    required this.expression,
    required this.result,
    required this.angleUnit,
    required this.createdAt,
  });
}
