import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../editor/domain/models/math_expression.dart';
import '../../domain/services/math_expression_validator.dart';

class SafeMathExpression extends StatelessWidget {
  static final MathExpressionValidationCache _validationCache =
      MathExpressionValidationCache();

  final MathExpression expression;
  final TextStyle? textStyle;

  const SafeMathExpression({super.key, required this.expression, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final validation = _validationCache.validate(expression);
    final fallback = Text(
      validation.accessibleFallback,
      style: textStyle,
      overflow: TextOverflow.visible,
    );
    return Semantics(
      label: validation.isValid
          ? validation.accessibleFallback
          : 'Formula needs attention. ${validation.accessibleFallback}. '
                '${validation.message}',
      readOnly: true,
      child: ExcludeSemantics(
        child: validation.isValid
            ? Math.tex(
                validation.renderSource,
                textStyle: textStyle,
                mathStyle: expression.display == MathExpressionDisplay.block
                    ? MathStyle.display
                    : MathStyle.text,
                onErrorFallback: (_) => fallback,
              )
            : Tooltip(
                message:
                    '${validation.message} Tap Edit to repair the formula.',
                child: fallback,
              ),
      ),
    );
  }
}
