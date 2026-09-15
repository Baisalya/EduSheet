import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_composer_spec.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_edit_command.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_selection_composer.dart';
import 'package:edusheet/features/math_keyboard/presentation/editing/math_editor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const insertionContext = MathInsertionContext(
    powerMode: false,
    subscriptMode: false,
    symbolSizeLevel: 0,
  );
  const selectionComposer = MathSelectionComposer();

  test('fraction exposes semantic slots without parsing its TeX', () {
    final composer = MathEditCommands.fraction.composer;

    expect(composer, isNotNull);
    expect(composer!.id, 'fraction');
    expect(composer.slotCount, 2);
    expect(composer.slots[0].role, MathComposerSlotRole.numerator);
    expect(composer.slots[1].role, MathComposerSlotRole.denominator);
    expect(composer.supportsNesting, isTrue);
  });

  test(
    'source selection can be wrapped as a fraction with denominator focus',
    () {
      final recipe = MathEditCommands.fraction.composer!.selectionWrap!;
      final result = selectionComposer.wrap(
        source: 'A=x+1',
        selection: const MathSourceSelection(start: 2, end: 5),
        recipe: recipe,
      );

      expect(result, isNotNull);
      expect(result!.source, r'A=\frac{x+1}{}');
      expect(result.cursorOffset, result.source.length - 1);
      expect(
        result.source.substring(
          result.cursorOffset - 1,
          result.cursorOffset + 1,
        ),
        '{}',
      );
    },
  );

  test('source selection wrapping accepts reverse selections', () {
    final recipe = MathEditCommands.squareRoot.composer!.selectionWrap!;
    final result = selectionComposer.wrap(
      source: 'x+1',
      selection: const MathSourceSelection(start: 3, end: 0),
      recipe: recipe,
    );

    expect(result, isNotNull);
    expect(result!.source, r'\sqrt{x+1}');
    expect(result.cursorOffset, result.source.length);
  });

  test('collapsed or invalid source selection is never guessed', () {
    final recipe = MathEditCommands.absoluteValue.composer!.selectionWrap!;

    expect(
      selectionComposer.wrap(
        source: 'x+1',
        selection: const MathSourceSelection(start: 1, end: 1),
        recipe: recipe,
      ),
      isNull,
    );
    expect(
      selectionComposer.wrap(
        source: 'x+1',
        selection: const MathSourceSelection(start: -1, end: 2),
        recipe: recipe,
      ),
      isNull,
    );
  });

  test('Phase 3 builders expose ordered semantic slots', () {
    expect(
      MathEditCommands.subscriptAndSuperscript.composer!.slots
          .map((slot) => slot.role)
          .toList(growable: false),
      <MathComposerSlotRole>[
        MathComposerSlotRole.subscript,
        MathComposerSlotRole.exponent,
      ],
    );
    expect(
      MathEditCommands.genericDerivative.composer!.slots
          .map((slot) => slot.role)
          .toList(growable: false),
      <MathComposerSlotRole>[
        MathComposerSlotRole.expression,
        MathComposerSlotRole.variable,
      ],
    );
    expect(
      MathEditCommands.evaluationBar.composer!.slots
          .map((slot) => slot.role)
          .toList(growable: false),
      <MathComposerSlotRole>[
        MathComposerSlotRole.lowerLimit,
        MathComposerSlotRole.upperLimit,
      ],
    );
    expect(
      MathEditCommands.norm.composer!.slots.single.role,
      MathComposerSlotRole.body,
    );
  });

  test('new composer structures are first-class catalogue entries', () {
    final expected = <String, MathEditCommand>{
      r'_{}^{}': MathEditCommands.subscriptAndSuperscript,
      r'\frac{d{}}{d{}}': MathEditCommands.genericDerivative,
      r'\lim_{}': MathEditCommands.genericLimit,
      r'\langle{},{}\rangle': MathEditCommands.innerProduct,
      r'|_{}^{}': MathEditCommands.evaluationBar,
      r'||{}||': MathEditCommands.norm,
    };

    for (final entry in expected.entries) {
      final symbol = MathSymbolCatalog.findByTex(entry.key);
      expect(symbol, isNotNull, reason: entry.key);
      expect(symbol!.editorCommand, same(entry.value), reason: entry.key);
      expect(symbol.composer, isNotNull, reason: entry.key);
      expect(symbol.isStructural, isTrue, reason: entry.key);
    }
  });

  test(
    'generic derivative starts in expression slot and Next reaches variable',
    () {
      final controller = MathFieldEditingController();
      addTearDown(controller.dispose);
      final adapter = MathFieldEditorAdapter(controller);
      final symbol = MathSymbolCatalog.findByTex(r'\frac{d{}}{d{}}');

      expect(symbol, isNotNull);
      adapter.insertSymbol(symbol!, insertionContext);
      adapter.insert('f', insertionContext);
      adapter.moveToNextSlot();
      adapter.insert('x', insertionContext);

      final value = controller.currentEditingValue();
      expect(value, contains(r'\frac{df}{dx}'));
    },
  );

  test(
    'combined scripts expose one semantic Next from subscript to exponent',
    () {
      final controller = MathFieldEditingController();
      addTearDown(controller.dispose);
      final adapter = MathFieldEditorAdapter(controller);
      final symbol = MathSymbolCatalog.findByTex(r'_{}^{}');

      expect(symbol, isNotNull);
      adapter.insert('x', insertionContext);
      adapter.insertSymbol(symbol!, insertionContext);
      adapter.insert('i', insertionContext);
      adapter.moveToNextSlot();
      adapter.insert('n', insertionContext);

      final value = controller.currentEditingValue();
      expect(value, contains(r'x_{i}^{n}'));
    },
  );

  test('visual composer nests structures using public slot operations', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);

    const fraction = MathSymbol(
      id: 'test.phase3.fraction',
      label: 'fraction',
      tex: r'\irrelevantFractionSource',
      category: MathCategory.functions,
      kind: MathEntryKind.structure,
      editorCommand: MathEditCommands.fraction,
      isBuilder: true,
    );
    const root = MathSymbol(
      id: 'test.phase3.root',
      label: 'root',
      tex: r'\irrelevantRootSource',
      category: MathCategory.functions,
      kind: MathEntryKind.structure,
      editorCommand: MathEditCommands.squareRoot,
      isBuilder: true,
    );

    adapter.insertSymbol(fraction, insertionContext);
    adapter.insertSymbol(root, insertionContext);
    adapter.insert('x', insertionContext);

    final value = controller.currentEditingValue();
    expect(value, contains(r'\frac'));
    expect(value, contains(r'\sqrt'));
    expect(value, contains('x'));
    expect(value, isNot(contains('irrelevant')));
  });
}
