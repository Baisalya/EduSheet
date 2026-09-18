import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_overview_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15);
  final workspace = TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        academicYear: '2026-27',
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
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'math',
        unitId: 'unit-1',
        title: 'Real Numbers',
        sortOrder: 0,
        plannedPeriods: 6,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: 'Euclid Division Lemma',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 2,
        status: TeachingProgressStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 'topic-2',
        chapterId: 'chapter-1',
        title: 'Fundamental Theorem',
        sortOrder: 1,
        plannedPeriods: 3,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  test('class overview is derived from active syllabus hierarchy', () {
    final metrics = SyllabusOverviewModel.forClass(workspace, 'class-10');

    expect(metrics.subjects, 1);
    expect(metrics.units, 1);
    expect(metrics.chapters, 1);
    expect(metrics.topics, 2);
    expect(metrics.completedTopics, 1);
    expect(metrics.plannedPeriods, 5);
    expect(metrics.completionPercent, 50);
  });

  test('subject and chapter overview use real topic progress', () {
    final subject = SyllabusOverviewModel.forSubject(workspace, 'math');
    final chapter = SyllabusOverviewModel.forChapter(workspace, 'chapter-1');

    expect(subject.chapters, 1);
    expect(subject.topics, 2);
    expect(subject.completionPercent, 50);
    expect(chapter.topics, 2);
    expect(chapter.completedTopics, 1);
    expect(chapter.plannedPeriods, 6);
  });

  test('unknown unit or chapter returns an empty overview', () {
    expect(SyllabusOverviewModel.forUnit(workspace, 'missing').topics, 0);
    expect(SyllabusOverviewModel.forChapter(workspace, 'missing').topics, 0);
  });
}
