import 'package:edusheet/features/teaching_planner/presentation/navigation/teaching_planner_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_home_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact shell uses bottom navigation and selected destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: TeachingPlannerPageShell(
          title: 'Progress & Insights',
          currentDestination: TeachingPlannerDestination.progress,
          body: Center(child: Text('Progress body')),
        ),
      ),
    );

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
    expect(find.byType(TeachingPlannerAdaptiveNavigationRail), findsNothing);
    expect(find.text('Progress body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide shell uses rail and lessons map to planner destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: TeachingPlannerPageShell(
          title: 'Lesson Planner',
          currentDestination: TeachingPlannerDestination.lessons,
          body: Center(child: Text('Lessons body')),
        ),
      ),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1);
    expect(find.byType(TeachingPlannerAdaptiveNavigationBar), findsNothing);
    expect(find.text('Lessons body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global navigation can be disabled for guided flows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TeachingPlannerPageShell(
          title: 'Guided syllabus',
          currentDestination: TeachingPlannerDestination.syllabus,
          showGlobalNavigation: false,
          body: Center(child: Text('Guided body')),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Guided body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
