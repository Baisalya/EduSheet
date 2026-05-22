import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
import '../providers/math_keyboard_controller.dart';

class MathKeyboardField extends ConsumerStatefulWidget {
  final Widget Function(
    BuildContext context,
    FocusNode fieldFocusNode,
    bool isMathActive,
  )
  builder;
  final dynamic
  controller; // TextEditingController, QuillController, or MathFieldEditingController

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
      ref
          .read(mathKeyboardControllerProvider.notifier)
          .registerController(widget.controller, _focusNode);

      // If math keyboard is already supposed to be active, hide system IME immediately
      final state = ref.read(mathKeyboardControllerProvider);
      if (state.isVisible && state.type == KeyboardType.math) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    } else {
      // Small delay to allow potential focus transfer
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_focusNode.hasFocus) {
          ref
              .read(mathKeyboardControllerProvider.notifier)
              .unregisterController(widget.controller);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive =
        keyboardState.isVisible && keyboardState.type == KeyboardType.math;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (isMathActive) {
              // Proactively hide system keyboard when tapping while math is active
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            }
          },
          child: Stack(
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
                            : Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                      ),
                      onPressed: () async {
                        final notifier = ref.read(
                          mathKeyboardControllerProvider.notifier,
                        );

                        if (isMathActive) {
                          notifier.showSystemKeyboard();
                          // Re-show system keyboard with a small delay to ensure readOnly is false
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.show',
                            );
                          });
                        } else {
                          notifier.showMathKeyboard();
                          // Explicitly hide system keyboard without losing focus
                          SystemChannels.textInput.invokeMethod(
                            'TextInput.hide',
                          );
                        }

                        if (!_focusNode.hasFocus) {
                          _focusNode.requestFocus();
                        }
                      },
                      tooltip: isMathActive
                          ? 'System Keyboard'
                          : 'Math Keyboard',
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isMathActive && _isFocused) _buildMathPreview(),
      ],
    );
  }

  Widget _buildMathPreview() {
    String tex = '';
    final controller = widget.controller;

    if (controller is TextEditingController) {
      tex = controller.text;
    } else if (controller is math_kb.MathFieldEditingController) {
      tex = controller.currentEditingValue();
    }

    if (tex.isEmpty) return const SizedBox.shrink();

    final isTexLike =
        controller is math_kb.MathFieldEditingController ||
        tex.contains('\\') ||
        tex.contains(r'\frac') ||
        tex.contains(r'\sqrt');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.functions,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'BOOK PREVIEW',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: isTexLike
                    ? Math.tex(
                        tex,
                        mathStyle: MathStyle.display,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'serif',
                        ),
                        onErrorFallback: (err) => Text(
                          tex,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.45,
                            fontFamily: 'serif',
                          ),
                        ),
                      )
                    : Text(
                        tex,
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.45,
                          fontFamily: 'serif',
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
