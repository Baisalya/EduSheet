import 'dart:collection';

import '../../../editor/domain/models/math_expression.dart';

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
  const MathExpressionValidator();

  MathExpressionValidation validate(MathExpression expression) {
    final source = expression.latex.trim();
    final fallback = expression.plainText.trim().isEmpty
        ? source
        : expression.plainText.trim();
    if (source.isEmpty) {
      return MathExpressionValidation(
        isValid: false,
        message: 'Formula source is empty.',
        renderSource: '',
        accessibleFallback: fallback,
      );
    }
    final balance = _firstBalanceError(source);
    if (balance != null) {
      return MathExpressionValidation(
        isValid: false,
        message: balance,
        renderSource: source,
        accessibleFallback: fallback,
      );
    }
    if (source.contains(r'\begin') != source.contains(r'\end')) {
      return MathExpressionValidation(
        isValid: false,
        message: 'Formula has an incomplete environment.',
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

  String? _firstBalanceError(String source) {
    final stack = <String>[];
    const opening = {'{': '}', '[': ']', '(': ')'};
    const closing = {'}': '{', ']': '[', ')': '('};
    var escaped = false;
    for (final codePoint in source.runes) {
      final character = String.fromCharCode(codePoint);
      if (escaped) {
        escaped = false;
        continue;
      }
      if (character == '\\') {
        escaped = true;
        continue;
      }
      if (opening.containsKey(character)) {
        stack.add(character);
      } else if (closing.containsKey(character)) {
        if (stack.isEmpty || stack.last != closing[character]) {
          return 'Formula has an unmatched “$character”.';
        }
        stack.removeLast();
      }
    }
    if (stack.isNotEmpty) {
      return 'Formula is missing “${opening[stack.last]}”.';
    }
    return null;
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
