import 'package:edusheet/features/math_keyboard/presentation/editing/math_editor_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = MathInsertionContext(
    powerMode: false,
    subscriptMode: false,
    symbolSizeLevel: 0,
  );

  group('TextFieldMathEditorAdapter', () {
    test('wraps insertion without replacing unrelated text', () {
      final controller = TextEditingController(text: 'x=');
      controller.selection = const TextSelection.collapsed(offset: 2);
      final adapter = TextFieldMathEditorAdapter(controller);

      adapter.insert(r'\sqrt{}', context);

      expect(controller.text, 'x=√()');
      expect(controller.selection.baseOffset, 4);
    });

    test('replaces selected text', () {
      final controller = TextEditingController(text: 'abc');
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 2,
      );
      final adapter = TextFieldMathEditorAdapter(controller);

      adapter.insert(r'\pi', context);

      expect(controller.text, 'aπc');
      expect(controller.selection.baseOffset, 2);
    });

    test('delete backward handles a selection safely', () {
      final controller = TextEditingController(text: 'abcd');
      controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 1,
      );
      final adapter = TextFieldMathEditorAdapter(controller);

      adapter.deleteBackward();

      expect(controller.text, 'ad');
      expect(controller.selection.baseOffset, 1);
    });

    test('falls back when structured slot navigation is unavailable', () {
      final adapter = TextFieldMathEditorAdapter(TextEditingController());

      expect(adapter.moveToNextSlot(), isFalse);
    });
  });
}
