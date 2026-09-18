import 'package:edusheet/features/teaching_planner/presentation/design/teaching_planner_design_system.dart';
import 'package:edusheet/features/teaching_planner/presentation/navigation/teaching_planner_navigation.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/teaching_planner_page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner inherits parent brightness, surfaces and workspace accent', () {
    final lightParent = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      scaffoldBackgroundColor: const Color(0xFFF4F8F5),
    );
    final darkParent = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101314),
    );

    final light = TeachingPlannerTheme.resolve(lightParent);
    final dark = TeachingPlannerTheme.resolve(darkParent);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      light.extension<TeachingPlannerColors>()?.primary,
      lightParent.colorScheme.primary,
    );
    expect(
      dark.extension<TeachingPlannerColors>()?.primary,
      darkParent.colorScheme.primary,
    );
    expect(
      light.extension<TeachingPlannerColors>()?.canvas,
      lightParent.scaffoldBackgroundColor,
    );
  });

  testWidgets('page shell scopes planner theme without mutating parent theme', (
    tester,
  ) async {
    final parent = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    );
    Color? parentPrimary;
    Color? plannerPrimary;

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: parent,
        home: Builder(
          builder: (context) {
            parentPrimary = Theme.of(context).colorScheme.primary;
            return TeachingPlannerPageShell(
              title: 'Progress & Insights',
              currentDestination: TeachingPlannerDestination.progress,
              body: Builder(
                builder: (context) {
                  plannerPrimary = Theme.of(context).colorScheme.primary;
                  return const Center(child: Text('Planner body'));
                },
              ),
            );
          },
        ),
      ),
    );

    expect(parentPrimary, parent.colorScheme.primary);
    expect(plannerPrimary, parentPrimary);
    expect(find.text('Planner body'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
