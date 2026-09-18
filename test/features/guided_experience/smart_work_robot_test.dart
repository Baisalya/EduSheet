import 'package:edusheet/features/guided_experience/presentation/widgets/smart_work_robot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('robot animation plays once and settles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SmartWorkRobot()),
        ),
      ),
    );

    expect(find.byType(SmartWorkRobot), findsOneWidget);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(SmartWorkRobot), findsOneWidget);
  });

  testWidgets('reduced motion uses a static robot icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: SmartWorkRobot()),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
  });
}
