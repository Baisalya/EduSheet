import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_dynamic_structure.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_edit_command.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_dynamic_structure_codec.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_plain_text_serializer.dart';
import 'package:edusheet/features/math_keyboard/presentation/editing/math_editor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_keyboard/math_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = MathDynamicStructureCodec();
  const insertionContext = MathInsertionContext(
    powerMode: false,
    subscriptMode: false,
    symbolSizeLevel: 0,
  );

  test('runtime specs reject invalid dimensions, dividers and relations', () {
    expect(
      const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 13,
        columns: 2,
      ).isValid,
      isFalse,
    );
    expect(
      const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.determinant,
        rows: 2,
        columns: 3,
      ).isValid,
      isFalse,
    );
    expect(
      const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.augmentedMatrix,
        rows: 2,
        columns: 3,
        augmentedSplitAfter: 3,
      ).isValid,
      isFalse,
    );
    expect(
      const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.alignedDerivation,
        rows: 2,
        relation: r'\approx',
      ).isValid,
      isFalse,
    );
  });

  test('compiler builds an arbitrary matrix from runtime dimensions', () {
    final instance = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 2,
        columns: 3,
      ),
      values: const <String>['a', 'b', 'c', 'd', 'e', 'f'],
    );

    final document = codec.compile(instance);

    expect(document.slots, hasLength(6));
    expect(
      document.tex,
      r'\begin{pmatrix}{a}&{b}&{c}\\{d}&{e}&{f}\end{pmatrix}',
    );
    expect(document.plainText, '[2×3 matrix]');
  });

  test('augmented matrix round-trips dimensions, divider and values', () {
    final instance = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.augmentedMatrix,
        rows: 2,
        columns: 4,
        augmentedSplitAfter: 3,
      ),
      values: const <String>['1', '0', '2', '5', '0', '1', '-1', '3'],
    );

    final document = codec.compile(instance);
    final restored = codec.tryParse(document.tex);

    expect(document.tex, contains(r'\begin{array}{ccc|c}'));
    expect(restored, isNotNull);
    expect(restored!.spec.kind, MathDynamicStructureKind.augmentedMatrix);
    expect(restored.spec.rows, 2);
    expect(restored.spec.columns, 4);
    expect(restored.spec.augmentedSplitAfter, 3);
    expect(restored.values, instance.values);
  });

  test('piecewise builder has expression-condition slots for every row', () {
    final instance = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.piecewise,
        rows: 3,
      ),
      values: const <String>['x^2', 'x<0', '0', 'x=0', 'x+1', 'x>0'],
    );

    final document = codec.compile(instance);
    final restored = codec.tryParse(document.tex);

    expect(document.slots, hasLength(6));
    expect(document.slots[0].role, MathDynamicSlotRole.expression);
    expect(document.slots[1].role, MathDynamicSlotRole.condition);
    expect(document.slots[4].row, 2);
    expect(restored, isNotNull);
    expect(restored!.spec.kind, MathDynamicStructureKind.piecewise);
    expect(restored.spec.rows, 3);
    expect(restored.values, instance.values);
  });

  test('aligned cases equations rehydrate as an equation system', () {
    final restored = codec.tryParse(r'\begin{cases}x+y&=1\\x-y&=0\end{cases}');

    expect(restored, isNotNull);
    expect(restored!.spec.kind, MathDynamicStructureKind.equationSystem);
    expect(restored.spec.rows, 2);
    expect(restored.values, const <String>['x+y=1', 'x-y=0']);
  });

  test('equation systems and aligned derivations use runtime row counts', () {
    final equations = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.equationSystem,
        rows: 4,
      ),
      values: const <String>['x+y=1', 'x-y=0', 'z=2', 'w=3'],
    );
    final aligned = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.alignedDerivation,
        rows: 3,
        relation: r'\Rightarrow',
      ),
      values: const <String>['2x+4', '10', '2x', '6', 'x', '3'],
    );

    final equationDocument = codec.compile(equations);
    final alignedDocument = codec.compile(aligned);
    final restoredEquations = codec.tryParse(equationDocument.tex);
    final restoredAligned = codec.tryParse(alignedDocument.tex);

    expect(restoredEquations, isNotNull);
    expect(restoredEquations!.spec.rows, 4);
    expect(restoredEquations.values, equations.values);
    expect(alignedDocument.tex, contains(r'&\Rightarrow'));
    expect(restoredAligned, isNotNull);
    expect(restoredAligned!.spec.rows, 3);
    expect(restoredAligned.spec.relation, r'\Rightarrow');
    expect(restoredAligned.values, aligned.values);
  });

  test('visual matrix walks cell-to-cell with one semantic Next action', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final instance = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.matrix,
        rows: 2,
        columns: 3,
      ),
    );

    adapter.insertDynamicStructure(instance, insertionContext);
    for (final value in <String>['a', 'b', 'c', 'd', 'e', 'f']) {
      adapter.insert(value, insertionContext);
      if (value != 'f') adapter.moveToNextSlot();
    }

    expect(
      controller.currentEditingValue(placeholderWhenEmpty: false),
      contains(r'\begin{pmatrix}{a}&{b}&{c}\\{d}&{e}&{f}\end{pmatrix}'),
    );
  });

  test('visual piecewise navigation alternates expression and condition', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final instance = MathDynamicStructureInstance(
      spec: const MathDynamicStructureSpec(
        kind: MathDynamicStructureKind.piecewise,
        rows: 2,
      ),
    );

    adapter.insertDynamicStructure(instance, insertionContext);
    for (final value in <String>['x', 'x<0', '0', 'x>=0']) {
      adapter.insert(value, insertionContext);
      if (value != 'x>=0') adapter.moveToNextSlot();
    }

    final source = controller.currentEditingValue(placeholderWhenEmpty: false);
    expect(source, contains(r'f(x)=\begin{cases}{x}&{x<0}'));
    expect(source, contains(r'\\{0}&{x>=0}\end{cases}'));
  });

  test('fixed catalogue presets route through dynamic structure commands', () {
    final expected = <String, MathEditCommand>{
      r'\begin{pmatrix}  & \\  & \end{pmatrix}': MathEditCommands.matrix2x2,
      r'\begin{pmatrix}  &  & \\  &  & \\  &  & \end{pmatrix}':
          MathEditCommands.matrix3x3,
      r'\begin{vmatrix}  & \\  & \end{vmatrix}':
          MathEditCommands.determinant2x2,
      r'f(x)=\begin{cases} & \\ & \end{cases}': MathEditCommands.piecewise2Rows,
    };

    for (final entry in expected.entries) {
      final symbol = MathSymbolCatalog.findByTex(entry.key);
      expect(symbol, isNotNull, reason: entry.key);
      expect(symbol!.editorCommand, same(entry.value), reason: entry.key);
      expect(
        entry.value.operations.any(
          (operation) => operation is MathInsertDynamicStructure,
        ),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test(
    'legacy two-equation template is recognized as editable dynamic rows',
    () {
      final controller = MathFieldEditingController();
      addTearDown(controller.dispose);
      final adapter = MathFieldEditorAdapter(controller);
      final symbol = MathSymbolCatalog.findByTex(
        r'\begin{cases} ax+by=c \\ dx+ey=f \end{cases}',
      );

      expect(symbol, isNotNull);
      adapter.insertSymbol(symbol!, insertionContext);
      adapter.moveToNextSlot();
      adapter.insert('+1', insertionContext);

      final source = controller.currentEditingValue(
        placeholderWhenEmpty: false,
      );
      expect(source, contains(r'{ax+by=c}'));
      expect(source, contains(r'{dx+ey=f+1}'));
    },
  );

  test('legacy fixed determinant keeps its existing plain-text fallback', () {
    const serializer = MathPlainTextSerializer();
    final insertion = serializer.serialize(
      r'\begin{vmatrix}  & \\  & \end{vmatrix}',
      powerMode: false,
      subscriptMode: false,
    );

    expect(insertion.text, '|A|');
  });

  test(
    'plain-text fallback reports arbitrary rectangular matrix dimensions',
    () {
      const serializer = MathPlainTextSerializer();
      final source = codec
          .compile(
            MathDynamicStructureInstance(
              spec: const MathDynamicStructureSpec(
                kind: MathDynamicStructureKind.matrix,
                rows: 5,
                columns: 4,
              ),
            ),
          )
          .tex;

      final insertion = serializer.serialize(
        source,
        powerMode: false,
        subscriptMode: false,
      );

      expect(insertion.text, '[5×4 matrix]');
    },
  );

  test('plain-text fallback scales with dynamic structure dimensions', () {
    const serializer = MathPlainTextSerializer();
    final source = codec
        .compile(
          MathDynamicStructureInstance(
            spec: const MathDynamicStructureSpec(
              kind: MathDynamicStructureKind.determinant,
              rows: 5,
              columns: 5,
            ),
          ),
        )
        .tex;

    final insertion = serializer.serialize(
      source,
      powerMode: false,
      subscriptMode: false,
    );

    expect(insertion.text, '[5×5 determinant]');
  });
}
