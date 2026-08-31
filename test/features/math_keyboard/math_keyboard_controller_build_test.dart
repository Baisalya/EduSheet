import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Build insertion cancels temporary modes and inserts immediately', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final textController = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(textController.dispose);
    addTearDown(focusNode.dispose);

    final keyboard = container.read(mathKeyboardControllerProvider.notifier);
    keyboard.registerController(textController, focusNode);
    keyboard.togglePowerMode();
    expect(container.read(mathKeyboardControllerProvider).isPowerMode, isTrue);

    final fraction = MathSymbolCatalog.findByTex(r'\frac{}{}');
    expect(fraction, isNotNull);

    keyboard.insertStructure(fraction!);

    final state = container.read(mathKeyboardControllerProvider);
    expect(state.isPowerMode, isFalse);
    expect(state.isSubscriptMode, isFalse);
    expect(textController.text, '()⁄()');
    expect(textController.selection.baseOffset, 1);
  });

  test('Build power key does not leave the keyboard in power mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final textController = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(textController.dispose);
    addTearDown(focusNode.dispose);

    final keyboard = container.read(mathKeyboardControllerProvider.notifier);
    keyboard.registerController(textController, focusNode);

    final power = MathSymbolCatalog.findByTex(r'^{}');
    expect(power, isNotNull);

    keyboard.insertStructure(power!);

    final state = container.read(mathKeyboardControllerProvider);
    expect(state.isPowerMode, isFalse);
    expect(state.isSubscriptMode, isFalse);
    expect(textController.text, '^');
  });
  test('visible math session owner transfers without hiding the keyboard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final firstController = TextEditingController();
    final secondController = TextEditingController();
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    final keyboard = container.read(mathKeyboardControllerProvider.notifier);
    keyboard.showMathKeyboardFor(firstController, firstFocus);

    final transferred = keyboard.transferMathSessionOwner(
      firstController,
      secondController,
      secondFocus,
    );

    final state = container.read(mathKeyboardControllerProvider);
    expect(transferred, isTrue);
    expect(state.isVisible, isTrue);
    expect(state.type, KeyboardType.math);
    expect(identical(state.activeController, secondController), isTrue);
    expect(identical(state.activeFocusNode, secondFocus), isTrue);
  });

  test('visual structures expose slots and preserve navigation/delete', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final visualController = MathFieldEditingController();
    final focusNode = FocusNode();
    addTearDown(visualController.dispose);
    addTearDown(focusNode.dispose);

    final keyboard = container.read(mathKeyboardControllerProvider.notifier);
    keyboard.showMathKeyboardFor(visualController, focusNode);
    final fraction = MathSymbolCatalog.findByTex(r'\frac{}{}');
    expect(fraction, isNotNull);

    keyboard.insertStructure(fraction!);
    keyboard.insertText('a');
    keyboard.nextField();
    keyboard.insertText('b');

    var value = visualController.currentEditingValue();
    expect(value, contains(r'\frac'));
    expect(value, contains('a'));
    expect(value, contains('b'));

    final beforeTemporaryEntry = value;
    keyboard.insertText('c');
    keyboard.moveCursorLeft();
    keyboard.moveCursorRight();
    keyboard.deleteBackward();
    value = visualController.currentEditingValue();
    expect(value, beforeTemporaryEntry);
    expect(value, contains('a'));
    expect(value, contains('b'));
  });

  test('root power and subscript Build keys insert immediately', () {
    for (final source in <String>[r'\sqrt{}', r'^{}', r'_{}']) {
      final container = ProviderContainer();
      final visualController = MathFieldEditingController();
      final focusNode = FocusNode();
      addTearDown(container.dispose);
      addTearDown(visualController.dispose);
      addTearDown(focusNode.dispose);

      final keyboard = container.read(mathKeyboardControllerProvider.notifier);
      keyboard.showMathKeyboardFor(visualController, focusNode);
      final structure = MathSymbolCatalog.findByTex(source);
      expect(structure, isNotNull, reason: source);

      keyboard.insertStructure(structure!);
      keyboard.insertText('x');

      final value = visualController.currentEditingValue();
      expect(value, isNotEmpty, reason: source);
      expect(value, contains('x'), reason: source);
      expect(
        container.read(mathKeyboardControllerProvider).isPowerMode,
        isFalse,
        reason: source,
      );
      expect(
        container.read(mathKeyboardControllerProvider).isSubscriptMode,
        isFalse,
        reason: source,
      );
    }
  });
}
