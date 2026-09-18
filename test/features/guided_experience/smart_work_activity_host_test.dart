import 'package:edusheet/features/guided_experience/application/smart_work_activity_controller.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/smart_work_activity_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pointer interaction resets the app-wide idle clock', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var taps = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SmartWorkActivityHost(
            child: Scaffold(
              body: TextButton(
                onPressed: () => taps += 1,
                child: const Text('Work'),
              ),
            ),
          ),
        ),
      ),
    );

    final before = container.read(smartWorkActivityControllerProvider).revision;
    await tester.tap(find.text('Work'));
    await tester.pump();

    expect(taps, 1);
    expect(
      container.read(smartWorkActivityControllerProvider).revision,
      greaterThan(before),
    );
  });

  testWidgets(
    'pointer down is never suppressed by the noisy-event throttle',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SmartWorkActivityHost(
              child: Scaffold(
                body: TextField(),
              ),
            ),
          ),
        ),
      );

      // A focus change is intentionally recorded first. The immediately
      // following pointer down must still count as deliberate user activity.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final before =
          container.read(smartWorkActivityControllerProvider).revision;

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(
        container.read(smartWorkActivityControllerProvider).revision,
        greaterThan(before),
      );
    },
  );


  testWidgets(
    'layout-time scroll notifications defer provider updates until after frame',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SmartWorkActivityHost(
              child: Scaffold(
                body: SizedBox(
                  height: 120,
                  child: ListView(
                    children: const [
                      SizedBox(height: 500),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final before =
          container.read(smartWorkActivityControllerProvider).revision;
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        container.read(smartWorkActivityControllerProvider).revision,
        greaterThan(before),
      );
    },
  );

}
