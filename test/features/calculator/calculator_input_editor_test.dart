import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/models/calculator_editing_value.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_input_editor.dart';

void main() {
  const editor = CalculatorInputEditor();

  CalculatorEditingValue value(String text, int cursor, {int? extent}) {
    return CalculatorEditingValue(
      text: text,
      selection: CalculatorSelection(
        baseOffset: cursor,
        extentOffset: extent ?? cursor,
      ),
    );
  }

  group('CalculatorInputEditor', () {
    test('resolves shift and hyperbolic actions without UI state', () {
      expect(
        editor.resolveModeToken('sin(', isShift: true, isHyp: false),
        'arcsin(',
      );
      expect(
        editor.resolveModeToken('sin(', isShift: false, isHyp: true),
        'sinh(',
      );
      expect(
        editor.resolveModeToken('sqrt(', isShift: true, isHyp: false),
        'cbrt(',
      );
      expect(editor.resolveModeToken('C', isShift: true, isHyp: false), 'P');
    });

    test('deletes complete calculator tokens', () {
      expect(editor.deleteLastToken('2+arcsin('), '2+');
      expect(editor.deleteLastToken('2+sqrt('), '2+');
      expect(editor.deleteLastToken('2+Ans'), '2+');
      expect(editor.deleteLastToken('10^'), '');
    });

    test('inserts at the caret instead of always appending', () {
      final edited = editor.insert(
        value('12+45', 3),
        '3',
        justEvaluated: false,
      );

      expect(edited.text, '12+345');
      expect(edited.cursorOffset, 4);
    });

    test('replaces a selected range and collapses caret after insertion', () {
      final edited = editor.insert(
        value('12+456', 3, extent: 6),
        '9',
        justEvaluated: false,
      );

      expect(edited.text, '12+9');
      expect(edited.selection, const CalculatorSelection.collapsed(4));
    });

    test('backspace removes selection before token-aware deletion', () {
      final selectionDeleted = editor.deleteBackward(
        value('12+456', 3, extent: 6),
      );
      expect(selectionDeleted.text, '12+');
      expect(selectionDeleted.cursorOffset, 3);

      final tokenDeleted = editor.deleteBackward(value('2+sqrt(9', 7));
      expect(tokenDeleted.text, '2+9');
      expect(tokenDeleted.cursorOffset, 2);
    });

    test('forward delete removes token or next character at the caret', () {
      final tokenDeleted = editor.deleteForward(value('2+sqrt(9', 2));
      expect(tokenDeleted.text, '2+9');
      expect(tokenDeleted.cursorOffset, 2);

      final charDeleted = editor.deleteForward(value('123', 1));
      expect(charDeleted.text, '13');
      expect(charDeleted.cursorOffset, 1);
    });

    test('prevents duplicate decimal points in the number around caret', () {
      expect(editor.append('', '.', justEvaluated: false), '0.');
      expect(editor.append('1.2', '.', justEvaluated: false), '1.2');
      expect(editor.append('1.2+', '.', justEvaluated: false), '1.2+0.');

      final middle = editor.insert(
        value('12.34+5', 2),
        '.',
        justEvaluated: false,
      );
      expect(middle.text, '12.34+5');

      final validMiddle = editor.insert(
        value('1234+5', 2),
        '.',
        justEvaluated: false,
      );
      expect(validMiddle.text, '12.34+5');
      expect(validMiddle.cursorOffset, 3);

      final negativeOperand = editor.insert(
        value('2×-5', 3),
        '.',
        justEvaluated: false,
      );
      expect(negativeOperand.text, '2×-0.5');
      expect(negativeOperand.cursorOffset, 5);
    });

    test(
      'normalizes adjacent binary operators but permits negative operands',
      () {
        expect(editor.append('2+', '×', justEvaluated: false), '2×');
        expect(editor.append('2×', '-', justEvaluated: false), '2×-');
        expect(editor.append('2^', '-', justEvaluated: false), '2^-');

        final middle = editor.insert(
          value('2+5', 2),
          '×',
          justEvaluated: false,
        );
        expect(middle.text, '2×5');
        expect(middle.cursorOffset, 2);
      },
    );

    test(
      'zero can be followed by an operator and leading zero is normalized',
      () {
        expect(editor.append('0', '+', justEvaluated: false), '0+');
        expect(editor.append('0', '5', justEvaluated: false), '5');
        expect(editor.append('0', '.', justEvaluated: false), '0.');
      },
    );

    test('continues from Ans after a completed calculation', () {
      expect(editor.append('2+3', '+', justEvaluated: true), 'Ans+');
      expect(editor.append('2+3', '^2', justEvaluated: true), 'Ans^2');
      expect(editor.append('2+3', '7', justEvaluated: true), '7');
    });

    test('toggles sign on the entry at the caret', () {
      expect(editor.toggleSign('12+5'), '12+-5');
      expect(editor.toggleSign('12+-5'), '12+5');
      expect(editor.toggleSign(''), '-');

      final edited = editor.toggleSignAtCaret(value('12+5×3', 4));
      expect(edited.text, '12+-5×3');
      expect(edited.cursorOffset, 5);

      final restored = editor.toggleSignAtCaret(edited);
      expect(restored.text, '12+5×3');
      expect(restored.cursorOffset, 4);
    });

    test('caret movement treats known multi-character tokens atomically', () {
      final left = editor.moveCaretBackward(value('2+sqrt(9', 7));
      expect(left.cursorOffset, 2);

      final right = editor.moveCaretForward(value('2+sqrt(9', 2));
      expect(right.cursorOffset, 7);
    });

    test('caret movement can extend and collapse a selection', () {
      var edited = editor.moveCaretBackward(
        value('1234', 4),
        extendSelection: true,
      );
      expect(
        edited.selection,
        const CalculatorSelection(baseOffset: 4, extentOffset: 3),
      );

      edited = editor.moveCaretBackward(edited);
      expect(edited.selection, const CalculatorSelection.collapsed(3));

      edited = editor.moveCaretForward(edited, extendSelection: true);
      expect(
        edited.selection,
        const CalculatorSelection(baseOffset: 3, extentOffset: 4),
      );
    });
  });
}
