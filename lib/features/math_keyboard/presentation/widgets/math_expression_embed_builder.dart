import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'safe_math_expression.dart';

/// Quill representation of a structured EduSheet math expression.
///
/// Unlike [BlockEmbed], this extends [Embeddable] directly so Flutter Quill
/// keeps it inside the surrounding text line. It therefore behaves like one
/// rich-text character while rendering a real textbook-style formula.
class MathExpressionEmbed extends Embeddable {
  MathExpressionEmbed(MathExpression expression)
      : super(MathExpression.quillEmbedKey, expression.toQuillEmbedData());
}

typedef MathExpressionEditCallback = Future<MathExpression?> Function(
  BuildContext context,
  MathExpression expression,
);

/// Renders an EduSheet formula embedded directly inside a Quill sentence.
///
/// In editable documents a tap opens the caller-provided formula editor and
/// replaces the same one-character embed in-place. In previews the exact same
/// builder is read-only, so authoring and preview use one representation.
class MathExpressionEmbedBuilder extends EmbedBuilder {
  const MathExpressionEmbedBuilder({this.onEdit, this.onChanged});

  final MathExpressionEditCallback? onEdit;
  final ValueChanged<MathExpression>? onChanged;

  @override
  String get key => MathExpression.quillEmbedKey;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) {
    final expression = MathExpression.tryFromQuillEmbedData(node.value.data);
    if (expression == null) return '[formula]';
    return _fallback(expression);
  }

  @override
  WidgetSpan buildWidgetSpan(Widget widget) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: widget,
    );
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final expression =
        MathExpression.tryFromQuillEmbedData(embedContext.node.value.data);
    if (expression == null) {
      return Text(
        '[formula]',
        style: embedContext.textStyle.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }

    final formula = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expression.display == MathExpressionDisplay.inline ? 2 : 6,
        vertical: expression.display == MathExpressionDisplay.inline ? 0 : 4,
      ),
      child: SafeMathExpression(
        expression: expression,
        textStyle: embedContext.textStyle,
      ),
    );

    if (embedContext.readOnly || onEdit == null) return formula;

    return Tooltip(
      message: 'Tap to edit math',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _edit(context, embedContext, expression),
          child: formula,
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    EmbedContext embedContext,
    MathExpression expression,
  ) async {
    final callback = onEdit;
    if (callback == null) return;
    final updated = await callback(context, expression);
    if (updated == null || !context.mounted) return;

    final offset = embedContext.node.documentOffset;
    embedContext.controller.replaceText(
      offset,
      1,
      MathExpressionEmbed(updated),
      null,
    );
    embedContext.controller.updateSelection(
      TextSelection.collapsed(offset: offset + 1),
      ChangeSource.local,
    );
    onChanged?.call(updated);
  }

  static String _fallback(MathExpression expression) {
    final text = expression.plainText.trim();
    return text.isEmpty ? expression.latex : text;
  }
}
