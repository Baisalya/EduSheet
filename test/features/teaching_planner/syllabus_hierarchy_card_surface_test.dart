import 'package:edusheet/features/teaching_planner/presentation/design/teaching_planner_design_system.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_hierarchy_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hierarchy card keeps the surface opaque and the day-theme shadow subtle',
    (tester) async {
      final theme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      );
      const cardKey = ValueKey('hierarchy-card-under-test');

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SyllabusHierarchyCard(
              key: cardKey,
              icon: Icons.menu_book_outlined,
              title: 'Mathematics',
              subtitle: '0 chapters • 0 topics',
              dragHandle: const Icon(Icons.drag_indicator_rounded),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(cardKey);
      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: card, matching: find.byType(DecoratedBox)),
      );
      final shadowHost = decoratedBoxes.firstWhere((widget) {
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            (decoration.boxShadow?.isNotEmpty ?? false);
      });
      final shadowDecoration = shadowHost.decoration as BoxDecoration;
      final shadow = shadowDecoration.boxShadow!.single;

      expect(shadow.color, TeachingPlannerColors.fromTheme(theme).shadow);
      expect(shadow.color.a, lessThan(0.1));

      final materials = tester.widgetList<Material>(
        find.descendant(of: card, matching: find.byType(Material)),
      );
      final surface = materials.first;
      expect(surface.color, TeachingPlannerColors.fromTheme(theme).surface);
      expect(surface.clipBehavior, Clip.antiAlias);

      final containers = tester.widgetList<Container>(
        find.descendant(of: card, matching: find.byType(Container)),
      );
      final transparentShadowContainers = containers.where((widget) {
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            (decoration.boxShadow?.isNotEmpty ?? false);
      });
      expect(transparentShadowContainers, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
