import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/safe_math_expression.dart';
import 'package:edusheet/features/paper_composer/application/question_math_surface_service.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';
import 'package:flutter/material.dart';

/// Renders one legacy string surface with its structured inline math document
/// when the metadata document still matches that exact fallback string.
class QuestionMathSurfaceView extends StatelessWidget {
  static const _service = QuestionMathSurfaceService();

  final Question question;
  final String surfaceKey;
  final String fallbackText;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final WrapAlignment? alignment;
  final bool showFallback;

  const QuestionMathSurfaceView({
    super.key,
    required this.question,
    required this.surfaceKey,
    required this.fallbackText,
    this.style,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow,
    this.alignment,
    this.showFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final document = _service.activeDocument(
      question,
      surfaceKey,
      fallbackText,
    );
    if (document == null) {
      if (!showFallback) return const SizedBox.shrink();
      return Text(
        fallbackText,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final children = <Widget>[];
    for (final part in document.parts) {
      switch (part.kind) {
        case QuestionMathInlinePartKind.text:
          if (part.text.isNotEmpty) {
            children.add(Text(part.text, style: style, textAlign: textAlign));
          }
          break;
        case QuestionMathInlinePartKind.math:
          final expression = part.expression;
          if (expression != null) {
            children.add(
              SafeMathExpression(expression: expression, textStyle: style),
            );
          }
          break;
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: document.fallbackText,
      child: ExcludeSemantics(
        child: Wrap(
          alignment:
              alignment ??
              switch (textAlign) {
                TextAlign.center => WrapAlignment.center,
                TextAlign.right || TextAlign.end => WrapAlignment.end,
                TextAlign.left ||
                TextAlign.start ||
                TextAlign.justify => WrapAlignment.start,
              },
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          runSpacing: 2,
          children: children,
        ),
      ),
    );
  }
}
