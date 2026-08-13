import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
// The package currently exposes TeXArg only through its implementation layer.
// Keep that dependency isolated here rather than leaking it into controllers/UI.
// ignore: implementation_imports
import 'package:math_keyboard/src/foundation/node.dart' as math_kb_node;

import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_plain_text_serializer.dart';

class MathInsertionContext {
  final bool powerMode;
  final bool subscriptMode;
  final int symbolSizeLevel;

  const MathInsertionContext({
    required this.powerMode,
    required this.subscriptMode,
    required this.symbolSizeLevel,
  });
}

abstract class MathEditorAdapter {
  void insert(String source, MathInsertionContext context);
  void moveLeft();
  void moveRight();
  void deleteBackward();
  void clear();

  /// Returns true when the editor handled structured-slot navigation itself.
  bool moveToNextSlot() => false;
}

class MathEditorAdapterFactory {
  const MathEditorAdapterFactory._();

  static MathEditorAdapter? forController(Object? controller) {
    if (controller is TextEditingController) {
      return TextFieldMathEditorAdapter(controller);
    }
    if (controller is quill.QuillController) {
      return QuillMathEditorAdapter(controller);
    }
    if (controller is math_kb.MathFieldEditingController) {
      return MathFieldEditorAdapter(controller);
    }
    return null;
  }
}

class TextFieldMathEditorAdapter extends MathEditorAdapter {
  final TextEditingController controller;
  final MathPlainTextSerializer serializer;

  TextFieldMathEditorAdapter(
    this.controller, {
    this.serializer = const MathPlainTextSerializer(),
  });

