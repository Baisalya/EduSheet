import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/catalog/symbol_universe_expansion_catalog.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_edit_command.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_accessible_text_service.dart';
import 'package:edusheet/features/math_keyboard/domain/services/math_plain_text_serializer.dart';
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
  const serializer = MathPlainTextSerializer();

  test(
    'Phase 5 adds 87 explicit universe placements with stable identities',
    () {
      expect(symbolUniverseExpansionMathSymbols, hasLength(87));
      expect(
        symbolUniverseExpansionMathSymbols.map((symbol) => symbol.id).toSet(),
        hasLength(87),
      );
      expect(
        symbolUniverseExpansionMathSymbols.map((symbol) => symbol.tex).toSet(),
        hasLength(87),
      );
    },
  );

  test('former Phase 1 gaps are now first-class catalogue keys', () {
    const promotedSources = <String>[
      r'\binom{}{}',
      r'\mapsto',
      r'\bigcup_{}^{}',
      r'\bigcap_{}^{}',
      r'\varepsilon',
      r'\vartheta',
      r'\varphi',
    ];

    for (final source in promotedSources) {
      expect(MathSymbolCatalog.findByTex(source), isNotNull, reason: source);
    }
  });

  test('new subject families are semantically searchable', () {
    final numberTheory = MathSymbolCatalog.search(
      'greatest common divisor',
      subject: MathSubject.numberTheory,
    );
    expect(numberTheory, isNotEmpty);
    expect(numberTheory.first.tex, r'\gcd');

    final combinatorics = MathSymbolCatalog.search(
      'n choose r',
      subject: MathSubject.combinatorics,
    );
    expect(combinatorics, isNotEmpty);
    expect(combinatorics.first.tex, r'\binom{}{}');

    final complex = MathSymbolCatalog.search(
      'complex conjugate',
      subject: MathSubject.complexNumbers,
    );
    expect(complex, isNotEmpty);
    expect(complex.first.tex, r'\overline{}');
  });

  test('new structured notation exposes semantic composer slots', () {
    final binomial = MathSymbolCatalog.findByTex(r'\binom{}{}')!;
    final modulo = MathSymbolCatalog.findByTex(r'\pmod{}')!;
    final bigUnion = MathSymbolCatalog.findByTex(r'\bigcup_{}^{}')!;
    final conjugate = MathSymbolCatalog.findByTex(r'\overline{}')!;

    expect(binomial.composer?.slotCount, 2);
    expect(binomial.supportsSourceSelectionWrap, isTrue);
    expect(modulo.composer?.slotCount, 1);
    expect(modulo.supportsSourceSelectionWrap, isTrue);
    expect(bigUnion.composer?.slotCount, 2);
    expect(conjugate.composer?.slotCount, 1);
    expect(conjugate.supportsSourceSelectionWrap, isTrue);
  });

  test('binomial command navigates upper slot to lower slot', () {
    final controller = MathFieldEditingController();
    addTearDown(controller.dispose);
    final adapter = MathFieldEditorAdapter(controller);
    final symbol = MathSymbolCatalog.findByTex(r'\binom{}{}')!;

    adapter.insertSymbol(symbol, insertionContext);
    adapter.insert('n', insertionContext);
    adapter.moveToNextSlot();
    adapter.insert('r', insertionContext);

    final source = controller.currentEditingValue(placeholderWhenEmpty: false);
    expect(source, contains(r'\binom'));
    expect(source, contains('n'));
    expect(source, contains('r'));
  });

  test('every Phase 5 placement has a useful plain-text fallback', () {
    for (final symbol in symbolUniverseExpansionMathSymbols) {
      final insertion = serializer.serialize(
        symbol.tex,
        powerMode: false,
        subscriptMode: false,
      );
      expect(insertion.text.trim(), isNotEmpty, reason: symbol.tex);
      expect(insertion.text, isNot(contains('\\')), reason: symbol.tex);
      expect(
        insertion.cursorOffset,
        allOf(
          greaterThanOrEqualTo(0),
          lessThanOrEqualTo(insertion.text.length),
        ),
        reason: symbol.tex,
      );
    }
  });

  test('accessibility fallback speaks new compound notation meaningfully', () {
    const accessible = MathAccessibleTextService();

    expect(accessible.describe(r'\binom{n}{r}'), contains('n choose r'));
    expect(accessible.describe(r'a\mid b'), contains('divides'));
    expect(accessible.describe(r'x\mapsto x^2'), contains('maps to'));
    expect(accessible.describe(r'\overline{z}'), contains('overline'));
  });

  test('legacy/raw insertion registry covers new structured commands', () {
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\binom{}{}'],
      same(MathEditCommands.binomial),
    );
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\pmod{}'],
      same(MathEditCommands.modulo),
    );
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\bigcup_{}^{}'],
      same(MathEditCommands.bigUnionWithLimits),
    );
    expect(
      MathLegacyEditCommandRegistry.bySource[r'\overline{}'],
      same(MathEditCommands.emptyOverline),
    );
  });
}
