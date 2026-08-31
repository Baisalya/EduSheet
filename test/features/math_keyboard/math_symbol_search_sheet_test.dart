import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_provider.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_symbol_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('teacher search promotes plain-language math discovery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MathSymbol? selected;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 820,
              height: 720,
              child: MathSymbolSearchSheet(
                categoryLabel: (category) => category.name.toUpperCase(),
                onSelected: (symbol) => selected = symbol,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find math quickly'), findsOneWidget);
    expect(find.text('Fraction'), findsOneWidget);
    expect(find.text('Square root'), findsOneWidget);

    await tester.tap(find.text('Fraction'));
    await tester.pumpAndSettle();

    expect(find.text('fraction with numerator and denominator'), findsWidgets);
    expect(find.text('Structure'), findsWidgets);

    final resultLabel = find
        .text('fraction with numerator and denominator')
        .first;
    await tester.tap(resultLabel);
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.tex, r'\frac{}{}');
  });

  testWidgets('search results can be favourited without inserting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 820,
              height: 720,
              child: MathSymbolSearchSheet(
                categoryLabel: (category) => category.name.toUpperCase(),
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Square root'));
    await tester.pumpAndSettle();

    final addFavourite = find.byTooltip('Add to favourites').first;
    await tester.tap(addFavourite);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MathSymbolSearchSheet));
    final container = ProviderScope.containerOf(context, listen: false);
    final favorites = container.read(favoriteSymbolsProvider);

    expect(favorites, isNotEmpty);
    expect(find.byTooltip('Remove from favourites'), findsWidgets);
  });

  testWidgets('teacher search remains usable at 320px and two-times text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
            child: child!,
          ),
          home: Scaffold(
            body: MathSymbolSearchSheet(
              categoryLabel: (category) => category.name.toUpperCase(),
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find math quickly'), findsOneWidget);
    expect(find.text('Fraction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
