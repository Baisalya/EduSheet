import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_node_ref.dart';
import 'package:edusheet/features/teaching_planner/presentation/services/syllabus_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9);
  final workspace = TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class',
        name: 'Class 10',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'subject',
        classId: 'class',
        name: 'Math',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    units: [
      PlannerUnit(
        id: 'unit',
        subjectId: 'subject',
        title: 'Unit',
        sortOrder: 0,
        plannedPeriods: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-in-unit',
        subjectId: 'subject',
        unitId: 'unit',
        title: 'Chapter A',
        sortOrder: 0,
        plannedPeriods: 1,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerChapter(
        id: 'chapter-root',
        subjectId: 'subject',
        title: 'Chapter B',
        sortOrder: 1,
        plannedPeriods: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic',
        chapterId: 'chapter-in-unit',
        title: 'Topic',
        sortOrder: 0,
        plannedPeriods: 1,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  test('compact hierarchy parent path is deterministic', () {
    expect(
      SyllabusNavigationPolicy.parentOf(
        workspace,
        const SyllabusNodeRef.topic(
          classId: 'class',
          subjectId: 'subject',
          unitId: 'unit',
          chapterId: 'chapter-in-unit',
          topicId: 'topic',
        ),
      ),
      const SyllabusNodeRef.chapter(
        classId: 'class',
        subjectId: 'subject',
        unitId: 'unit',
        chapterId: 'chapter-in-unit',
      ),
    );

    expect(
      SyllabusNavigationPolicy.parentOf(
        workspace,
        const SyllabusNodeRef.chapter(
          classId: 'class',
          subjectId: 'subject',
          unitId: 'unit',
          chapterId: 'chapter-in-unit',
        ),
      ),
      const SyllabusNodeRef.unit(
        classId: 'class',
        subjectId: 'subject',
        unitId: 'unit',
      ),
    );

    expect(
      SyllabusNavigationPolicy.parentOf(
        workspace,
        const SyllabusNodeRef.chapter(
          classId: 'class',
          subjectId: 'subject',
          chapterId: 'chapter-root',
        ),
      ),
      const SyllabusNodeRef.subject(classId: 'class', subjectId: 'subject'),
    );
  });

  test('selection validation rejects missing or archived nodes', () {
    expect(
      SyllabusNavigationPolicy.validatedSelection(
        workspace,
        const SyllabusNodeRef.subject(classId: 'class', subjectId: 'subject'),
      ),
      isNotNull,
    );

    expect(
      SyllabusNavigationPolicy.validatedSelection(
        workspace,
        const SyllabusNodeRef.subject(classId: 'class', subjectId: 'missing'),
      ),
      isNull,
    );

    final archivedWorkspace = workspace.copyWith(
      subjects: [workspace.subjects.single.copyWith(archivedAt: now)],
    );
    expect(
      SyllabusNavigationPolicy.validatedSelection(
        archivedWorkspace,
        const SyllabusNodeRef.subject(classId: 'class', subjectId: 'subject'),
      ),
      isNull,
    );
  });
}
