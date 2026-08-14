enum CalculationErrorCode {
  syntax,
  domain,
  divisionByZero,
  overflow,
  unsupported,
  unknown,
}

class CalculationResult {
  final double? value;
  final String displayText;
  final CalculationErrorCode? errorCode;
  final String? errorMessage;

  const CalculationResult._({
    required this.value,
    required this.displayText,
    required this.errorCode,
    required this.errorMessage,
  });

  const CalculationResult.success({
    required double value,
    required String displayText,
  }) : this._(
         value: value,
         displayText: displayText,
         errorCode: null,
         errorMessage: null,
       );

  const CalculationResult.failure({
    required CalculationErrorCode errorCode,
    required String errorMessage,
  }) : this._(
         value: null,
         displayText: 'Error',
         errorCode: errorCode,
         errorMessage: errorMessage,
       );

  bool get isSuccess => errorCode == null;
  bool get isFailure => !isSuccess;
}
