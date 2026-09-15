import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/services/teaching_planner_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);

  test('valid normalized hierarchy passes integrity validation', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-10',
          name: 'Class 10',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      subjects: [
        PlannerSubject(
          id: 'math',
          classId: 'class-10',
          name: 'Mathematics',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      units: [
        PlannerUnit(
          id: 'unit-1',
          subjectId: 'math',
          title: 'Number Systems',
          sortOrder: 0,
          plannedPeriods: 8,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      chapters: [
        PlannerChapter(
          id: 'real-numbers',
          subjectId: 'math',
          unitId: 'unit-1',
          title: 'Real Numbers',
          sortOrder: 0,
          plannedPeriods: 6,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      topics: [
        PlannerTopic(
          id: 'euclid',
          chapterId: 'real-numbers',
          title: 'Euclid Division Lemma',
          sortOrder: 0,
          plannedPeriods: 2,
          actualPeriods: 0,
          status: TeachingProgressStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(TeachingPlannerIntegrity.validate(workspace), isEmpty);
  });

  test('missing parent is rejected instead of silently dropping data', () {
    final workspace = TeachingPlannerWorkspace(
      topics: [
        PlannerTopic(
          id: 'orphan-topic',
          chapterId: 'missing-chapter',
          title: 'Orphan',
          sortOrder: 0,
          plannedPeriods: 1,
          actualPeriods: 0,
          status: TeachingProgressStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final issues = TeachingPlannerIntegrity.validate(workspace);
    expect(issues.map((issue) => issue.code), contains('missing_parent'));
    expect(
      () => TeachingPlannerIntegrity.validateOrThrow(workspace),
      throwsA(isA<TeachingPlannerIntegrityException>()),
    );
  });

  test('active child under archived parent is rejected', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'archived-class',
          name: 'Class 8',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          archivedAt: now,
        ),
      ],
      subjects: [
        PlannerSubject(
          id: 'active-subject',
          classId: 'archived-class',
          name: 'Science',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(
      TeachingPlannerIntegrity.validate(workspace).map((issue) => issue.code),
      contains('active_child_of_archived_parent'),
    );
  });
}
