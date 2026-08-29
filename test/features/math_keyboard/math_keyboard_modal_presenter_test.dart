import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_interaction_region.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_modal_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keyboard panels stay on the keyboard nested Navigator', (
    tester,
  ) async {
    final rootKey = GlobalKey<NavigatorState>();
    final keyboardKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootKey,
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 360,
            child: MathKeyboardInteractionRegion(
              child: Navigator(
                key: keyboardKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Center(
                    child: FilledButton(
                      onPressed: () => showMathKeyboardPanel<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (panelContext) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton(
                            onPressed: () => Navigator.pop(panelContext),
                            child: const Text('Close keyboard panel'),
                          ),
                        ),
                      ),
                      child: const Text('Open keyboard panel'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open keyboard panel'));
    await tester.pumpAndSettle();

    expect(find.text('Close keyboard panel'), findsOneWidget);
    expect(rootKey.currentState!.canPop(), isFalse);
    expect(keyboardKey.currentState!.canPop(), isTrue);

    await tester.tap(find.text('Close keyboard panel'));
    await tester.pumpAndSettle();

    expect(keyboardKey.currentState!.canPop(), isFalse);
  });
}
