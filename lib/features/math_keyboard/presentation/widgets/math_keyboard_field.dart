import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/math_keyboard_controller.dart';

class MathKeyboardField extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, FocusNode fieldFocusNode, bool isMathActive) builder;
  final dynamic controller; // TextEditingController or QuillController

  const MathKeyboardField({
    super.key,
    required this.builder,
    required this.controller,
  });

  @override
  ConsumerState<MathKeyboardField> createState() => _MathKeyboardFieldState();
}

class _MathKeyboardFieldState extends ConsumerState<MathKeyboardField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_focusNode.hasFocus) {
      ref.read(mathKeyboardControllerProvider.notifier).registerController(widget.controller, _focusNode);
    } else {
      // Small delay to allow potential focus transfer
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_focusNode.hasFocus) {
          ref.read(mathKeyboardControllerProvider.notifier).unregisterController(widget.controller);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive = keyboardState.isVisible && keyboardState.type == KeyboardType.math;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        widget.builder(context, _focusNode, isMathActive),
        if (_isFocused)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: isMathActive 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.secondaryContainer,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                icon: Icon(
                  isMathActive ? Icons.keyboard : Icons.functions,
                  size: 20,
                  color: isMathActive 
                      ? Theme.of(context).colorScheme.onPrimary 
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                onPressed: () {
                  final notifier = ref.read(mathKeyboardControllerProvider.notifier);
                  if (isMathActive) {
                    notifier.showSystemKeyboard();
                  } else {
                    notifier.showMathKeyboard();
                  }
                  
                  // Re-request focus to ensure the keyboardType change is picked up
                  // and the correct keyboard (none vs system) is shown/hidden.
                  _focusNode.unfocus();
                  Future.delayed(const Duration(milliseconds: 50), () {
                    _focusNode.requestFocus();
                  });
                },
                tooltip: isMathActive ? 'System Keyboard' : 'Math Keyboard',
              ),
            ),
          ),
      ],
    );
  }
}
