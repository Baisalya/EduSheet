import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edusheet/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:edusheet/features/calculator/presentation/widgets/formula_catalog_sheet.dart';

void main() {
  Future<ProviderContainer> pumpFormulaCatalog(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 700));
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 680,
                height: 620,
                child: FormulaCatalogSheet(dialogMode: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'formula selection opens variable solver instead of raw insertion',
    (tester) async {
      final container = await pumpFormulaCatalog(tester);
      addTearDown(container.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.tap(
        find.byKey(const ValueKey("formula-tile-Newton's Second Law")),
      );
      await tester.pump();

      expect(find.text('Calculate Force (F)'), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-input-m')), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-input-a')), findsOneWidget);
      expect(container.read(calculatorProvider).equation, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('formula-input-m')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('formula-input-a')),
        '3',
      );
      await tester.tap(find.byKey(const ValueKey('formula-solver-calculate')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('formula-solver-result')),
        findsOneWidget,
      );
      expect(find.text('F = 6 N'), findsOneWidget);
      expect(container.read(calculatorProvider).equation, isEmpty);
    },
  );

  testWidgets('solver shows field validation and keeps calculator unchanged', (
    tester,
  ) async {
    final container = await pumpFormulaCatalog(tester);
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.tap(
      find.byKey(const ValueKey("formula-tile-Newton's Second Law")),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('formula-input-m')), '2');
    await tester.tap(find.byKey(const ValueKey('formula-solver-calculate')));
    await tester.pump();

    expect(find.text('Enter acceleration.'), findsOneWidget);
    expect(find.byKey(const ValueKey('formula-solver-result')), findsNothing);
    expect(container.read(calculatorProvider).equation, isEmpty);
  });

  testWidgets('solved result can be inserted into the main calculator', (
    tester,
  ) async {
    final container = await pumpFormulaCatalog(tester);
    addTearDown(container.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.tap(
      find.byKey(const ValueKey("formula-tile-Newton's Second Law")),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('formula-input-m')), '2');
    await tester.enterText(find.byKey(const ValueKey('formula-input-a')), '3');
    await tester.tap(find.byKey(const ValueKey('formula-solver-calculate')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('formula-solver-insert-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert result'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(container.read(calculatorProvider).equation, '6');
  });
}
