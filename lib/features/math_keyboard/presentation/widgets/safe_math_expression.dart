import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../editor/domain/models/math_expression.dart';
import '../../domain/services/math_compatibility_service.dart';
import '../../domain/services/math_expression_validator.dart';

class SafeMathExpression extends StatelessWidget {
  static final MathExpressionValidationCache _validationCache =
      MathExpressionValidationCache();
  static final MathCompatibilityCache _compatibilityCache =
      MathCompatibilityCache();

  final MathExpression expression;
  final TextStyle? textStyle;

  const SafeMathExpression({
    super.key,
    required this.expression,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final validation = _validationCache.validate(expression);
    final compatibility = _compatibilityCache.inspectSource(
      expression.latex,
      plainFallback: validation.accessibleFallback,
    );
    final fallback = Text(
      validation.accessibleFallback,
      style: textStyle,
      overflow: TextOverflow.visible,
    );
    final rendererNative =
        compatibility.screenRenderer.support == MathCompatibilitySupport.native;
    final detail = !validation.isValid
        ? validation.message
        : compatibility.screenRenderer.message;

    return Semantics(
      label: !validation.isValid
          ? 'Formula needs attention. ${validation.accessibleFallback}. $detail'
          : !rendererNative
          ? 'Formula uses a safe fallback. ${validation.accessibleFallback}. $detail'
          : validation.accessibleFallback,
      readOnly: true,
      child: ExcludeSemantics(
        child: !validation.isValid || !rendererNative
            ? Tooltip(
                message: detail ?? 'Formula uses a readable fallback.',
                child: fallback,
              )
            : Math.tex(
                validation.renderSource,
                textStyle: textStyle,
                mathStyle: expression.display == MathExpressionDisplay.block
                    ? MathStyle.display
                    : MathStyle.text,
                // Keep the widget-level fallback as a final safety net for
                // layout/build failures that occur after parser preflight.
                onErrorFallback: (_) => fallback,
              ),
      ),
    );
  }
}
