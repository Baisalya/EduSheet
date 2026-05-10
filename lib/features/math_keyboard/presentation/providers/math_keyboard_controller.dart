import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
import 'package:math_keyboard/src/foundation/node.dart' as math_kb_node;
import 'package:uuid/uuid.dart';
import '../../domain/models/math_symbol.dart';

part 'math_keyboard_controller.g.dart';

enum KeyboardType { system, math }

enum FloatingElementType { shape, textBox }

class FloatingElement {
  final String id;
  final FloatingElementType type;
  final Offset position;
  final Size size;
  final String? content; // For text box or specific shape data
  final IconData? icon; // For shapes

  FloatingElement({
    required this.id,
    required this.type,
    required this.position,
    this.size = const Size(100, 100),
    this.content,
    this.icon,
  });

  FloatingElement copyWith({
    Offset? position,
    Size? size,
    String? content,
  }) {
    return FloatingElement(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      content: content ?? this.content,
      icon: icon,
    );
  }
}

class MathKeyboardStateData {
  final bool isVisible;
  final KeyboardType type;
  final dynamic activeController; // Can be TextEditingController or QuillController
  final FocusNode? activeFocusNode;
  final double height;
  final MathCategory currentCategory;
  final bool isTabletLayout;
  final bool isPowerMode;
  final int symbolSizeLevel; // -2 to +2 (small to large)
  final List<FloatingElement> floatingElements;

