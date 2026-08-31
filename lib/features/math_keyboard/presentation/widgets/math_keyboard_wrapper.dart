import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_view.dart';
import 'math_keyboard_interaction_region.dart';
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

    final effectiveHeight = effectiveMathKeyboardHeight(
      MediaQuery.sizeOf(context),
      state.height,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        key: const ValueKey('math-keyboard-slide'),
        offset: isMathVisible ? Offset.zero : const Offset(0, 1),
        duration: mathKeyboardTransitionDuration,
        curve: Curves.easeOutCubic,
        child: Material(
          child: SizedBox(
            key: const ValueKey('math-keyboard-overlay'),
            height: effectiveHeight,
            child: MathKeyboardInteractionRegion(
              child: HeroControllerScope.none(
                child: Navigator(
                  key: navigatorKey,
                  // The keyboard has its own route stack, but merely revealing
                  // that stack must never steal focus from the active formula
                  // field. Individual keyboard search inputs can still request
                  // focus when the user explicitly taps them.
                  requestFocus: false,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (context) => const MathKeyboardView(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
