import 'package:edusheet/features/guided_experience/demo/demo_mode_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo banner clearly warns that real data is not changed', (
    tester,
  ) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DemoModeBanner(
            label: 'Create Paper',
            onExit: () => exited = true,
          ),
        ),
      ),
    );

    expect(find.text('Demo Mode · Create Paper'), findsOneWidget);
    expect(
      find.text('Your real EduSheet data will not be changed.'),
      findsOneWidget,
    );
    expect(find.text('Exit Demo'), findsOneWidget);

    await tester.tap(find.text('Exit Demo'));
    expect(exited, isTrue);
  });
}
