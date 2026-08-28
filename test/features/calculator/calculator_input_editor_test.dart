import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/services/calculator_input_editor.dart';

void main() {
  const editor = CalculatorInputEditor();

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

    test('prevents duplicate decimal points in the current number', () {
      expect(editor.append('', '.', justEvaluated: false), '0.');
      expect(editor.append('1.2', '.', justEvaluated: false), '1.2');
      expect(editor.append('1.2+', '.', justEvaluated: false), '1.2+0.');
    });

    test(
      'normalizes adjacent binary operators but permits negative operands',
      () {
        expect(editor.append('2+', '×', justEvaluated: false), '2×');
        expect(editor.append('2×', '-', justEvaluated: false), '2×-');
        expect(editor.append('2^', '-', justEvaluated: false), '2^-');
      },
    );

    test('continues from Ans after a completed calculation', () {
      expect(editor.append('2+3', '+', justEvaluated: true), 'Ans+');
      expect(editor.append('2+3', '^2', justEvaluated: true), 'Ans^2');
      expect(editor.append('2+3', '7', justEvaluated: true), '7');
    });

    test('toggles sign on the current entry', () {
      expect(editor.toggleSign('12+5'), '12+-5');
      expect(editor.toggleSign('12+-5'), '12+5');
      expect(editor.toggleSign(''), '-');
    });
  });
}
