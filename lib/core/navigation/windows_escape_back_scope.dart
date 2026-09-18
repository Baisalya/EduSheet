import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dismiss_layer_coordinator.dart';

/// Provides a single Windows Escape-to-back policy for the application.
///
/// This widget must wrap feature-level keyboard handlers. Key events bubble
/// from the focused descendant outward, so existing handlers (math keyboard,
/// presentation mode, geometry tools, etc.) get the first opportunity to
/// consume Escape. Only an otherwise-unhandled plain Escape reaches this
/// fallback.
class WindowsEscapeBackScope extends ConsumerWidget {
  WindowsEscapeBackScope({
    super.key,
    required this.navigatorKey,
    required this.child,
    bool? enabled,
  }) : enabled = enabled ?? Platform.isWindows;

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleKeyEvent(ref, event),
      child: child,
    );
  }

  KeyEventResult _handleKeyEvent(WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final dismissResult = ref
        .read(dismissLayerCoordinatorProvider)
        .handleEscape();
    if (dismissResult == DismissLayerResult.dismissed ||
        dismissResult == DismissLayerResult.blocked) {
      return KeyEventResult.handled;
    }

    if (_isEditingOnPageRoute()) {
      // An unhandled Escape while typing on a normal page must not discard the
      // user's editing context by navigating away. Popup/modal routes remain
      // eligible so dialogs and sheets still close as expected.
      return KeyEventResult.handled;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      // Consume plain Escape at the root so it can never become an accidental
      // application-exit gesture.
      return KeyEventResult.handled;
    }

    // maybePop respects PopScope/route pop disposition and therefore preserves
    // existing back contracts instead of forcing a route off the stack.
    unawaited(navigator.maybePop());
    return KeyEventResult.handled;
  }

  bool _isEditingOnPageRoute() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;

    final editable = focusContext.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return false;

    return ModalRoute.of(focusContext) is PageRoute;
  }
}
