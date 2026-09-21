import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_hierarchy_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('syllabus hero exposes move and duplicate as distinct actions', (
    tester,
  ) async {
    var moved = false;
    var duplicated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: SyllabusEntityHero(
              icon: Icons.menu_book_rounded,
              eyebrow: 'SUBJECT',
              title: 'Mathematics',
              subtitle: 'Class 8',
              metrics: const [],
              onEdit: () {},
              onAttach: () {},
              onMove: () => moved = true,
              onDuplicate: () => duplicated = true,
              onArchive: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Syllabus actions'));
    await tester.pumpAndSettle();
    expect(find.text('Move to…'), findsOneWidget);
    expect(find.text('Duplicate structure'), findsOneWidget);

    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    expect(moved, isTrue);

    await tester.tap(find.byTooltip('Syllabus actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate structure'));
    await tester.pumpAndSettle();
    expect(duplicated, isTrue);
  });
}
