import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_view.dart';
import 'floating_element_manager.dart';

class MathKeyboardWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const MathKeyboardWrapper({super.key, required this.child});

  @override
  ConsumerState<MathKeyboardWrapper> createState() =>
      _MathKeyboardWrapperState();
}

class _MathKeyboardWrapperState extends ConsumerState<MathKeyboardWrapper> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        const FloatingElementManager(),
        const _MathKeyboardOverlay(),
      ],
    );
  }
}

class _MathKeyboardOverlay extends ConsumerWidget {
  const _MathKeyboardOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mathKeyboardControllerProvider);
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final isMathVisible = state.isVisible && state.type == KeyboardType.math;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: isMathVisible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (isMathVisible) {
              controller.setHeight(state.height - details.delta.dy);
            }
          },
          child: Material(
            child: SizedBox(
              height: state.height,
              child: const MathKeyboardView(),
            ),
          ),
        ),
      ),
    );
  }
}
