import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/domain/models/calculator_editing_value.dart';

void main() {
  group('CalculatorEditingValue', () {
    test('fromText places caret at the end by default', () {
      final value = CalculatorEditingValue.fromText('12+3');

      expect(value.text, '12+3');
      expect(value.selection, const CalculatorSelection.collapsed(4));
      expect(value.cursorOffset, 4);
      expect(value.hasSelection, isFalse);
    });

    test('normalizes out-of-range selection without changing text', () {
      const value = CalculatorEditingValue(
        text: '123',
        selection: CalculatorSelection(baseOffset: -5, extentOffset: 99),
      );

      final normalized = value.normalized();

      expect(normalized.text, '123');
      expect(normalized.selection.start, 0);
      expect(normalized.selection.end, 3);
    });

    test('selection supports reversed base and extent offsets', () {
      const selection = CalculatorSelection(baseOffset: 5, extentOffset: 2);

      expect(selection.start, 2);
      expect(selection.end, 5);
      expect(selection.isCollapsed, isFalse);
    });
  });
}