  @override
  void insert(String source, MathInsertionContext context) {
    final insertion = serializer.serialize(
      source,
      powerMode: context.powerMode,
      subscriptMode: context.subscriptMode,
    );
    final selection = controller.selection;
    final currentText = controller.text;
    final start = selection.start >= 0 ? selection.start : currentText.length;
    final end = selection.end >= 0 ? selection.end : currentText.length;
    final safeStart = start.clamp(0, currentText.length);
    final safeEnd = end.clamp(0, currentText.length);
    final rangeStart = safeStart <= safeEnd ? safeStart : safeEnd;
    final rangeEnd = safeStart <= safeEnd ? safeEnd : safeStart;
    final newText = currentText.replaceRange(
      rangeStart,
      rangeEnd,
      insertion.text,
    );
    final cursor = (rangeStart + insertion.cursorOffset).clamp(
      0,
      newText.length,
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  @override
  void moveLeft() {
    final selection = controller.selection;
    if (selection.start > 0) {
      controller.selection = TextSelection.collapsed(
        offset: selection.start - 1,
      );
    }
  }

  @override
  void moveRight() {
    final selection = controller.selection;
    if (selection.end < controller.text.length) {
      controller.selection = TextSelection.collapsed(offset: selection.end + 1);
    }
  }

  @override
  void deleteBackward() {
    final selection = controller.selection;
    if (selection.start < 0 || selection.end < 0) return;

    final currentText = controller.text;
    if (selection.start == selection.end && selection.start > 0) {
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
      final start = selection.start < selection.end
          ? selection.start
          : selection.end;
      final end = selection.start < selection.end
          ? selection.end
          : selection.start;
      final newText = currentText.replaceRange(start, end, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    }
  }

  @override
  void clear() => controller.clear();
}

class QuillMathEditorAdapter extends MathEditorAdapter {
  final quill.QuillController controller;
  final MathPlainTextSerializer serializer;

  QuillMathEditorAdapter(
    this.controller, {
    this.serializer = const MathPlainTextSerializer(),
  });

  @override
  void insert(String source, MathInsertionContext context) {
    if (_isGeometryToken(source)) {
      _insertGeometry(source);
      return;
    }

    final insertion = serializer.serialize(
      source,
      powerMode: context.powerMode,
      subscriptMode: context.subscriptMode,
    );
    final docEnd = (controller.document.length - 1).clamp(0, 1 << 30);
    final base = controller.selection.baseOffset;
    final extent = controller.selection.extentOffset;
    final safeBase = base < 0 ? docEnd : base.clamp(0, docEnd);
    final safeExtent = extent < 0 ? safeBase : extent.clamp(0, docEnd);
    final index = safeBase <= safeExtent ? safeBase : safeExtent;
    final length = (safeBase - safeExtent).abs();

    controller.replaceText(index, length, insertion.text, null);
    final newDocEnd = (controller.document.length - 1).clamp(0, 1 << 30);
    controller.updateSelection(
      TextSelection.collapsed(
        offset: (index + insertion.cursorOffset).clamp(0, newDocEnd),
      ),
      quill.ChangeSource.local,
    );
  }

  bool _isGeometryToken(String source) =>
      source.startsWith('{{geometry:') && source.endsWith('}}');

  void _insertGeometry(String source) {
    final id = source.substring(11, source.length - 2);
    final docEnd = (controller.document.length - 1).clamp(0, 1 << 30);
    final base = controller.selection.baseOffset;
    final extent = controller.selection.extentOffset;
    final safeBase = base < 0 ? docEnd : base.clamp(0, docEnd);
    final safeExtent = extent < 0 ? safeBase : extent.clamp(0, docEnd);
    final index = safeBase <= safeExtent ? safeBase : safeExtent;
    final length = (safeBase - safeExtent).abs();
    final diagram = GeometryDiagramRegistry.instance.diagramFor(id);
    final data = jsonEncode(<String, Object?>{
      'id': id,
      'height': 200.0,
      'widthFactor': 1.0,
      'alignmentX': 0.0,
      if (diagram != null) 'diagram': diagram.toJson(),
    });

    controller.replaceText(
      index,
      length,
      quill.BlockEmbed.custom(quill.CustomBlockEmbed('geometry', data)),
      null,
    );
  }

  @override
  void moveLeft() {
    final index = controller.selection.baseOffset;
    if (index > 0) {
      controller.updateSelection(
        TextSelection.collapsed(offset: index - 1),
        quill.ChangeSource.local,
      );
    }
  }

  @override
  void moveRight() {
    final index = controller.selection.baseOffset;
    if (index < controller.document.length - 1) {
      controller.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        quill.ChangeSource.local,
      );
    }
  }

  @override
  void deleteBackward() {
    final base = controller.selection.baseOffset;
    final extent = controller.selection.extentOffset;
    if (base < 0 || extent < 0) return;

    final start = base <= extent ? base : extent;
    final length = (base - extent).abs();
    if (length > 0) {
      controller.replaceText(start, length, '', null);
    } else if (start > 0) {
      controller.replaceText(start - 1, 1, '', null);
      controller.updateSelection(
        TextSelection.collapsed(offset: start - 1),
        quill.ChangeSource.local,
      );
    }
  }

  @override
  void clear() => controller.clear();
}

class MathFieldEditorAdapter extends MathEditorAdapter {
  final math_kb.MathFieldEditingController controller;

  MathFieldEditorAdapter(this.controller);

  @override
  void insert(String source, MathInsertionContext context) {
    const functionsWithBraces = <String>[
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

    if (source == r'\frac{1}{2}') {
      _addFraction('1', '2');
    } else if (source == r'\frac{1}{3}') {
      _addFraction('1', '3');
    } else if (source == r'\frac{2}{3}') {
      _addFraction('2', '3');
    } else if (source == r'\frac{d}{dx}') {
      _addFraction('d', 'dx');
    } else if (source == r'\frac{dy}{dx}') {
      _addFraction('dy', 'dx');
    } else if (source == r'\frac{d^2}{dx^2}') {
      _addSecondDerivative();
    } else if (source == r'\lim_{x \to \infty}') {
      controller.addLeaf(r'\lim');
      controller.addFunction('_', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
      ]);
      controller.addLeaf('x');
      controller.addLeaf(r'\to');
      controller.addLeaf(r'\infty');
      controller.goNext();
    } else if (source == r'\int_{}^{}' || source == r'\int_{}^{}^{}') {
      _addLimits(r'\int');
    } else if (source == r'\sum_{}^{}' || source == r'\sum_{}^{}^{}') {
      _addLimits(r'\sum');
    } else if (source == r'\prod_{}^{}' || source == r'\prod_{}^{}^{}') {
      _addLimits(r'\prod');
    } else if (source == r'\triangle_{A B C}') {
      controller.addLeaf(r'\triangle');
      controller.addFunction('_', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
      ]);
    } else if (source == r'\overline{AB}') {
      _addSingleArgumentFunction(r'\overline');
    } else if (source == r'\overrightarrow{AB}') {
      _addSingleArgumentFunction(r'\overrightarrow');
    } else if (source == r'\overleftrightarrow{AB}') {
      _addSingleArgumentFunction(r'\overleftrightarrow');
    } else if (source == r'\widehat{AB}') {
      _addSingleArgumentFunction(r'\widehat');
    } else if (source == r'\bar{x}') {
      _addSingleArgumentFunction(r'\bar');
    } else if (source == r'\vec{v}' || source == r'\vec{F}') {
      _addSingleArgumentFunction(r'\vec');
    } else if (source == r'\text{Graph}') {
      controller.addLeaf(r'\text{Graph Frame}');
    } else if (functionsWithBraces.contains(source)) {
      controller.addLeaf(source);
      controller.addLeaf('(');
      controller.addLeaf(')');
      controller.goBack();
    } else if (source.endsWith(r'\theta') && source.length > 7) {
      final function = source.split(' ').first;
      controller.addLeaf(function);
      controller.addLeaf('(');
      controller.addLeaf(r'\theta');
      controller.addLeaf(')');
    } else if (source == r'\sqrt{}') {
      _addSingleArgumentFunction(r'\sqrt');
    } else if (source == r'\sqrt[3]{}') {
      controller.addFunction(r'\sqrt', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.brackets,
        math_kb_node.TeXArg.braces,
      ]);
      controller.addLeaf('3');
      controller.goNext();
    } else if (source == r'\sqrt[]{}') {
      controller.addFunction(r'\sqrt', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.brackets,
        math_kb_node.TeXArg.braces,
      ]);
    } else if (source == r'^{}') {
      _addSingleArgumentFunction('^');
    } else if (source == r'^{2}') {
      _addPower('2');
    } else if (source == r'^{3}') {
      _addPower('3');
    } else if (source == r'_{}') {
      _addSingleArgumentFunction('_');
    } else if (source.startsWith('^{') && source.endsWith('}')) {
      _addPower(source.substring(2, source.length - 1));
    } else if (source == r'\int') {
      controller.addLeaf(r'\int');
    } else if (source == r'\sum') {
      controller.addLeaf(r'\sum');
    } else if (source == r'\prod') {
      controller.addLeaf(r'\prod');
    } else if (source == r'\log_{}') {
      controller.addLeaf(r'\log');
      controller.addFunction('_', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
      ]);
      controller.addLeaf('a');
      controller.goNext();
      controller.addLeaf('(');
      controller.addLeaf(')');
      controller.goBack();
    } else if (source == r'e^{}') {
      controller.addLeaf('e');
      _addSingleArgumentFunction('^');
    } else if (source == r'|{}|') {
      _addPair('|', '|');
    } else if (source == '(') {
      _addPair('(', ')');
    } else if (source == '[') {
      _addPair('[', ']');
    } else if (source == '{') {
      _addPair('{', '}');
    } else if (source == r'\langle\rangle') {
      _addPair(r'\langle', r'\rangle');
    } else if (source == r'\lfloor\rfloor') {
      _addPair(r'\lfloor', r'\rfloor');
    } else if (source == r'\lceil\rceil') {
      _addPair(r'\lceil', r'\rceil');
    } else if (source == r'\frac{}{}') {
      controller.addFunction(r'\frac', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
        math_kb_node.TeXArg.braces,
      ]);
    } else if (context.powerMode &&
        (source.length == 1 || source == r'\pi' || source == 'e')) {
      _addSingleArgumentFunction('^');
      controller.addLeaf(source);
      controller.goNext();
    } else if (context.subscriptMode &&
        (source.length == 1 || source == r'\pi' || source == 'e')) {
      _addSingleArgumentFunction('_');
      controller.addLeaf(source);
      controller.goNext();
    } else {
      if (context.symbolSizeLevel != 0 && source.startsWith('\\')) {
        const sizeMap = <int, String>{
          -2: r'\tiny',
          -1: r'\small',
          1: r'\large',
          2: r'\Large',
        };
        final prefix = sizeMap[context.symbolSizeLevel] ?? '';
        controller.addLeaf(prefix);
        controller.addLeaf(' ');
      }
      controller.addLeaf(source);
    }
  }

  void _addFraction(String numerator, String denominator) {
    controller.addFunction(r'\frac', <math_kb_node.TeXArg>[
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

  void _addSecondDerivative() {
    controller.addFunction(r'\frac', <math_kb_node.TeXArg>[
      math_kb_node.TeXArg.braces,
      math_kb_node.TeXArg.braces,
    ]);
    controller.addLeaf('d');
    _addSingleArgumentFunction('^');
    controller.addLeaf('2');
    controller.goNext();
    controller.goNext();
    controller.addLeaf('d');
    controller.addLeaf('x');
    _addSingleArgumentFunction('^');
    controller.addLeaf('2');
    controller.goNext();
    controller.goNext();
  }

  void _addLimits(String base) {
    controller.addLeaf(base);
    controller.addFunction('_', <math_kb_node.TeXArg>[
      math_kb_node.TeXArg.braces,
    ]);
    controller.goNext();
    controller.addFunction('^', <math_kb_node.TeXArg>[
      math_kb_node.TeXArg.braces,
    ]);
    controller.goBack();
    controller.goBack();
  }

  void _addSingleArgumentFunction(String function) {
    controller.addFunction(function, <math_kb_node.TeXArg>[
      math_kb_node.TeXArg.braces,
    ]);
  }

  void _addPower(String content) {
    _addSingleArgumentFunction('^');
    for (final char in content.split('')) {
      controller.addLeaf(char);
    }
    if (content.isNotEmpty) controller.goNext();
  }

  void _addPair(String left, String right) {
    controller.addLeaf(left);
    controller.addLeaf(right);
    controller.goBack();
  }

  @override
  void moveLeft() => controller.goBack();

  @override
  void moveRight() => controller.goNext();

  @override
  void deleteBackward() => controller.goBack(deleteMode: true);

  @override
  void clear() {
    // The currently authorized math_keyboard API does not expose a clear-all
    // operation. Preserve the previous no-op rather than guessing private state.
  }

  @override
  bool moveToNextSlot() {
    controller.goNext();
    return true;
  }
}
