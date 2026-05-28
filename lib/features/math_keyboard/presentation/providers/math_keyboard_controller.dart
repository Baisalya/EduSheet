import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
// ignore: implementation_imports
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

  FloatingElement copyWith({Offset? position, Size? size, String? content}) {
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
  final dynamic
  activeController; // Can be TextEditingController or QuillController
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
    bool clearActiveController = false,
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
      activeController: clearActiveController
          ? null
          : (activeController ?? this.activeController),
      activeFocusNode: clearActiveFocusNode
          ? null
          : (activeFocusNode ?? this.activeFocusNode),
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
    state = state.copyWith(
      activeController: controller,
      activeFocusNode: focusNode,
    );
  }

  void unregisterController(dynamic controller) {
    if (state.activeController == controller) {
      state = state.copyWith(
        clearActiveController: true,
        clearActiveFocusNode: true,
        isVisible: false,
      );
    }
  }

  void showMathKeyboard() {
    state = state.copyWith(isVisible: true, type: KeyboardType.math);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void showSystemKeyboard() {
    state = state.copyWith(isVisible: false, type: KeyboardType.system);
    // The UI (MathKeyboardField) will handle calling TextInput.show after a frame
    final node = state.activeFocusNode;
    if (node != null && node.canRequestFocus && node.context != null) {
      node.requestFocus();
    }
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
      size: type == FloatingElementType.textBox
          ? const Size(150, 60)
          : const Size(80, 80),
    );
    state = state.copyWith(
      floatingElements: [...state.floatingElements, newElement],
    );
  }

  void updateElement(
    String id, {
    Offset? position,
    Size? size,
    String? content,
  }) {
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
      floatingElements: state.floatingElements
          .where((e) => e.id != id)
          .toList(),
    );
  }

  void setSymbolSize(int level) {
    state = state.copyWith(symbolSizeLevel: level.clamp(-2, 2));
  }

  void moveCursorLeft() {
    final controller = state.activeController;
    if (controller is math_kb.MathFieldEditingController) {
      controller.goBack();
    } else if (controller is TextEditingController) {
      final selection = controller.selection;
      if (selection.start > 0) {
        controller.selection = TextSelection.collapsed(
          offset: selection.start - 1,
        );
      }
    } else if (controller is quill.QuillController) {
      final index = controller.selection.baseOffset;
      if (index > 0) {
        controller.updateSelection(
          TextSelection.collapsed(offset: index - 1),
          quill.ChangeSource.local,
        );
      }
    }
  }

  void moveCursorRight() {
    final controller = state.activeController;
    if (controller is math_kb.MathFieldEditingController) {
      controller.goNext();
    } else if (controller is TextEditingController) {
      final selection = controller.selection;
      if (selection.end < controller.text.length) {
        controller.selection = TextSelection.collapsed(
          offset: selection.end + 1,
        );
      }
    } else if (controller is quill.QuillController) {
      final index = controller.selection.baseOffset;
      if (index < controller.document.length - 1) {
        controller.updateSelection(
          TextSelection.collapsed(offset: index + 1),
          quill.ChangeSource.local,
        );
      }
    }
  }

  void nextField() {
    final controller = state.activeController;
    if (controller is math_kb.MathFieldEditingController) {
      controller.goNext();
    } else {
      // For standard fields, tab to next focusable if possible, or just space
      insertText(' ');
    }
  }

  void insertText(String text) {
    final controller = state.activeController;
    if (controller == null) return;

    // Handle space/newline to exit power mode
    if (text == ' ' || text == '\n') {
      state = state.copyWith(isPowerMode: false);
    }

    // Determine the text to insert, potentially with sizing prefix
    String textToInsert = text;
    if (state.symbolSizeLevel != 0 && text.startsWith('\\')) {
      final sizeMap = {-2: r'\tiny', -1: r'\small', 1: r'\large', 2: r'\Large'};
      final prefix = sizeMap[state.symbolSizeLevel] ?? '';
      textToInsert = '$prefix $text';
    }

    if (controller is TextEditingController ||
        controller is quill.QuillController) {
      // For standard text fields, map structural LaTeX to clean Unicode/text
      final textMapping = {
        r'\sqrt{}': '√()',
        r'\sqrt[3]{}': '∛()',
        r'\sqrt[]{}': 'ⁿ√()',
        r'\frac{}{}': '()⁄()',
        r'\frac{1}{2}': '½',
        r'\frac{1}{3}': '⅓',
        r'\frac{2}{3}': '⅔',
        r'\int_{}^{}^{}': '∫',
        r'\int_{}^{}': '∫ₐᵇ',
        r'\int': '∫',
        r'\iint': '∬',
        r'\iiint': '∭',
        r'\oint': '∮',
        r'\sum_{}^{}^{}': '∑',
        r'\sum_{}^{}': '∑ₙ',
        r'\sum': '∑',
        r'\prod_{}^{}^{}': '∏',
        r'\prod_{}^{}': '∏ₙ',
        r'\prod': '∏',
        r'\log_{}(': 'logₐ()',
        r'\log_{}': 'logₐ()',
        r'\ln': 'ln()',
        r'|{}|': '||',
        r'^{}': '^',
        r'_{}': '_',
        r'^{2}': '²',
        r'^{3}': '³',
        r'e^{}': 'e^',
        r'\frac{d}{dx}': 'd/dx',
        r'\frac{dy}{dx}': 'dy/dx',
        r'\frac{d^2}{dx^2}': 'd²/dx²',
        r'\lim_{x \to \infty}': 'lim x→∞',
        r'\triangle_{A B C}': '△ABC',
        r'\overline{AB}': 'AB̅',
        r'\vec{v}': 'v⃗',
        r'\overset{\frown}{AB}': 'arc AB',
        r'\text{cm}^{2}': 'cm²',
        r'\text{cm}^{3}': 'cm³',
        r'\begin{pmatrix}  & \\  & \end{pmatrix}': '[2×2 matrix]',
        r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}':
            '[3×3 matrix]',
        r'\begin{vmatrix}  & \\  & \end{vmatrix}': '|A|',
        r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}': 'x = (-b ± √(b² - 4ac))⁄2a',
        r'a^2 + b^2 = c^2': 'a² + b² = c²',
        r'(x-h)^2 + (y-k)^2 = r^2': '(x-h)² + (y-k)² = r²',
        r'y = mx + c': 'y = mx + c',
        r'm = \frac{y_2-y_1}{x_2-x_1}': 'm = (y₂-y₁)⁄(x₂-x₁)',
        r'd = \sqrt{(x_2-x_1)^2 + (y_2-y_1)^2}': 'd = √((x₂-x₁)² + (y₂-y₁)²)',
        r'a_n = a + (n-1)d': 'aₙ = a + (n-1)d',
        r'S_n = \frac{n}{2}[2a+(n-1)d]': 'Sₙ = n⁄2[2a+(n-1)d]',
        r'a_n = ar^{n-1}': 'aₙ = arⁿ⁻¹',
        r'\bar{x} = \frac{\sum x}{n}': 'x̄ = ∑x⁄n',
        r'P(E)=\frac{\text{Favourable outcomes}}{\text{Total outcomes}}':
            'P(E)= favourable outcomes⁄total outcomes',
        r'A=\pi r^2': 'A = πr²',
        r'V=\frac{4}{3}\pi r^3': 'V = ⁴⁄₃πr³',
        r'\text{Solve: }': 'Solve: ',
        r'\text{Prove that }': 'Prove that ',
        r'\text{Find the value of } x': 'Find the value of x',
        r'\sin': 'sin()',
        r'\cos': 'cos()',
        r'\tan': 'tan()',
        r'\csc': 'csc()',
        r'\sec': 'sec()',
        r'\cot': 'cot()',
        r'\sin^2 \theta': 'sin²θ',
        r'\cos^2 \theta': 'cos²θ',
        r'\tan \theta': 'tanθ',
        r'\arcsin': 'arcsin()',
        r'\arccos': 'arccos()',
        r'\arctan': 'arctan()',
        r'\sinh': 'sinh()',
        r'\cosh': 'cosh()',
        r'\tanh': 'tanh()',
        r'\langle\rangle': '⟨⟩',
        r'\lfloor\rfloor': '⌊⌋',
        r'\lceil\rceil': '⌈⌉',
        r'\theta': 'θ',
        r'\phi': 'φ',
        r'\alpha': 'α',
        r'\beta': 'β',
        r'\gamma': 'γ',
        r'\delta': 'δ',
        r'\epsilon': 'ε',
        r'\pi': 'π',
        r'\permil': '‰',
        r'\text{₹}': '₹',
        '(': '()',
        '[': '[]',
        '{': '{}',
      };

      if (textMapping.containsKey(text)) {
        textToInsert = textMapping[text]!;
      } else if (state.isPowerMode &&
          (text.length == 1 || text == r'\pi' || text == 'e')) {
        // ... (rest of power mode logic remains the same)
        final rawChar = text == r'\pi' ? 'π' : text;
        const superscripts = {
          '0': '⁰',
          '1': '¹',
          '2': '²',
          '3': '³',
          '4': '⁴',
          '5': '⁵',
          '6': '⁶',
          '7': '⁷',
          '8': '⁸',
          '9': '⁹',
          '+': '⁺',
          '-': '⁻',
          '=': '⁼',
          '(': '⁽',
          ')': '⁾',
          'n': 'ⁿ',
          'x': 'ˣ',
          'y': 'ʸ',
          'z': 'ᶻ',
          'a': 'ᵃ',
          'b': 'ᵇ',
          'c': 'ᶜ',
          'i': 'ⁱ',
          'π': 'ᵖ',
        };
        textToInsert = superscripts[rawChar] ?? '^$rawChar';
      } else {
        // General cleanup for other LaTeX commands in standard fields
        final symbol = mathSymbols.firstWhere(
          (s) => s.tex == text,
          orElse: () =>
              MathSymbol(label: text, tex: text, category: MathCategory.misc),
        );

        if (symbol.label.length == 1 ||
            symbol.category == MathCategory.greek ||
            symbol.category == MathCategory.operators) {
          textToInsert = symbol.label;
        } else if (text.startsWith('\\')) {
          // If it's a command we don't know, just show the label or strip the backslash
          textToInsert = symbol.label;
        }
      }

      if (controller is TextEditingController) {
        final selection = controller.selection;
        final currentText = controller.text;
        final start = selection.start != -1
            ? selection.start
            : currentText.length;
        final end = selection.end != -1 ? selection.end : currentText.length;

        final newText = currentText.replaceRange(start, end, textToInsert);

        // Smart cursor placement for auto-closing pairs
        int newCursorPos = start + textToInsert.length;
        if ([
          '()',
          '[]',
          '{}',
          '||',
          '√()',
          '∛()',
          'ⁿ√()',
          'sin()',
          'cos()',
          'tan()',
          'logₐ()',
          'ln()',
        ].contains(textToInsert)) {
          newCursorPos -= 1;
        } else if (textToInsert == '()⁄()') {
          newCursorPos = start + 1;
        } else if ([
          'arcsin()',
          'arccos()',
          'arctan()',
          'sinh()',
          'cosh()',
          'tanh()',
        ].contains(textToInsert)) {
          newCursorPos -= 1;
        }

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPos),
        );
      } else if (controller is quill.QuillController) {
        final index = controller.selection.baseOffset;
        final length = controller.selection.extentOffset - index;

        controller.replaceText(index, length, textToInsert, null);

        int offset = textToInsert.length;
        if ([
          '()',
          '[]',
          '{}',
          '||',
          '√()',
          '∛()',
          'ⁿ√()',
          'sin()',
          'cos()',
          'tan()',
          'logₐ()',
          'ln()',
        ].contains(textToInsert)) {
          offset -= 1;
        } else if (textToInsert == '()⁄()') {
          offset = 1;
        } else if ([
          'arcsin()',
          'arccos()',
          'arctan()',
          'sinh()',
          'cosh()',
          'tanh()',
        ].contains(textToInsert)) {
          offset -= 1;
        }

        controller.updateSelection(
          TextSelection.collapsed(offset: index + offset),
          quill.ChangeSource.local,
        );
      }
    } else if (controller is math_kb.MathFieldEditingController) {
      final functionsWithBraces = [
        r'\sin',
        r'\cos',
        r'\tan',
        r'\csc',
        r'\sec',
        r'\cot',
        r'\log',
        r'\ln',
        r'\arcsin',
        r'\arccos',
        r'\arctan',
        r'\sinh',
        r'\cosh',
        r'\tanh',
      ];

      void addFraction(String numerator, String denominator) {
        controller.addFunction(r'\frac', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
        for (final char in numerator.split('')) {
          controller.addLeaf(char);
        }
        controller.goNext();
        for (final char in denominator.split('')) {
          controller.addLeaf(char);
        }
        controller.goNext();
      }

      if (text == r'\frac{1}{2}') {
        addFraction('1', '2');
      } else if (text == r'\frac{1}{3}') {
        addFraction('1', '3');
      } else if (text == r'\frac{2}{3}') {
        addFraction('2', '3');
      } else if (text == r'\frac{d}{dx}') {
        addFraction('d', 'dx');
      } else if (text == r'\frac{dy}{dx}') {
        addFraction('dy', 'dx');
      } else if (text == r'\frac{d^2}{dx^2}') {
        controller.addFunction(r'\frac', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
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
        controller.addFunction(r'\sqrt', [
          math_kb_node.TeXArg.brackets,
          math_kb_node.TeXArg.braces,
        ]);
        controller.addLeaf('3');
        controller.goNext();
      } else if (text == r'\sqrt[]{}') {
        controller.addFunction(r'\sqrt', [
          math_kb_node.TeXArg.brackets,
          math_kb_node.TeXArg.braces,
        ]);
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
        controller.addFunction(r'\int', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
      } else if (text == r'\sum_{}^{}') {
        controller.addFunction(r'\sum', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
      } else if (text == r'\prod_{}^{}') {
        controller.addFunction(r'\prod', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
      } else if (text == r'\log_{}') {
        controller.addLeaf(r'\log');
        controller.addFunction('_', [math_kb_node.TeXArg.braces]);
        controller.addLeaf('a');
        controller.goNext();
        controller.addLeaf('(');
        controller.addLeaf(')');
        controller.goBack();
      } else if (text == r'e^{}') {
        controller.addLeaf('e');
        controller.addFunction('^', [math_kb_node.TeXArg.braces]);
      } else if (text == r'|{}|') {
        controller.addLeaf('|');
        controller.addLeaf('|');
        controller.goBack(); // Move cursor inside
      } else if (text == '(') {
        controller.addLeaf('(');
        controller.addLeaf(')');
        controller.goBack();
      } else if (text == '[') {
        controller.addLeaf('[');
        controller.addLeaf(']');
        controller.goBack();
      } else if (text == '{') {
        controller.addLeaf('{');
        controller.addLeaf('}');
        controller.goBack();
      } else if (text == r'\langle\rangle') {
        controller.addLeaf(r'\langle');
        controller.addLeaf(r'\rangle');
        controller.goBack();
      } else if (text == r'\lfloor\rfloor') {
        controller.addLeaf(r'\lfloor');
        controller.addLeaf(r'\rfloor');
        controller.goBack();
      } else if (text == r'\lceil\rceil') {
        controller.addLeaf(r'\lceil');
        controller.addLeaf(r'\rceil');
        controller.goBack();
      } else if (text == r'\frac{}{}') {
        controller.addFunction(r'\frac', [
          math_kb_node.TeXArg.braces,
          math_kb_node.TeXArg.braces,
        ]);
      } else {
        if (state.isPowerMode && text.length == 1) {
          controller.addFunction('^', [math_kb_node.TeXArg.braces]);
          controller.addLeaf(text);
          controller.goNext();
        } else {
          // General insertion with sizing
          if (state.symbolSizeLevel != 0 && text.startsWith('\\')) {
            final sizeMap = {
              -2: r'\tiny',
              -1: r'\small',
              1: r'\large',
              2: r'\Large',
            };
            final prefix = sizeMap[state.symbolSizeLevel] ?? '';
            controller.addLeaf(prefix);
            controller.addLeaf(' ');
          }
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
        final newText = currentText.replaceRange(
          selection.start - 1,
          selection.start,
          '',
        );
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start - 1),
        );
      } else if (selection.start != selection.end) {
        final currentText = controller.text;
        final newText = currentText.replaceRange(
          selection.start,
          selection.end,
          '',
        );
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
