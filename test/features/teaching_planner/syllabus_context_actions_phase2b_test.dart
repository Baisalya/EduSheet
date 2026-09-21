import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_hierarchy_cards.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long press exposes the same syllabus card actions on touch', (
    tester,
  ) async {
    var moved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusHierarchyCard(
            icon: Icons.article_outlined,
            title: 'Linear Equations',
            subtitle: 'Algebra',
            onTap: () {},
            actions: [
              SyllabusCardAction(
                id: 'move',
                label: 'Move to…',
                icon: Icons.drive_file_move_outline,
                onSelected: () => moved = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Linear Equations'));
    await tester.pumpAndSettle();
    expect(find.text('Move to…'), findsOneWidget);
    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    expect(moved, isTrue);
  });

  testWidgets('secondary click exposes syllabus card actions on desktop', (
    tester,
  ) async {
    var trashed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              child: SyllabusHierarchyCard(
                icon: Icons.article_outlined,
                title: 'Motion',
                subtitle: 'Science',
                onTap: () {},
                actions: [
                  SyllabusCardAction(
                    id: 'trash',
                    label: 'Move to Trash',
                    icon: Icons.delete_outline_rounded,
                    onSelected: () => trashed = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.text('Motion'),
      buttons: kSecondaryMouseButton,
      warnIfMissed: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Move to Trash'), findsOneWidget);
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    expect(trashed, isTrue);
  });
}
