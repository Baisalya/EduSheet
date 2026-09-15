import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:math_keyboard/math_keyboard.dart' as math_kb;
// The package currently exposes TeXArg only through its implementation layer.
// Keep that dependency isolated here rather than leaking it into controllers/UI.
// ignore: implementation_imports
import 'package:math_keyboard/src/foundation/node.dart' as math_kb_node;

import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import '../../domain/models/math_dynamic_structure.dart';
import '../../domain/models/math_edit_command.dart';
import '../../domain/models/math_symbol.dart';
import '../../domain/services/math_dynamic_structure_codec.dart';
import '../../domain/services/math_plain_text_serializer.dart';

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

  /// Typed catalogue insertion path. Non-visual editors intentionally keep
  /// using their existing plain-text serialization by default.
  void insertSymbol(MathSymbol symbol, MathInsertionContext context) =>
      insert(symbol.tex, context);

  /// Runtime-sized structures use the same adapter boundary as catalogue
  /// commands. Non-visual editors keep their existing serialization behavior.
  void insertDynamicStructure(
    MathDynamicStructureInstance instance,
    MathInsertionContext context,
  ) {
    final document = const MathDynamicStructureCodec().compile(instance);
    insert(document.tex, context);
  }

  void moveLeft();
  void moveRight();
  void deleteBackward();
  void clear();

  /// Returns true when the editor handled structured-slot navigation itself.
  bool moveToNextSlot() => false;

  /// Returns true when the editor handled reverse structured-slot navigation.
  bool moveToPreviousSlot() => false;
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

  /// Raw input is reserved for hardware characters, whitespace and other
  /// non-catalogue actions. Catalogue structures use [insertSymbol] so their
  /// editing semantics come from domain metadata rather than TeX matching.
  @override
  void insert(String source, MathInsertionContext context) {
    final dynamicStructure = const MathDynamicStructureCodec().tryParse(source);
    if (dynamicStructure != null) {
      _insertDynamicStructure(dynamicStructure);
      return;
    }

    final legacyCommand = MathLegacyEditCommandRegistry.bySource[source];
    if (legacyCommand != null) {
      _execute(legacyCommand);
      return;
    }
    if (_insertIntoActiveScriptMode(source, context)) return;
    _insertLeafWithSize(source, context.symbolSizeLevel);
  }

  @override
  void insertSymbol(MathSymbol symbol, MathInsertionContext context) {
    final command =
        symbol.editorCommand ??
        MathLegacyEditCommandRegistry.bySource[symbol.tex];
    if (command != null) {
      _execute(command);
      return;
    }

    final dynamicStructure = const MathDynamicStructureCodec().tryParse(
      symbol.tex,
    );
    if (dynamicStructure != null) {
      _insertDynamicStructure(dynamicStructure);
      return;
    }

    if (_insertIntoActiveScriptMode(symbol.tex, context)) return;
    _insertLeafWithSize(symbol.tex, context.symbolSizeLevel);
  }

  @override
  void insertDynamicStructure(
    MathDynamicStructureInstance instance,
    MathInsertionContext context,
  ) {
    _insertDynamicStructure(instance);
  }

  void _insertDynamicStructure(MathDynamicStructureInstance instance) {
    final document = const MathDynamicStructureCodec().compile(instance);
    final host = controller.currentNode;
    host.removeCursor();

    final structureKey = Object();
    _DynamicMathSlotFunction? firstSlot;
    for (var index = 0; index < document.tokens.length; index++) {
      final token = document.tokens[index];
      switch (token) {
        case MathDynamicLiteralToken(:final source):
          if (index == document.tokens.length - 1) {
            host.addTeX(
              _DynamicStructureEndLeaf(
                source: source,
                structureKey: structureKey,
              ),
            );
          } else {
            host.addTeX(math_kb_node.TeXLeaf(source));
          }
        case MathDynamicSlotToken(:final slot, :final initialValue):
          final function = _DynamicMathSlotFunction(
            parent: host,
            slot: slot,
            structureKey: structureKey,
            initialValue: initialValue,
          );
          host.addTeX(function);
          firstSlot ??= function;
      }
    }

    final first = firstSlot;
    if (first == null) {
      host.setCursor();
      controller.currentNode = host;
      _publishControllerMutation();
      return;
    }

    final slotNode = first.argNodes.single;
    slotNode.courserPosition = slotNode.children.length;
    slotNode.setCursor();
    controller.currentNode = slotNode;
    _publishControllerMutation();
  }

  /// Publishes a tree mutation without reaching into ChangeNotifier's
  /// protected `notifyListeners` API.
  ///
  /// The upstream controller exposes node mutation state publicly but does not
  /// expose a public refresh method. Adding and immediately deleting an empty
  /// leaf uses only its public editing API, emits the required change signal,
  /// preserves the serialized TeX value, and leaves no sentinel node behind.
  void _publishControllerMutation() {
    controller.addLeaf('');
    controller.goBack(deleteMode: true);
  }

  void _execute(MathEditCommand command) {
    for (final operation in command.operations) {
      switch (operation) {
        case MathInsertLeaf(:final source):
          controller.addLeaf(source);
        case MathInsertFunction(:final function, :final arguments):
          controller.addFunction(
            function,
            arguments.map(_toTeXArg).toList(growable: false),
          );
        case MathMoveSlot(:final direction, :final count):
          for (var i = 0; i < count; i++) {
            switch (direction) {
              case MathSlotMoveDirection.previous:
                controller.goBack();
              case MathSlotMoveDirection.next:
                controller.goNext();
            }
          }
        case MathInsertDynamicStructure(:final spec):
          _insertDynamicStructure(MathDynamicStructureInstance(spec: spec));
      }
    }
  }

  math_kb_node.TeXArg _toTeXArg(MathEditArgument argument) {
    switch (argument) {
      case MathEditArgument.braces:
        return math_kb_node.TeXArg.braces;
      case MathEditArgument.brackets:
        return math_kb_node.TeXArg.brackets;
    }
  }

  bool _insertIntoActiveScriptMode(
    String source,
    MathInsertionContext context,
  ) {
    final isScriptValue =
        source.length == 1 || source == r'\pi' || source == 'e';
    if (!isScriptValue) return false;

    if (context.powerMode) {
      controller.addFunction('^', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
      ]);
      controller.addLeaf(source);
      controller.goNext();
      return true;
    }

    if (context.subscriptMode) {
      controller.addFunction('_', <math_kb_node.TeXArg>[
        math_kb_node.TeXArg.braces,
      ]);
      controller.addLeaf(source);
      controller.goNext();
      return true;
    }

    return false;
  }

  void _insertLeafWithSize(String source, int symbolSizeLevel) {
    if (symbolSizeLevel != 0 && source.startsWith(r'\')) {
      const sizeMap = <int, String>{
        -2: r'\tiny',
        -1: r'\small',
        1: r'\large',
        2: r'\Large',
      };
      final prefix = sizeMap[symbolSizeLevel] ?? '';
      controller.addLeaf(prefix);
      controller.addLeaf(' ');
    }
    controller.addLeaf(source);
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
  bool moveToPreviousSlot() {
    if (_moveToPreviousDynamicSlot()) return true;
    if (_moveToPreviousFunctionArgument()) return true;
    if (_moveSeededDerivativeToNumerator()) return true;
    if (_moveUpperScriptToLowerScript()) return true;

    controller.goBack();
    return true;
  }

  @override
  bool moveToNextSlot() {
    if (_moveToNextDynamicSlot()) return true;

    // Some composer structures are represented by adjacent TeX functions
    // rather than multiple arguments of one function. `goNext()` is node-based,
    // so one call would stop between the semantic slots. Keep that package
    // detail isolated here and expose one logical Next-slot action to the UI.
    if (_isSeededDerivativeNumeratorSlot()) {
      controller.goNext(); // numerator -> start of denominator
      controller.goNext(); // skip the seeded denominator `d`
      return true;
    }

    if (_isLowerScriptFollowedByUpperScript()) {
      controller.goNext(); // lower-script arg -> parent node
      controller.goNext(); // parent node -> upper-script arg
      return true;
    }

    controller.goNext();
    return true;
  }

  bool _moveToPreviousDynamicSlot() {
    final slotNode = controller.currentNode;
    final slotFunction = slotNode.parent;
    if (slotFunction is! _DynamicMathSlotFunction) return false;

    final host = slotFunction.parent;
    final startIndex = host.children.indexOf(slotFunction);
    if (startIndex <= 0) return false;

    _DynamicMathSlotFunction? previousSlot;
    for (var index = startIndex - 1; index >= 0; index--) {
      final child = host.children[index];
      if (child is _DynamicMathSlotFunction &&
          identical(child.structureKey, slotFunction.structureKey)) {
        previousSlot = child;
        break;
      }
    }
    if (previousSlot == null) return false;

    slotNode.removeCursor();
    final previousNode = previousSlot.argNodes.single;
    previousNode.courserPosition = previousNode.children.length;
    previousNode.setCursor();
    controller.currentNode = previousNode;
    _publishControllerMutation();
    return true;
  }

  bool _moveToPreviousFunctionArgument() {
    final slotNode = controller.currentNode;
    final function = slotNode.parent;
    if (function is! math_kb_node.TeXFunction || function.argNodes.length < 2) {
      return false;
    }

    final slotIndex = function.argNodes.indexWhere(
      (arg) => identical(arg, slotNode),
    );
    if (slotIndex <= 0) return false;

    slotNode.removeCursor();
    final previousNode = function.argNodes[slotIndex - 1];
    previousNode.courserPosition = previousNode.children.length;
    previousNode.setCursor();
    controller.currentNode = previousNode;
    _publishControllerMutation();
    return true;
  }

  bool _moveSeededDerivativeToNumerator() {
    final node = controller.currentNode;
    final parent = node.parent;
    if (parent == null ||
        parent.expression != r'\frac' ||
        parent.argNodes.length != 2 ||
        !identical(parent.argNodes[1], node) ||
        _firstNonCursorExpression(parent.argNodes[0]) != 'd' ||
        _firstNonCursorExpression(parent.argNodes[1]) != 'd') {
      return false;
    }

    node.removeCursor();
    final previousNode = parent.argNodes[0];
    previousNode.courserPosition = previousNode.children.length;
    previousNode.setCursor();
    controller.currentNode = previousNode;
    _publishControllerMutation();
    return true;
  }

  bool _moveUpperScriptToLowerScript() {
    final slotNode = controller.currentNode;
    final upperScript = slotNode.parent;
    if (upperScript == null || !upperScript.expression.startsWith('^')) {
      return false;
    }

    final hostNode = upperScript.parent;
    final upperIndex = hostNode.children.indexOf(upperScript);
    if (upperIndex <= 0) return false;
    final previous = hostNode.children[upperIndex - 1];
    if (previous is! math_kb_node.TeXFunction || previous.expression != '_') {
      return false;
    }

    slotNode.removeCursor();
    final previousNode = previous.argNodes.single;
    previousNode.courserPosition = previousNode.children.length;
    previousNode.setCursor();
    controller.currentNode = previousNode;
    _publishControllerMutation();
    return true;
  }

  bool _moveToNextDynamicSlot() {
    final slotNode = controller.currentNode;
    final slotFunction = slotNode.parent;
    if (slotFunction is! _DynamicMathSlotFunction) return false;

    final host = slotFunction.parent;
    final startIndex = host.children.indexOf(slotFunction);
    if (startIndex < 0) return false;

    _DynamicMathSlotFunction? nextSlot;
    var endIndex = -1;
    for (var index = startIndex + 1; index < host.children.length; index++) {
      final child = host.children[index];
      if (child is _DynamicMathSlotFunction &&
          identical(child.structureKey, slotFunction.structureKey)) {
        nextSlot = child;
        break;
      }
      if (child is _DynamicStructureEndLeaf &&
          identical(child.structureKey, slotFunction.structureKey)) {
        endIndex = index;
        break;
      }
    }

    slotNode.removeCursor();
    if (nextSlot != null) {
      final nextNode = nextSlot.argNodes.single;
      nextNode.courserPosition = nextNode.children.length;
      nextNode.setCursor();
      controller.currentNode = nextNode;
      _publishControllerMutation();
      return true;
    }

    if (endIndex >= 0) {
      host.courserPosition = endIndex + 1;
      host.setCursor();
      controller.currentNode = host;
      _publishControllerMutation();
      return true;
    }

    // The structure tree is malformed or was externally modified. Restore the
    // cursor instead of leaving the controller without one.
    slotNode.setCursor();
    return false;
  }

  bool _isSeededDerivativeNumeratorSlot() {
    final node = controller.currentNode;
    final parent = node.parent;
    if (parent == null ||
        parent.expression != r'\frac' ||
        parent.argNodes.length != 2 ||
        !identical(parent.argNodes.first, node)) {
      return false;
    }

    return _firstNonCursorExpression(parent.argNodes[0]) == 'd' &&
        _firstNonCursorExpression(parent.argNodes[1]) == 'd';
  }

  bool _isLowerScriptFollowedByUpperScript() {
    final slotNode = controller.currentNode;
    final lowerScript = slotNode.parent;
    if (lowerScript == null || lowerScript.expression != '_') return false;

    final hostNode = lowerScript.parent;
    final lowerIndex = hostNode.children.indexOf(lowerScript);
    if (lowerIndex < 0 || lowerIndex + 1 >= hostNode.children.length) {
      return false;
    }

    final next = hostNode.children[lowerIndex + 1];
    return next is math_kb_node.TeXFunction && next.expression.startsWith('^');
  }

  String? _firstNonCursorExpression(math_kb_node.TeXNode node) {
    for (final child in node.children) {
      if (child is math_kb_node.Cursor) continue;
      return child.expression;
    }
    return null;
  }
}

class _DynamicMathSlotFunction extends math_kb_node.TeXFunction {
  final MathDynamicSlotSpec slot;
  final Object structureKey;

  _DynamicMathSlotFunction({
    required math_kb_node.TeXNode parent,
    required this.slot,
    required this.structureKey,
    required String initialValue,
  }) : super('', parent, <math_kb_node.TeXArg>[math_kb_node.TeXArg.braces]) {
    final node = argNodes.single;
    if (initialValue.isNotEmpty) {
      node.children.add(math_kb_node.TeXLeaf(initialValue));
      node.courserPosition = node.children.length;
    }
  }
}

class _DynamicStructureEndLeaf extends math_kb_node.TeXLeaf {
  final Object structureKey;

  _DynamicStructureEndLeaf({required String source, required this.structureKey})
    : super(source);
}
