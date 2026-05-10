import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
import 'package:math_keyboard/src/foundation/node.dart' as math_kb_node;
import '../../domain/models/math_symbol.dart';

part 'math_keyboard_controller.g.dart';

enum KeyboardType { system, math }

class MathKeyboardStateData {
  final bool isVisible;
  final KeyboardType type;
  final dynamic activeController; // Can be TextEditingController or QuillController
  final FocusNode? activeFocusNode;
  final double height;
  final MathCategory currentCategory;
  final bool isTabletLayout;
  final bool isPowerMode;

  MathKeyboardStateData({
    this.isVisible = false,
    this.type = KeyboardType.system,
    this.activeController,
    this.activeFocusNode,
    this.height = 300,
    this.currentCategory = MathCategory.basic,
    this.isTabletLayout = false,
    this.isPowerMode = false,
  });

  MathKeyboardStateData copyWith({
    bool? isVisible,
    KeyboardType? type,
    dynamic activeController,
    FocusNode? activeFocusNode,
    bool clearActiveFocusNode = false,
    double? height,
    MathCategory? currentCategory,
    bool? isTabletLayout,
    bool? isPowerMode,
  }) {
    return MathKeyboardStateData(
      isVisible: isVisible ?? this.isVisible,
      type: type ?? this.type,
      activeController: activeController ?? this.activeController,
      activeFocusNode: clearActiveFocusNode ? null : (activeFocusNode ?? this.activeFocusNode),
      height: height ?? this.height,
      currentCategory: currentCategory ?? this.currentCategory,
      isTabletLayout: isTabletLayout ?? this.isTabletLayout,
      isPowerMode: isPowerMode ?? this.isPowerMode,
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

  void setCategory(MathCategory category) {
    state = state.copyWith(currentCategory: category);
  }

  void setHeight(double height) {
    // Clamp height between reasonable limits
    final clampedHeight = height.clamp(200.0, 500.0);
    state = state.copyWith(height: clampedHeight);
  }

  void toggleTabletLayout() {
    state = state.copyWith(isTabletLayout: !state.isTabletLayout);
  }

  void togglePowerMode() {
    state = state.copyWith(isPowerMode: !state.isPowerMode);
  }

  void insertText(String text) {
    final controller = state.activeController;
    if (controller == null) return;

    // Handle space/newline to exit power mode
    if (text == ' ' || text == '\n') {
      state = state.copyWith(isPowerMode: false);
    }

    if (controller is TextEditingController || controller is quill.QuillController) {
      // Map TeX to Unicode for standard text fields
      String textToInsert = text;
      
      // If Power Mode is active and it's a simple character, wrap it in power
      if (state.isPowerMode && (text.length == 1 || text == r'\pi' || text == 'e')) {
        final rawChar = text == r'\pi' ? 'π' : text;
        const superscripts = {'0':'⁰','1':'¹','2':'²','3':'³','4':'⁴','5':'⁵','6':'⁶','7':'⁷','8':'⁸','9':'⁹','n':'ⁿ','x':'ˣ','y':'ʸ','z':'ᶻ','a':'ᵃ','b':'ᵇ','c':'ᶜ','i':'ⁱ','π':'ᶲ'}; // Approximation for pi
        textToInsert = superscripts[rawChar] ?? '^$rawChar';
      } else {
        final symbol = mathSymbols.firstWhere((s) => s.tex == text, orElse: () => MathSymbol(label: text, tex: text, category: MathCategory.misc));
        
        // If it's a known math symbol with a label that is a single unicode character, use the label
        if (symbol.label.length == 1 || symbol.category == MathCategory.greek || symbol.category == MathCategory.operators) {
          textToInsert = symbol.label;
        }

        // Professional function insertion for standard fields
        final functions = [
          r'\sin', r'\cos', r'\tan', r'\csc', r'\sec', r'\cot', 
          r'\log', r'\ln', r'\arcsin', r'\arccos', r'\arctan',
          r'\sinh', r'\cosh', r'\tanh'
        ];
        
        if (functions.contains(text)) {
          textToInsert = '${textToInsert.replaceAll('\\', '')}()';
        } else if (text.endsWith(r'\theta') && text.length > 7) {
          // Handle theta versions like \sin \theta
          final func = text.split(' ').first.replaceAll('\\', '');
          textToInsert = '$func(θ)';
        }
      }
      
      // Handle specific common TeX strings if not caught by symbols
      if (text == r'^{2}') textToInsert = '²';
      if (text == r'^{3}') textToInsert = '³';
      if (text == r'\frac{1}{2}') textToInsert = '½';
      if (text.startsWith('^{') && text.endsWith('}')) {
        final content = text.substring(2, text.length - 1);
        if (content.length == 1) {
          // Map 0-9 to superscript unicode if possible
          const superscripts = {'0':'⁰','1':'¹','2':'²','3':'³','4':'⁴','5':'⁵','6':'⁶','7':'⁷','8':'⁸','9':'⁹','n':'ⁿ','x':'ˣ','y':'ʸ'};
          textToInsert = superscripts[content] ?? '^$content';
        } else {
          textToInsert = '^($content)';
        }
      }
      if (text == r'\sqrt{}') textToInsert = '√';
      if (text == r'\frac{}{}') textToInsert = '/';

      if (controller is TextEditingController) {
        final selection = controller.selection;
        final currentText = controller.text;
        
        final newText = currentText.replaceRange(
          selection.start != -1 ? selection.start : currentText.length,
          selection.end != -1 ? selection.end : currentText.length,
          textToInsert,
        );
        
        final newCursorPos = (selection.start != -1 ? selection.start : currentText.length) + textToInsert.length;
        
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPos),
        );
      } else if (controller is quill.QuillController) {
        final index = controller.selection.baseOffset;
        final length = controller.selection.extentOffset - index;
        
        controller.replaceText(index, length, textToInsert, null);
        controller.updateSelection(
          TextSelection.collapsed(offset: index + textToInsert.length),
          quill.ChangeSource.local,
        );
      }
    } else if (controller is math_kb.MathFieldEditingController) {
      final functionsWithBraces = [
        r'\sin', r'\cos', r'\tan', r'\csc', r'\sec', r'\cot', 
        r'\log', r'\ln', r'\arcsin', r'\arccos', r'\arctan',
        r'\sinh', r'\cosh', r'\tanh'
      ];
      
      if (text == r'\frac{1}{2}') {
        controller.addFunction(r'\frac', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
      } else if (functionsWithBraces.contains(text)) {
        controller.addLeaf(text);
        controller.addLeaf('(');
        controller.addLeaf(')');
        controller.goBack(); // Place cursor inside ()
      } else if (text.endsWith(r'\theta') && text.length > 7) {
        // Handle theta versions like \sin \theta
        final func = text.split(' ').first;
        controller.addLeaf(func);
        controller.addLeaf('(');
        controller.addLeaf(r'\theta');
        controller.addLeaf(')');
      } else if (text == r'\sqrt{}') {
        controller.addFunction(r'\sqrt', [math_kb_node.TeXArg.braces]);
      } else if (text == r'\sqrt[3]{}') {
        controller.addFunction(r'\sqrt', [math_kb_node.TeXArg.brackets, math_kb_node.TeXArg.braces]);
        controller.addLeaf('3');
        controller.goNext();
      } else if (text == r'^{}') {
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
      } else if (text == r'^{2}') {
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('2');
        controller.goNext(); // Move cursor after the exponent
      } else if (text == r'^{3}') {
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('3');
        controller.goNext(); // Move cursor after the exponent
      } else if (text == r'_{}') {
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
      } else if (text.startsWith('^{') && text.endsWith('}')) {
        final content = text.substring(2, text.length - 1);
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
        if (content.isNotEmpty) {
          for (var i = 0; i < content.length; i++) {
            controller.addLeaf(content[i]);
          }
          controller.goNext(); // Move cursor after the exponent
        }
      } else if (text == r'\int') {
        controller.addLeaf(r'\int');
      } else if (text == r'\int_{}^{}') {
        controller.addFunction(r'\int', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
      } else if (text == r'\sum_{}^{}') {
        controller.addFunction(r'\sum', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
      } else if (text == r'\prod_{}^{}') {
        controller.addFunction(r'\prod', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
      } else if (text == r'\log_{}(') {
        controller.addFunction(r'\log', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('(');
      } else if (text == r'e^{}') {
        controller.addLeaf('e');
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
      } else if (text == r'|{}|') {
        controller.addLeaf('|');
        controller.addLeaf('|');
        controller.goBack(); // Move cursor inside
      } else {
        if (state.isPowerMode && text.length == 1) {
          controller.addFunction('^', [math_kb_node.TeXArg.braces]);
          controller.addLeaf(text);
          controller.goNext();
        } else {
          controller.addLeaf(text);
        }
      }
    }
  }

  void clearAll() {
    final controller = state.activeController;
    if (controller == null) return;

    if (controller is TextEditingController) {
      controller.clear();
    } else if (controller is quill.QuillController) {
      controller.clear();
    } else if (controller is math_kb.MathFieldEditingController) {
      // MathFieldEditingController doesn't have a direct clear, 
      // but we can try to replace the whole content or re-init.
      // For now, let's just use a loop or re-assign value if possible.
      // Alternatively, we can use goBack in a loop if we knew the length.
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
