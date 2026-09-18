import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/weekly_planner_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 1);

  TeachingPlannerWorkspace workspace(List<LessonPlan> lessons) =>
      TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'c',
            name: 'Class 10',
            sortOrder: 0,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
        subjects: [
          PlannerSubject(
            id: 's',
            classId: 'c',
            name: 'Mathematics',
            sortOrder: 0,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
        chapters: [
          PlannerChapter(
            id: 'h',
            subjectId: 's',
            title: 'Algebra',
            sortOrder: 0,
            plannedPeriods: 8,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
        lessonPlans: lessons,
      );

  LessonPlan lesson({
    required String id,
    required DateTime date,
    required int periods,
    int? startPeriod,
    TeachingProgressStatus status = TeachingProgressStatus.planned,
  }) => LessonPlan(
    id: id,
    classId: 'c',
    subjectId: 's',
    chapterId: 'h',
    title: 'Lesson $id',
    plannedDate: date,
    plannedPeriods: periods,
    startPeriod: startPeriod,
    objective: 'Teach algebra',
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  test('builds a Monday-to-Sunday week with real lesson totals', () {
    final model = WeeklyPlannerModel.fromWorkspace(
      workspace([
        lesson(
          id: 'a',
          date: DateTime(2026, 9, 14),
          periods: 2,
          startPeriod: 1,
          status: TeachingProgressStatus.completed,
        ),
        lesson(id: 'b', date: DateTime(2026, 9, 16), periods: 1),
      ]),
      DateTime(2026, 9, 15),
    );

    expect(model.weekStart, DateTime(2026, 9, 14));
    expect(model.weekEnd, DateTime(2026, 9, 20));
    expect(model.days, hasLength(7));
    expect(model.totalLessons, 2);
    expect(model.completedLessons, 1);
    expect(model.plannedPeriods, 3);
    expect(model.slottedLessons, 1);
    expect(model.completionRatio, .5);
    expect(model.days.first.lessonCount, 1);
    expect(model.days[2].lessonCount, 1);
  });

  test('resolves real hierarchy labels for agenda cards', () {
    final model = WeeklyPlannerModel.fromWorkspace(
      workspace([
        lesson(
          id: 'a',
          date: DateTime(2026, 9, 15),
          periods: 1,
          startPeriod: 3,
        ),
      ]),
      DateTime(2026, 9, 15),
    );

    final item = model.dayFor(DateTime(2026, 9, 15)).lessons.single;
    expect(item.className, 'Class 10');
    expect(item.subjectName, 'Mathematics');
    expect(item.chapterTitle, 'Algebra');
    expect(item.hasConflict, isFalse);
  });

  test('marks both overlapping same-class lessons as conflicts', () {
    final model = WeeklyPlannerModel.fromWorkspace(
      workspace([
        lesson(
          id: 'a',
          date: DateTime(2026, 9, 15),
          periods: 2,
          startPeriod: 2,
        ),
        lesson(
          id: 'b',
          date: DateTime(2026, 9, 15),
          periods: 2,
          startPeriod: 3,
        ),
      ]),
      DateTime(2026, 9, 15),
    );

    expect(model.conflictLessonCount, 2);
    expect(
      model
          .dayFor(DateTime(2026, 9, 15))
          .lessons
          .every((item) => item.hasConflict),
      isTrue,
    );
  });
}
