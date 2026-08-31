import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_interaction_region.dart';

class MathKeyboardField extends ConsumerStatefulWidget {
  final Widget Function(
    BuildContext context,
    FocusNode fieldFocusNode,
    bool isMathActive,
  )
  builder;
  final Object
  controller; // TextEditingController, QuillController, or MathFieldEditingController
  final FocusNode? focusNode;

  /// Keeps an already-visible custom math session alive across focus churn.
  ///
  /// Use this for composite editors such as `MathField` that can temporarily
  /// move focus while changing their keyboard mode. The owning feature must
  /// explicitly release the session when the user moves to a different, normal
  /// text editor.
  final bool retainMathSessionOnFocusLoss;

  const MathKeyboardField({
    super.key,
    required this.builder,
    required this.controller,
    this.focusNode,
    this.retainMathSessionOnFocusLoss = false,
  });

  @override
  ConsumerState<MathKeyboardField> createState() => _MathKeyboardFieldState();
}

class _MathKeyboardFieldState extends ConsumerState<MathKeyboardField> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late final MathKeyboardController _mathKeyboardController;
  bool _isFocused = false;
  bool _disposed = false;
  bool _wasMathActive = false;
  double? _lastMathKeyboardHeight;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _mathKeyboardController = ref.read(mathKeyboardControllerProvider.notifier);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant MathKeyboardField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousFocusNode = _focusNode;
    final focusNodeChanged = !identical(oldWidget.focusNode, widget.focusNode);
    final controllerChanged = !identical(
      oldWidget.controller,
      widget.controller,
    );
    if (!focusNodeChanged && !controllerChanged) return;

    final keyboardBeforeUpdate = ref.read(mathKeyboardControllerProvider);
    final ownedVisibleMathSession =
        keyboardBeforeUpdate.isVisible &&
        keyboardBeforeUpdate.type == KeyboardType.math &&
        identical(
          keyboardBeforeUpdate.activeController,
          oldWidget.controller,
        ) &&
        identical(keyboardBeforeUpdate.activeFocusNode, previousFocusNode);
    final hadFocusBeforeUpdate = previousFocusNode.hasFocus;
    final previousFocusWasOwned = _ownsFocusNode;

    if (focusNodeChanged) {
      previousFocusNode.removeListener(_onFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_onFocusChange);
      _isFocused = _focusNode.hasFocus || hadFocusBeforeUpdate;
    }

    final updatedController = widget.controller;
    final updatedFocusNode = _focusNode;
    final previousController = oldWidget.controller;

    // Riverpod must not be mutated from didUpdateWidget. Synchronize the
    // keyboard owner only after the rebuilt editor/focus node is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNodeChanged && previousFocusWasOwned) {
        try {
          previousFocusNode.dispose();
        } catch (_) {
          // The old internally-owned focus node may already be disposed during
          // route teardown. Ownership synchronization is best-effort here.
        }
      }

      if (_disposed || !mounted) return;

      final currentKeyboardState = ref.read(mathKeyboardControllerProvider);
      final shouldTransferVisibleSession =
          ownedVisibleMathSession &&
          currentKeyboardState.isVisible &&
          currentKeyboardState.type == KeyboardType.math &&
          identical(
            currentKeyboardState.activeController,
            previousController,
          ) &&
          identical(currentKeyboardState.activeFocusNode, previousFocusNode) &&
          (hadFocusBeforeUpdate || updatedFocusNode.hasFocus);

      if (shouldTransferVisibleSession) {
        _mathKeyboardController.transferMathSessionOwner(
          previousController,
          updatedController,
          updatedFocusNode,
        );

        if (hadFocusBeforeUpdate &&
            updatedFocusNode.canRequestFocus &&
            updatedFocusNode.context != null &&
            !updatedFocusNode.hasFocus) {
          updatedFocusNode.requestFocus();
        }
        _ensureVisibleAboveKeyboard();
        return;
      }

      _mathKeyboardController.unregisterController(
        previousController,
        focusNode: previousFocusNode,
      );

      if (hadFocusBeforeUpdate &&
          updatedFocusNode.canRequestFocus &&
          updatedFocusNode.context != null &&
          !updatedFocusNode.hasFocus) {
        updatedFocusNode.requestFocus();
      }

      if (updatedFocusNode.hasFocus) {
        _mathKeyboardController.registerController(
          updatedController,
          updatedFocusNode,
        );
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _focusNode.removeListener(_onFocusChange);

    final controller = widget.controller;
    final focusNode = _focusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mathKeyboardController.unregisterController(
          controller,
          focusNode: focusNode,
        );
      } catch (_) {
        // Provider scope may already be disposed during test/app teardown.
      }
    });

    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  /// MathField disables its text-input connection while the custom keyboard is
  /// active. That correctly suppresses the native IME, but on Windows it also
  /// means ordinary hardware letters and numbers have no text client to reach.
  /// Route those keys through the same structured editor adapter as on-screen
  /// math keys. Other editors keep their normal native hardware-key behavior.
  KeyEventResult _handleHardwareKey(FocusNode node, KeyEvent event) {
    if (_disposed ||
        event is! KeyDownEvent && event is! KeyRepeatEvent ||
        widget.controller is! math_kb.MathFieldEditingController) {
      return KeyEventResult.ignored;
    }

    final state = ref.read(mathKeyboardControllerProvider);
    if (!state.isVisible ||
        state.type != KeyboardType.math ||
        !identical(state.activeController, widget.controller)) {
      return KeyEventResult.ignored;
    }

    final hardware = HardwareKeyboard.instance;
    if (hardware.isControlPressed ||
        hardware.isAltPressed ||
        hardware.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _mathKeyboardController.deleteBackward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _mathKeyboardController.moveCursorLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _mathKeyboardController.moveCursorRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _mathKeyboardController.nextField();
      return KeyEventResult.handled;
    }

    final character = _mathHardwareCharacter(event);
    if (character == null) return KeyEventResult.ignored;
    _mathKeyboardController.insertText(character);
    return KeyEventResult.handled;
  }

  String? _mathHardwareCharacter(KeyEvent event) {
    final character = event.character;
    if (character != null &&
        character.runes.length == 1 &&
        RegExp(r'^[A-Za-z0-9+\-*/=().,\[\]{}<>^_%|!:]$').hasMatch(character)) {
      return character;
    }

    final explicitKeys = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
      LogicalKeyboardKey.numpadAdd: '+',
      LogicalKeyboardKey.numpadSubtract: '-',
      LogicalKeyboardKey.numpadMultiply: '*',
      LogicalKeyboardKey.numpadDivide: '/',
      LogicalKeyboardKey.numpadDecimal: '.',
      LogicalKeyboardKey.numpadEqual: '=',
    };
    final explicit = explicitKeys[event.logicalKey];
    if (explicit != null) return explicit;

    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.length == 1 &&
        RegExp(r'^[A-Za-z0-9+\-*/=().,\[\]{}<>^_%|!:]$').hasMatch(keyLabel)) {
      return HardwareKeyboard.instance.isShiftPressed
          ? keyLabel.toUpperCase()
          : keyLabel.toLowerCase();
    }
    return null;
  }

  void _onFocusChange() {
    if (_disposed) return;

    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_focusNode.hasFocus) {
      _mathKeyboardController.registerController(widget.controller, _focusNode);

      // If math keyboard is already supposed to be active, hide system IME immediately
      final state = ref.read(mathKeyboardControllerProvider);
      if (state.isVisible && state.type == KeyboardType.math) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _ensureVisibleAboveKeyboard();
      }
    } else {
      // Defer by one frame so focus can transfer to another math field
      // without leaving a Timer alive during route/widget teardown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !mounted || _focusNode.hasFocus) return;

        final state = ref.read(mathKeyboardControllerProvider);
        final ownsVisibleMathSession =
            state.isVisible &&
            state.type == KeyboardType.math &&
            identical(state.activeController, widget.controller);
        if (ownsVisibleMathSession && widget.retainMathSessionOnFocusLoss) {
          return;
        }

        final destinationContext = FocusManager.instance.primaryFocus?.context;
        final movedInsideThisField = _containsFocusContext(destinationContext);
        final movedIntoMathKeyboard = MathKeyboardInteractionRegion.contains(
          destinationContext,
        );
        final movedToExternalEditable = _isEditableFocusOutsideMathKeyboard(
          destinationContext,
        );

        // A visible custom-keyboard session is owned by the editor controller,
        // not by one fragile desktop focus frame. MathField may hand focus
        // between internal focus nodes/EditableText objects when `opensKeyboard`
        // changes. That internal hand-off is still the same editor session and
        // must not be mistaken for the user moving to another field.
        //
        // Release only when focus actually lands in a different editable
        // control outside both this MathKeyboardField and the custom keyboard.
        if (ownsVisibleMathSession &&
            (destinationContext == null ||
                movedInsideThisField ||
                movedIntoMathKeyboard ||
                !movedToExternalEditable)) {
          return;
        }

        _mathKeyboardController.unregisterController(
          widget.controller,
          focusNode: _focusNode,
        );
      });
    }
  }

  bool _containsFocusContext(BuildContext? destinationContext) {
    if (destinationContext == null) return false;
    if (identical(destinationContext, context)) return true;

    var isInside = false;
    destinationContext.visitAncestorElements((element) {
      if (identical(element, context)) {
        isInside = true;
        return false;
      }
      return true;
    });
    return isInside;
  }

  bool _isEditableFocusOutsideMathKeyboard(BuildContext? context) {
    if (context == null || MathKeyboardInteractionRegion.contains(context)) {
      return false;
    }

    if (context.widget is EditableText) return true;

    var foundEditable = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        foundEditable = true;
        return false;
      }
      return true;
    });
    return foundEditable;
  }

  void _ensureVisibleAboveKeyboard() {
    void reveal() {
      if (_disposed || !mounted) return;

      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;

      try {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } catch (_) {
        // Keeping the field above the keyboard is a convenience. During route
        // teardown/re-parenting a ScrollPosition can detach between frames;
        // focus/input must remain functional even when reveal is no longer
        // possible for that frame.
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      reveal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardState = ref.watch(mathKeyboardControllerProvider);
    final isMathActive =
        keyboardState.isVisible &&
        keyboardState.type == KeyboardType.math &&
        identical(keyboardState.activeController, widget.controller);
    if (_isFocused && isMathActive) {
      final heightChanged = _lastMathKeyboardHeight != keyboardState.height;
      if (!_wasMathActive || heightChanged) {
        _wasMathActive = true;
        _lastMathKeyboardHeight = keyboardState.height;
        _ensureVisibleAboveKeyboard();
      }
    } else {
      _wasMathActive = false;
      _lastMathKeyboardHeight = null;
    }

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
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _handleHardwareKey,
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
                          if (isMathActive) {
                            _mathKeyboardController.showSystemKeyboard();
                            // Re-show system keyboard with a small delay to ensure readOnly is false
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_disposed) return;
                              SystemChannels.textInput.invokeMethod(
                                'TextInput.show',
                              );
                            });
                          } else {
                            _mathKeyboardController.showMathKeyboardFor(
                              widget.controller,
                              _focusNode,
                            );
                            // Explicitly hide system keyboard without losing focus
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.hide',
                            );
                            _ensureVisibleAboveKeyboard();
                          }

                          if (!_focusNode.hasFocus) {
                            _focusNode.requestFocus();
                            _ensureVisibleAboveKeyboard();
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
        ),
        if (isMathActive && _isFocused) _buildMathPreview(),
      ],
    );
  }

  Widget _buildMathPreview() {
    String tex = '';
    final controller = widget.controller;

    // Safety check: Don't use disposed controllers
    try {
      if (controller is TextEditingController) {
        // This might still throw if disposed but we try our best
        tex = controller.text;
      } else if (controller is quill.QuillController) {
        // For Quill, we show the plain text in the preview
        tex = controller.document.toPlainText().trim();
      } else if (controller is math_kb.MathFieldEditingController) {
        tex = controller.currentEditingValue();
      }
    } catch (_) {
      return const SizedBox.shrink();
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
              Expanded(
                child: Text(
                  'BOOK PREVIEW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
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
