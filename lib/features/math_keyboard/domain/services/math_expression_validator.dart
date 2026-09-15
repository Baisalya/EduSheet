import 'dart:collection';

import '../../../editor/domain/models/math_expression.dart';
import 'math_safety_validation_service.dart';

class MathExpressionValidation {
  final bool isValid;
  final String? message;
  final String renderSource;
  final String accessibleFallback;

  const MathExpressionValidation({
    required this.isValid,
    required this.renderSource,
    required this.accessibleFallback,
    this.message,
  });
}

class MathExpressionValidator {
  final MathSafetyValidationService safetyValidationService;

  const MathExpressionValidator({
    this.safetyValidationService = const MathSafetyValidationService(),
  });

  MathExpressionValidation validate(MathExpression expression) {
    final source = expression.latex.trim();
    final safety = safetyValidationService.inspect(expression);
    final compatibility = safety.compatibility;
    final fallback = safety.readableFallback;

    if (!compatibility.syntaxValid) {
      return MathExpressionValidation(
        isValid: false,
        message: compatibility.syntaxMessage,
        renderSource: source,
        accessibleFallback: fallback,
      );
    }

    return MathExpressionValidation(
      isValid: true,
      renderSource: source,
      accessibleFallback: fallback,
    );
  }
}

class MathExpressionValidationCache {
  final int maximumEntries;
  final MathExpressionValidator validator;
  final LinkedHashMap<String, MathExpressionValidation> _entries =
      LinkedHashMap<String, MathExpressionValidation>();

  MathExpressionValidationCache({
    this.maximumEntries = 200,
    this.validator = const MathExpressionValidator(),
  }) : assert(maximumEntries > 0);

  int get length => _entries.length;

  MathExpressionValidation validate(MathExpression expression) {
    final key = '${expression.latex}\u0000${expression.plainText}';
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }

    final result = validator.validate(expression);
    _entries[key] = result;
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
    return result;
  }

  void clear() => _entries.clear();
}
