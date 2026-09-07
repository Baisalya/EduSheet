import 'package:flutter/material.dart';

import '../../domain/models/calculator_editing_value.dart';

/// Native editing surface for the calculator expression.
///
/// The calculator owns the text in [CalculatorEditingValue]; this widget only
/// adapts that domain value to Flutter's native caret/selection experience.
/// It stays read-only so the on-screen calculator keypad remains the source of
/// text mutations and tapping the expression never opens the software keyboard.
class CalculatorExpressionEditor extends StatefulWidget {
  final CalculatorEditingValue value;
  final FocusNode focusNode;
  final ValueChanged<CalculatorSelection> onSelectionChanged;
  final bool compact;

  const CalculatorExpressionEditor({
    super.key,
    required this.value,
    required this.focusNode,
    required this.onSelectionChanged,
    this.compact = false,
  });

  @override
  State<CalculatorExpressionEditor> createState() =>
      _CalculatorExpressionEditorState();
}

class _CalculatorExpressionEditorState
    extends State<CalculatorExpressionEditor> {
  late final TextEditingController _textController;
  bool _applyingExternalValue = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController.fromValue(
      _toTextEditingValue(widget.value),
    );
    _textController.addListener(_handleEditingControllerChanged);
  }

  @override
  void didUpdateWidget(CalculatorExpressionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextValue = _toTextEditingValue(widget.value);
    if (_textController.value != nextValue) {
      _applyingExternalValue = true;
      _textController.value = nextValue;
      _applyingExternalValue = false;
    }

    // Calculator keys should not leave a hidden caret after a pointer click
    // temporarily transfers focus elsewhere. Refocus only after the domain
    // editing value itself changes, never on unrelated rebuilds/dialogs.
    if (oldWidget.value != widget.value && !widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusNode.canRequestFocus) {
          widget.focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleEditingControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _handleEditingControllerChanged() {
    if (_applyingExternalValue) return;

    final textValue = _textController.value;
    if (textValue.text != widget.value.text) {
      // The surface is intentionally read-only. If a platform edit ever slips
      // through, restore the authoritative calculator value rather than
      // creating a second text-mutation path.
      _applyingExternalValue = true;
      _textController.value = _toTextEditingValue(widget.value);
      _applyingExternalValue = false;
      return;
    }

    final selection = textValue.selection;
    if (!selection.isValid ||
        selection.baseOffset < 0 ||
        selection.extentOffset < 0) {
      return;
    }

    final calculatorSelection = CalculatorSelection(
      baseOffset: selection.baseOffset,
      extentOffset: selection.extentOffset,
    ).clamp(widget.value.text.length);

    if (calculatorSelection != widget.value.selection) {
      widget.onSelectionChanged(calculatorSelection);
    }
  }

  TextEditingValue _toTextEditingValue(CalculatorEditingValue value) {
    final normalized = value.normalized();
    return TextEditingValue(
      text: normalized.text,
      selection: TextSelection(
        baseOffset: normalized.selection.baseOffset,
        extentOffset: normalized.selection.extentOffset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      textField: true,
      label: 'Calculator expression',
      value: widget.value.text.isEmpty ? 'Empty' : widget.value.text,
      child: TextField(
        key: const ValueKey('calculator-expression-editor'),
        controller: _textController,
        focusNode: widget.focusNode,
        autofocus: true,
        readOnly: true,
        showCursor: true,
        enableInteractiveSelection: true,
        selectAllOnFocus: false,
        maxLines: 1,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        scrollPadding: EdgeInsets.zero,
        cursorWidth: 2,
        cursorRadius: const Radius.circular(2),
        cursorColor: theme.colorScheme.primary,
        scrollPhysics: const ClampingScrollPhysics(),
        onTapOutside: (_) {
          // Calculator keypad presses are outside the EditableText region but
          // should not dismiss the expression caret.
        },
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: widget.compact ? 4 : 7,
          ),
          hintText: '0',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(125),
            fontSize: widget.compact ? 19 : 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextStyle(
          fontSize: widget.compact ? 19 : 21,
          height: 1.15,
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
