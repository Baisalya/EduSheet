import 'package:edusheet/features/math_keyboard/domain/catalog/math_symbol_catalog.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_wrapper.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    '320px keyboard remains usable at two-times text scale including Build',
    (tester) async {
      tester.view.physicalSize = const Size(320, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(body: MathKeyboardView()),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Build a math structure'), findsOneWidget);
      final resizeNode = tester.getSemantics(
        find.bySemanticsLabel('Resize math keyboard'),
      );
      expect(
        resizeNode,
        isSemantics(
          label: 'Resize math keyboard',
          value: '320 pixels',
          increasedValue: '360 pixels',
          decreasedValue: '280 pixels',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('math-build-button')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Build math faster'), findsOneWidget);

      final fraction = MathSymbolCatalog.findByTex(r'\frac{}{}');
      expect(fraction, isNotNull);
      final fractionCard = find.byKey(ValueKey('math-build-${fraction!.id}'));
      final structureBrowser = find.byKey(
        const ValueKey('math-structure-browser'),
      );

      // At 320x520 with 2x text scaling the first structure card starts below
      // the initial Build viewport. Scroll the real local panel until the
      // canonical fraction card is rendered and physically visible before
      // asserting its semantics and adaptive height.
      await tester.dragUntilVisible(
        fractionCard,
        structureBrowser,
        const Offset(0, -120),
      );
      await tester.pump();

      expect(fractionCard, findsOneWidget);
      // GridView owns each child's merged semantics through IndexedSemantics,
      // so assert the visible accessibility label directly rather than using
      // a widget-descendant relationship that does not exist in the render
      // semantics tree.
      expect(find.bySemanticsLabel('Insert Fraction'), findsOneWidget);
      expect(tester.getSize(fractionCard).height, greaterThanOrEqualTo(100));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    '320px formula editor remains usable with two-times text and keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: MathKeyboardWrapper(child: child!),
            ),
            home: const Scaffold(
              body: FormulaEditorSheet(
                initial: MathExpression(
                  id: 'extreme-editor',
                  latex: 'x',
                  plainText: 'x',
                ),
                autoOpenMathKeyboard: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit math formula'), findsOneWidget);
      final buildButton = find.byKey(const ValueKey('math-build-button'));
      expect(buildButton, findsOneWidget);

      await tester.tap(buildButton);
      await tester.pump(const Duration(milliseconds: 200));

      final structureBrowser = find.byKey(
        const ValueKey('math-structure-browser'),
      );
      final pythagoras = find.text('Pythagoras');
      await tester.dragUntilVisible(
        pythagoras,
        structureBrowser,
        const Offset(0, -160),
      );
      expect(pythagoras, findsOneWidget);

      final editorScroll = find.byKey(
        const ValueKey('formula-editor-scrollable-layout'),
      );
      final saveFormula = find.text('Save formula');
      await tester.dragUntilVisible(
        saveFormula,
        editorScroll,
        const Offset(0, -160),
      );
      expect(tester.getCenter(saveFormula).dy, lessThan(200));
      expect(tester.takeException(), isNull);
    },
  );
}
