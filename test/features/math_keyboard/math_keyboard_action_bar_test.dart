import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'medium width keeps the teacher-critical Next box label visible',
    (tester) async {
      tester.view.physicalSize = const Size(480, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 480,
                  child: MathKeyboardActionBar(compact: true),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Next box'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow action bar remains accessible at two-times text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 320,
                  child: MathKeyboardActionBar(compact: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Next box'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Move typing position left'))
          .label,
      'Move typing position left',
    );
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              'Move to the next fraction, power, root, or formula box',
            ),
          )
          .label,
      'Move to the next fraction, power, root, or formula box',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
