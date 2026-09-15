import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_dynamic_structure.dart';
import 'package:edusheet/features/math_keyboard/presentation/editing/math_editor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  const context = MathInsertionContext(
    powerMode: false,
    subscriptMode: false,
    symbolSizeLevel: 0,
  );

  test('previous slot returns from denominator to numerator', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final fraction = MathSymbolCatalog.findByTex(r'\frac{}{}');
    expect(fraction, isNotNull);

    adapter.insertSymbol(fraction!, context);
    adapter.insert('1', context);
    expect(adapter.moveToNextSlot(), isTrue);
    adapter.insert('2', context);
    expect(adapter.moveToPreviousSlot(), isTrue);
    adapter.insert('3', context);

    final source = controller.currentEditingValue(placeholderWhenEmpty: false);
    expect(source, contains(r'\frac'));
    expect(source, contains('{13}'));
    expect(source, contains('{2}'));
  });

  test('reverse slot navigation remains available after combined scripts', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final combined = MathSymbolCatalog.findByTex(r'_{}^{}');
    expect(combined, isNotNull);

    adapter.insert('x', context);
    adapter.insertSymbol(combined!, context);
    adapter.insert('i', context);
    expect(adapter.moveToNextSlot(), isTrue);
    adapter.insert('n', context);
    expect(adapter.moveToPreviousSlot(), isTrue);
    adapter.insert('j', context);

    final source = controller.currentEditingValue(placeholderWhenEmpty: false);
    expect(source, contains(r'x_{ij}^{n}'));
  });
  test('previous slot walks backward inside runtime-sized structures', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final matrix = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 1,
        columns: 3,
      ),
    );

    adapter.insertDynamicStructure(matrix, context);
    adapter.insert('a', context);
    adapter.moveToNextSlot();
    adapter.insert('b', context);
    adapter.moveToNextSlot();
    adapter.insert('c', context);
    expect(adapter.moveToPreviousSlot(), isTrue);
    adapter.insert('d', context);

    final source = controller.currentEditingValue(placeholderWhenEmpty: false);
    expect(source, contains(r'\begin{pmatrix}{a}&{bd}&{c}\end{pmatrix}'));
  });
}
