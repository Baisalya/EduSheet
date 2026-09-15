import 'dart:io';

import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_edit_command.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/presentation/editing/math_editor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const context = MathInsertionContext(
    powerMode: false,
    subscriptMode: false,
    symbolSizeLevel: 0,
  );

  test('duplicate semantic placements share declarative command semantics', () {
    final byId = <String, List<MathSymbol>>{};
    for (final symbol in MathSymbolCatalog.symbols) {
      byId.putIfAbsent(symbol.id, () => <MathSymbol>[]).add(symbol);
    }

    for (final placements in byId.values) {
      final commands = placements.map((item) => item.editorCommand).toList();
      final hasCommand = commands.any((command) => command != null);
      if (!hasCommand) continue;

      expect(
        commands.every((command) => command != null),
        isTrue,
        reason:
            'Semantic id ${placements.first.id} must not change editor '
            'behavior between categories.',
      );
      final expected = _commandSignature(commands.first!);
      for (final command in commands.skip(1)) {
        expect(
          _commandSignature(command!),
          expected,
          reason: 'Semantic id ${placements.first.id}',
        );
      }
    }
  });

  test('visual insertion executes metadata instead of matching symbol TeX', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);

    const synthetic = MathSymbol(
      id: 'test.synthetic.fraction',
      label: 'Synthetic',
      tex: r'\notTheFractionSource',
      category: MathCategory.misc,
      kind: MathEntryKind.structure,
      isBuilder: true,
      editorCommand: MathEditCommands.fraction,
    );

    adapter.insertSymbol(synthetic, context);
    adapter.insert('a', context);
    adapter.moveToNextSlot();
    adapter.insert('b', context);

    final value = controller.currentEditingValue();
    expect(value, contains(r'\frac'));
    expect(value, contains('a'));
    expect(value, contains('b'));
    expect(value, isNot(contains(r'\notTheFractionSource')));
  });

  test('function-call command is also independent from stored TeX', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);

    const synthetic = MathSymbol(
      id: 'test.synthetic.sin',
      label: 'Synthetic sin',
      tex: r'\unrelated',
      category: MathCategory.misc,
      kind: MathEntryKind.function,
      editorCommand: MathEditCommands.sinCall,
    );

    adapter.insertSymbol(synthetic, context);
    adapter.insert('x', context);

    final value = controller.currentEditingValue();
    expect(value, contains(r'\sin'));
    expect(value, contains('x'));
    expect(value, isNot(contains(r'\unrelated')));
  });

  test('declarative command coverage includes Phase 5 structures', () {
    final placements = MathSymbolCatalog.symbols
        .where((symbol) => symbol.editorCommand != null)
        .toList(growable: false);
    final semanticIds = placements.map((symbol) => symbol.id).toSet();

    expect(placements, hasLength(85));
    expect(semanticIds, hasLength(76));

    for (final symbol in placements) {
      expect(
        symbol.editorCommand!.isEmpty,
        isFalse,
        reason: '${symbol.id} (${symbol.tex})',
      );
    }
  });

  test('raw compatibility aliases remain declarative and explicit', () {
    expect(MathLegacyEditCommandRegistry.bySource, hasLength(77));
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\frac{}{}'],
      same(MathEditCommands.fraction),
    );
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\int_{}^{}^{}'],
      same(MathEditCommands.integralWithLimits),
    );
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\triangle_{A B C}'],
      same(MathEditCommands.triangleSubscript),
    );
  });

  test('visual adapter no longer contains the TeX dispatch tree', () {
    final source = File(
      'lib/features/math_keyboard/presentation/editing/math_editor_adapter.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('functionsWithBraces')));
    expect(source, isNot(contains("source == r'\\frac{1}{2}'")));
    expect(source, isNot(contains("source.endsWith(r'\\theta')")));
    expect(source, isNot(contains("source.startsWith('^{')")));
  });
}

String _commandSignature(MathEditCommand command) {
  return command.operations
      .map((operation) {
        switch (operation) {
          case MathInsertLeaf(:final source):
            return 'leaf:$source';
          case MathInsertFunction(:final function, :final arguments):
            return 'function:$function:${arguments.map((item) => item.name).join(',')}';
          case MathMoveSlot(:final direction, :final count):
            return 'move:${direction.name}:$count';
          case MathInsertDynamicStructure(:final spec):
            return 'dynamic:${spec.kind.name}:${spec.rows}:${spec.columns}:'
                '${spec.augmentedSplitAfter}:${spec.relation}';
        }
      })
      .join('|');
}
