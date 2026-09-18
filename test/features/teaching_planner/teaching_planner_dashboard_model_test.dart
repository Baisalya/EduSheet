import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/teaching_planner_dashboard_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard derives real progress and schedule from existing workspace',
    () {
      final now = DateTime(2026, 9, 15, 9);
      final created = DateTime(2026, 1, 1);
      final workspace = TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'class-1',
            name: 'Class 10',
            academicYear: '2026–27',
            sortOrder: 0,
            createdAt: created,
            updatedAt: created,
          ),
        ],
        subjects: [
          PlannerSubject(
            id: 'subject-1',
            classId: 'class-1',
            name: 'Mathematics',
            sortOrder: 0,
            createdAt: created,
            updatedAt: created,
          ),
        ],
        topics: [
          PlannerTopic(
            id: 'topic-1',
            chapterId: 'chapter-1',
            title: 'Topic 1',
            sortOrder: 0,
            plannedPeriods: 1,
            actualPeriods: 1,
            status: TeachingProgressStatus.completed,
            createdAt: created,
            updatedAt: created,
          ),
          PlannerTopic(
            id: 'topic-2',
            chapterId: 'chapter-1',
            title: 'Topic 2',
            sortOrder: 1,
            plannedPeriods: 1,
            actualPeriods: 0,
            status: TeachingProgressStatus.planned,
            createdAt: created,
            updatedAt: created,
          ),
        ],
        lessonPlans: [
          LessonPlan(
            id: 'lesson-today',
            classId: 'class-1',
            subjectId: 'subject-1',
            chapterId: 'chapter-1',
            title: 'Quadratic equations',
            plannedDate: DateTime(2026, 9, 15),
            plannedPeriods: 2,
            startPeriod: 3,
            objective: 'Teach quadratic equations',
            createdAt: created,
            updatedAt: created,
          ),
          LessonPlan(
            id: 'lesson-overdue',
            classId: 'class-1',
            subjectId: 'subject-1',
            chapterId: 'chapter-1',
            title: 'Earlier lesson',
            plannedDate: DateTime(2026, 9, 14),
            plannedPeriods: 1,
            objective: 'Earlier objective',
            createdAt: created,
            updatedAt: created,
          ),
        ],
      );

      final model = TeachingPlannerDashboardModel.fromWorkspace(
        workspace,
        TeachingPlannerCapabilities.free(),
        now: now,
      );

      expect(model.classCount, 1);
      expect(model.subjectCount, 1);
      expect(model.topicCount, 2);
      expect(model.lessonCount, 2);
      expect(model.overallCompletion, 0.5);
      expect(model.overallCompletionLabel, 'Topics complete');
      expect(model.pendingTopics, 1);
      expect(model.insights.overdueLessons, 1);
      expect(model.todayLessons, hasLength(1));
      expect(model.todayLessons.single.className, 'Class 10');
      expect(model.todayLessons.single.subjectName, 'Mathematics');
      expect(model.todayLessons.single.periodLabel, 'Periods 3–4');
      expect(model.nextLesson?.id, 'lesson-today');
      expect(model.classes.single.subjectCount, 1);
    },
  );

  test('dashboard falls back to lesson completion when no topics exist', () {
    final created = DateTime(2026, 1, 1);
    final workspace = TeachingPlannerWorkspace(
      lessonPlans: [
        LessonPlan(
          id: 'done',
          classId: 'class-1',
          subjectId: 'subject-1',
          chapterId: 'chapter-1',
          title: 'Completed lesson',
          plannedDate: DateTime(2026, 9, 10),
          plannedPeriods: 1,
          objective: 'Objective',
          status: TeachingProgressStatus.completed,
          createdAt: created,
          updatedAt: created,
        ),
      ],
    );

    final model = TeachingPlannerDashboardModel.fromWorkspace(
      workspace,
      TeachingPlannerCapabilities.pro(),
      now: DateTime(2026, 9, 15),
    );

    expect(model.overallCompletion, 1);
    expect(model.overallCompletionLabel, 'Lessons complete');
    expect(model.accessLabel, 'Pro');
  });
}
