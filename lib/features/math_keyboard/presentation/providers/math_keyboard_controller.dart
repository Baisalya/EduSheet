import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:math_keyboard/math_keyboard.dart' as math_kb;

part 'math_keyboard_controller.g.dart';

enum KeyboardType { system, math }

class MathKeyboardStateData {
  final bool isVisible;
  final KeyboardType type;
  final dynamic activeController; // Can be TextEditingController or QuillController
  final FocusNode? activeFocusNode;

  MathKeyboardStateData({
    this.isVisible = false,
    this.type = KeyboardType.system,
    this.activeController,
    this.activeFocusNode,
  });

  MathKeyboardStateData copyWith({
    bool? isVisible,
    KeyboardType? type,
    dynamic activeController,
    FocusNode? activeFocusNode,
    bool clearActiveFocusNode = false,
  }) {
    return MathKeyboardStateData(
      isVisible: isVisible ?? this.isVisible,
      type: type ?? this.type,
      activeController: activeController ?? this.activeController,
      activeFocusNode: clearActiveFocusNode ? null : (activeFocusNode ?? this.activeFocusNode),
    );
  }
}

@riverpod
class MathKeyboardController extends _$MathKeyboardController {
  @override
  MathKeyboardStateData build() => MathKeyboardStateData();

  void registerController(dynamic controller, FocusNode focusNode) {
    state = state.copyWith(activeController: controller, activeFocusNode: focusNode);
  }

  void unregisterController(dynamic controller) {
    if (state.activeController == controller) {
      state = state.copyWith(activeController: null, clearActiveFocusNode: true, isVisible: false);
    }
  }

  void showMathKeyboard() {
    state = state.copyWith(isVisible: true, type: KeyboardType.math);
    // Unfocus to hide system keyboard if it's visible, but we might want to keep focus for insertion
    // Actually, keeping focus is better for cursor position.
    // We'll use a trick in the UI to prevent system keyboard from showing.
  }

  void showSystemKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    state.activeFocusNode?.requestFocus();
  }

  void insertText(String text) {
    final controller = state.activeController;
    if (controller == null) return;

    if (controller is TextEditingController) {
      final selection = controller.selection;
      final currentText = controller.text;
      
      final newText = currentText.replaceRange(
        selection.start != -1 ? selection.start : currentText.length,
        selection.end != -1 ? selection.end : currentText.length,
        text,
      );
      
      final newCursorPos = (selection.start != -1 ? selection.start : currentText.length) + text.length;
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    } else if (controller is quill.QuillController) {
      final index = controller.selection.baseOffset;
      final length = controller.selection.extentOffset - index;
      
      controller.replaceText(index, length, text, null);
      controller.updateSelection(
        TextSelection.collapsed(offset: index + text.length),
        quill.ChangeSource.local,
      );
    } else if (controller is math_kb.MathFieldEditingController) {
      controller.addLeaf(text);
    }
  }

  void deleteBackward() {
    final controller = state.activeController;
    if (controller == null) return;

    if (controller is TextEditingController) {
      final selection = controller.selection;
      if (selection.start == selection.end && selection.start > 0) {
        final currentText = controller.text;
        final newText = currentText.replaceRange(selection.start - 1, selection.start, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start - 1),
        );
      } else if (selection.start != selection.end) {
        final currentText = controller.text;
        final newText = currentText.replaceRange(selection.start, selection.end, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
      }
    } else if (controller is quill.QuillController) {
      final index = controller.selection.baseOffset;
      final length = controller.selection.extentOffset - index;
      
      if (length > 0) {
        controller.replaceText(index, length, '', null);
      } else if (index > 0) {
        controller.replaceText(index - 1, 1, '', null);
        controller.updateSelection(
          TextSelection.collapsed(offset: index - 1),
          quill.ChangeSource.local,
        );
      }
    } else if (controller is math_kb.MathFieldEditingController) {
      controller.goBack(deleteMode: true);
    }
  }
}
