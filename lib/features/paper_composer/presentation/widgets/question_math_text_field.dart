import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:flutter/material.dart';

/// A normal [TextField] that can switch to EduSheet's existing custom math
/// keyboard without creating a second keyboard/session implementation.
///
/// Advanced paper blocks (passages, word banks, table cells and captions) use
/// the same controller/focus ownership contract as question options, so a
/// teacher can enter mathematical symbols anywhere those blocks are editable.
class QuestionMathTextField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final int? minLines;
  final int? maxLines;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;

  const QuestionMathTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return MathKeyboardField(
      controller: controller,
      builder: (context, focusNode, isMathActive) => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: isMathActive ? TextInputType.none : keyboardType,
        textInputAction: textInputAction,
        decoration: decoration,
        onChanged: onChanged,
      ),
    );
  }
}
