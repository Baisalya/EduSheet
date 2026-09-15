import 'package:edusheet/features/teaching_planner/application/lesson_schedule_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const schedule = LessonScheduleService();
  final now = DateTime.utc(2026, 9, 8);

  LessonPlan lesson(String id, int? start) => LessonPlan(
    id: id,
    classId: 'c',
    subjectId: 's',
    chapterId: 'h',
    title: 'Lesson $id',
    plannedDate: DateTime.utc(2026, 9, 10),
    plannedPeriods: 2,
    startPeriod: start,
    objective: 'Learn',
    createdAt: now,
    updatedAt: now,
  );

  TeachingPlannerWorkspace workspace(List<LessonPlan> lessons) =>
      TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'c',
            name: 'Class 10',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        subjects: [
          PlannerSubject(
            id: 's',
            classId: 'c',
            name: 'Math',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        chapters: [
          PlannerChapter(
            id: 'h',
            subjectId: 's',
            title: 'Numbers',
            sortOrder: 0,
            plannedPeriods: 4,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        lessonPlans: lessons,
      );

  test('unslotted lessons never create artificial conflicts', () {
    expect(
      schedule.conflicts(workspace([lesson('a', null), lesson('b', null)])),
      isEmpty,
    );
  });

  test('overlapping period ranges for same class and day are conflicts', () {
    final result = schedule.conflicts(
      workspace([lesson('a', 2), lesson('b', 3)]),
    );
    expect(result, hasLength(1));
    expect(result.single.firstLessonId, 'a');
    expect(result.single.secondLessonId, 'b');
  });

  test('non-overlapping period ranges are allowed', () {
    expect(
      schedule.conflicts(workspace([lesson('a', 1), lesson('b', 3)])),
      isEmpty,
    );
  });
}
