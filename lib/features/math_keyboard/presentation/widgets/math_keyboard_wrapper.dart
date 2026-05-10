import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_view.dart';

class MathKeyboardWrapper extends ConsumerWidget {
  final Widget child;

  const MathKeyboardWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mathKeyboardControllerProvider);
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final isMathVisible = state.isVisible && state.type == KeyboardType.math;

    return Material(
      child: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: Column(
              children: [
                Expanded(child: child),
                // Spacer to prevent content from being hidden behind math keyboard
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isMathVisible ? state.height : 0,
                  curve: Curves.easeOut,
                ),
              ],
            ),
          ),

          // Floating Math Keyboard
          Positioned(
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
                child: const MathKeyboardView(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
