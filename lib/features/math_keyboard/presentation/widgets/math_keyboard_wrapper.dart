import 'dart:math' as math;

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
  final _keyboardNavigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        const FloatingElementManager(),
        _MathKeyboardOverlay(navigatorKey: _keyboardNavigatorKey),
      ],
    );
  }
}

class _MathKeyboardOverlay extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const _MathKeyboardOverlay({required this.navigatorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mathKeyboardControllerProvider);
    final isMathVisible = state.isVisible && state.type == KeyboardType.math;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final adaptiveMax = math.max(240.0, math.min(500.0, screenHeight * 0.62));
    final adaptiveMin = math.min(280.0, adaptiveMax);
    final effectiveHeight = state.height
        .clamp(adaptiveMin, adaptiveMax)
        .toDouble();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: isMathVisible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        child: Material(
          child: SizedBox(
            height: effectiveHeight,
            child: HeroControllerScope.none(
              child: Navigator(
                key: navigatorKey,
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const MathKeyboardView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
