import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_chapter_progress.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_entity_sheet.dart';
import 'package:edusheet/features/teaching_planner/presentation/widgets/syllabus_hierarchy_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21);

  TeachingPlannerWorkspace workspace() => TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-8',
        name: 'Class 8',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'math',
        classId: 'class-8',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    units: [
      PlannerUnit(
        id: 'algebra',
        subjectId: 'math',
        title: 'Algebra',
        sortOrder: 0,
        plannedPeriods: 0,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerUnit(
        id: 'geometry',
        subjectId: 'math',
        title: 'Geometry',
        sortOrder: 1,
        plannedPeriods: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'linear',
        subjectId: 'math',
        unitId: 'algebra',
        title: 'Linear Equations',
        sortOrder: 0,
        plannedPeriods: 0,
        status: TeachingProgressStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerChapter(
        id: 'polynomials',
        subjectId: 'math',
        unitId: 'algebra',
        title: 'Polynomials',
        sortOrder: 1,
        plannedPeriods: 0,
        status: TeachingProgressStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerChapter(
        id: 'triangles',
        subjectId: 'math',
        unitId: 'geometry',
        title: 'Triangles',
        sortOrder: 0,
        plannedPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  test('chapter completion rolls up automatically to unit subject and class', () {
    final value = workspace();
    final algebra = SyllabusChapterProgress.forUnit(value, 'algebra');
    final subject = SyllabusChapterProgress.forSubject(value, 'math');
    final classProgress = SyllabusChapterProgress.forClass(value, 'class-8');

    expect(algebra.totalChapters, 2);
    expect(algebra.completedChapters, 1);
    expect(algebra.inProgressChapters, 1);
    expect(algebra.completionPercent, 50);
    expect(algebra.rollupStatus, TeachingProgressStatus.inProgress);

    expect(subject.totalChapters, 3);
    expect(subject.completedChapters, 1);
    expect(subject.completionPercent, 33);
    expect(classProgress.totalChapters, 3);
    expect(classProgress.completedChapters, 1);
  });

  testWidgets('chapter card exposes traditional quick actions', (tester) async {
    var planned = false;
    var completed = false;
    var edited = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyllabusHierarchyCard(
            icon: Icons.article_outlined,
            title: 'Linear Equations',
            subtitle: 'In progress',
            status: TeachingProgressStatus.inProgress,
            completion: .5,
            onTap: () {},
            onStatusToggle: () => completed = true,
            statusToggleTooltip: 'Mark chapter complete',
            actions: [
              SyllabusCardAction(
                id: 'plan',
                label: 'Plan lesson',
                icon: Icons.event_note_rounded,
                onSelected: () => planned = true,
              ),
              SyllabusCardAction(
                id: 'complete',
                label: 'Mark complete',
                icon: Icons.task_alt_rounded,
                onSelected: () => completed = true,
              ),
              SyllabusCardAction(
                id: 'edit',
                label: 'Edit',
                icon: Icons.edit_outlined,
                onSelected: () => edited = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Teaching'), findsOneWidget);
    expect(find.byTooltip('Mark chapter complete'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark chapter complete'));
    await tester.pump();
    expect(completed, isTrue);
    completed = false;

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Plan lesson'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(planned, isFalse);
    expect(edited, isFalse);
  });

  testWidgets('new chapter keeps advanced planning details collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SyllabusEntitySheet(
            requestedKind: SyllabusEntityKind.chapter,
            subjectId: 'math',
          ),
        ),
      ),
    );

    expect(find.text('Chapter title'), findsOneWidget);
    expect(find.text('Planning details (optional)'), findsOneWidget);
    expect(find.text('Planned periods'), findsNothing);

    await tester.tap(find.text('Planning details (optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Planned periods'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Unit (optional)'), findsOneWidget);
  });
}
