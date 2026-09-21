import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_hierarchy_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('syllabus actions keep Archive separate from Move to Trash', (
    tester,
  ) async {
    var archived = false;
    var trashed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusEntityHero(
            icon: Icons.school_rounded,
            eyebrow: 'CLASS SYLLABUS',
            title: 'Class 8',
            subtitle: '2026-27',
            metrics: const [],
            onAttach: () {},
            onArchive: () => archived = true,
            onDelete: () => trashed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Syllabus actions'));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);

    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();

    expect(trashed, isTrue);
    expect(archived, isFalse);
  });
}