  MathKeyboardStateData({
    this.isVisible = false,
    this.type = KeyboardType.system,
    this.activeController,
    this.activeFocusNode,
    this.height = 300,
    this.currentCategory = MathCategory.basic,
    this.isTabletLayout = false,
    this.isPowerMode = false,
    this.symbolSizeLevel = 0,
    this.floatingElements = const [],
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
    int? symbolSizeLevel,
    List<FloatingElement>? floatingElements,
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
      symbolSizeLevel: symbolSizeLevel ?? this.symbolSizeLevel,
      floatingElements: floatingElements ?? this.floatingElements,
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
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void showSystemKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    // The UI (MathKeyboardField) will handle calling TextInput.show after a frame
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

  void addFloatingElement(FloatingElementType type, {IconData? icon}) {
    final newElement = FloatingElement(
      id: const Uuid().v4(),
      type: type,
      position: const Offset(50, 100),
      icon: icon,
      size: type == FloatingElementType.textBox ? const Size(150, 60) : const Size(80, 80),
    );
    state = state.copyWith(floatingElements: [...state.floatingElements, newElement]);
  }

  void updateElement(String id, {Offset? position, Size? size, String? content}) {
    state = state.copyWith(
      floatingElements: state.floatingElements.map((e) {
        if (e.id == id) {
          return e.copyWith(position: position, size: size, content: content);
        }
        return e;
      }).toList(),
    );
  }

  void removeElement(String id) {
    state = state.copyWith(
      floatingElements: state.floatingElements.where((e) => e.id != id).toList(),
    );
  }

  void setSymbolSize(int level) {
    state = state.copyWith(symbolSizeLevel: level.clamp(-2, 2));
  }

  void insertText(String text) {
    final controller = state.activeController;
    if (controller == null) return;

    // Handle space/newline to exit power mode
    if (text == ' ' || text == '\n') {
      state = state.copyWith(isPowerMode: false);
    }

    if (controller is TextEditingController || controller is quill.QuillController) {
      // Map TeX to Unicode for standard text fields (No \commands allowed here)
      String textToInsert = text;
      
      // Map Geometry TeX to Unicode equivalents for text fields
      final geometryMap = {
        r'\triangle': '△',
        r'\bigcirc': '○',
        r'\square': '□',
        r'\text{Rect}': '▭',
        r'\Diamond': '◊',
        r'\text{Paral}': '▱',
        r'\text{Trap}': '⏢',
        r'\angle': '∠',
        r'm\angle': 'm∠',
        r'\cong': '≅',
        r'\sim': '∼',
        r'\perp': '⊥',
        r'\parallel': '∥',
        r'^{\circ}': '°',
        r'\overline{AB}': 'AB̅',
        r'\vec{v}': 'v⃗',
        r'\text{Graph}': '[Graph]',
        r'\triangle_{A B C}': '△ABC',
      };

      if (geometryMap.containsKey(text)) {
        textToInsert = geometryMap[text]!;
      } else if (state.isPowerMode && (text.length == 1 || text == r'\pi' || text == 'e')) {
        // ... (existing power mode logic)
        final rawChar = text == r'\pi' ? 'π' : text;
        const superscripts = {'0':'⁰','1':'¹','2':'²','3':'³','4':'⁴','5':'⁵','6':'⁶','7':'⁷','8':'⁸','9':'⁹','n':'ⁿ','x':'ˣ','y':'ʸ','z':'ᶻ','a':'ᵃ','b':'ᵇ','c':'ᶜ','i':'ⁱ','π':'ᶲ'};
        textToInsert = superscripts[rawChar] ?? '^$rawChar';
      } else {
        final symbol = mathSymbols.firstWhere((s) => s.tex == text, orElse: () => MathSymbol(label: text, tex: text, category: MathCategory.misc));
        if (symbol.label.length == 1 || symbol.category == MathCategory.greek || symbol.category == MathCategory.operators) {
          textToInsert = symbol.label;
        }

        final functions = [r'\sin', r'\cos', r'\tan', r'\csc', r'\sec', r'\cot', r'\log', r'\ln', r'\arcsin', r'\arccos', r'\arctan', r'\sinh', r'\cosh', r'\tanh'];
        if (functions.contains(text)) {
          textToInsert = '${textToInsert.replaceAll('\\', '')}()';
        } else if (text.endsWith(r'\theta') && text.length > 7) {
          final func = text.split(' ').first.replaceAll('\\', '');
          textToInsert = '$func(θ)';
        } else if (text == r'\frac{d}{dx}') {
          textToInsert = 'd/dx';
        } else if (text == r'\frac{dy}{dx}') {
          textToInsert = 'dy/dx';
        } else if (text == r'\frac{d^2}{dx^2}') {
          textToInsert = 'd²/dx²';
        } else if (text == r'\lim_{x \to \infty}') {
          textToInsert = 'lim x→∞';
        } else if (text == r'\int_{}^{}^{}') {
          textToInsert = '∫';
        }
      }

      // DO NOT wrap in \large for standard text fields, it just shows as text
      // Instead, we use the character as-is. Standard fields don't support TeX sizing.
      
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
      } else if (text == r'\frac{d}{dx}') {
        controller.addFunction(r'\frac', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
        controller.addLeaf('d');
        controller.goNext();
        controller.addLeaf('d');
        controller.addLeaf('x');
        controller.goNext();
      } else if (text == r'\frac{dy}{dx}') {
        controller.addFunction(r'\frac', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
        controller.addLeaf('d');
        controller.addLeaf('y');
        controller.goNext();
        controller.addLeaf('d');
        controller.addLeaf('x');
        controller.goNext();
      } else if (text == r'\frac{d^2}{dx^2}') {
        controller.addFunction(r'\frac', [math_kb_node.TeXArg.braces, math_kb_node.TeXArg.braces]);
        controller.addLeaf('d');
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('2');
        controller.goNext();
        controller.goNext();
        controller.addLeaf('d');
        controller.addLeaf('x');
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('2');
        controller.goNext();
        controller.goNext();
      } else if (text == r'\lim_{x \to \infty}') {
        controller.addLeaf(r'\lim');
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('x');
        controller.addLeaf(r'\to');
        controller.addLeaf(r'\infty');
        controller.goNext();
      } else if (text == r'\int_{}^{}^{}') {
        controller.addLeaf(r'\int');
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
        // Cursor stays in subscript for user to fill lower bound
      } else if (text == r'\triangle_{A B C}') {
        controller.addLeaf(r'\triangle');
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
        // Allow teacher to type labels like ABC
      } else if (text == r'\overline{AB}') {
        controller.addFunction(r'\overline', [math_kb_node.TeXArg.braces]);
      } else if (text == r'\vec{v}') {
        controller.addFunction(r'\vec', [math_kb_node.TeXArg.braces]);
      } else if (text == r'\text{Graph}') {
        controller.addLeaf(r'\text{Graph Frame}');
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
      } else if (text == r'\triangle_{A B C}') {
        controller.addLeaf(r'\triangle');
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
        // Allow teacher to type labels like ABC
      } else if (text == r'\overline{AB}') {
        controller.addFunction(r'\overline', [math_kb_node.TeXArg.braces]);
      } else if (text == r'\vec{v}') {
        controller.addFunction(r'\vec', [math_kb_node.TeXArg.braces]);
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
          // Check for size prefix if geometry category and math field
          if (state.currentCategory == MathCategory.geometry && state.symbolSizeLevel != 0 && text.startsWith('\\')) {
            final sizeMap = { -2: r'\tiny', -1: r'\small', 1: r'\large', 2: r'\Large' };
            final prefix = sizeMap[state.symbolSizeLevel] ?? '';
            controller.addLeaf(prefix);
            controller.addLeaf(' ');
            controller.addLeaf(text);
          } else {
            controller.addLeaf(text);
          }
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
