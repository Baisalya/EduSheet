import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/progress_insights_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15);
  final workspace = TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'c1',
        name: 'Class 10',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerClass(
        id: 'c2',
        name: 'Class 9',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 's1',
        classId: 'c1',
        name: 'Math',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerSubject(
        id: 's2',
        classId: 'c2',
        name: 'Science',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'h1',
        subjectId: 's1',
        title: 'Algebra',
        sortOrder: 0,
        plannedPeriods: 4,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerChapter(
        id: 'h2',
        subjectId: 's2',
        title: 'Motion',
        sortOrder: 0,
        plannedPeriods: 3,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 't1',
        chapterId: 'h1',
        title: 'Linear equations',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 2,
        priority: PlannerPriority.high,
        status: TeachingProgressStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 't2',
        chapterId: 'h1',
        title: 'Polynomials',
        sortOrder: 1,
        plannedPeriods: 2,
        actualPeriods: 0,
        priority: PlannerPriority.high,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 't3',
        chapterId: 'h2',
        title: 'Velocity',
        sortOrder: 0,
        plannedPeriods: 3,
        actualPeriods: 1,
        status: TeachingProgressStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'l1',
        classId: 'c1',
        subjectId: 's1',
        chapterId: 'h1',
        topicIds: const ['t1'],
        title: 'Completed algebra',
        plannedDate: DateTime.utc(2026, 9, 14),
        plannedPeriods: 2,
        actualPeriods: 2,
        objective: 'Complete equations',
        status: TeachingProgressStatus.completed,
        taughtAt: DateTime.utc(2026, 9, 14),
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'l2',
        classId: 'c1',
        subjectId: 's1',
        chapterId: 'h1',
        topicIds: const ['t2'],
        title: 'Overdue algebra',
        plannedDate: DateTime.utc(2026, 9, 13),
        plannedPeriods: 2,
        actualPeriods: 0,
        objective: 'Teach polynomials',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'l3',
        classId: 'c1',
        subjectId: 's1',
        chapterId: 'h1',
        topicIds: const ['t2'],
        title: 'Upcoming algebra',
        plannedDate: DateTime.utc(2026, 9, 17),
        plannedPeriods: 1,
        actualPeriods: 0,
        objective: 'Practice polynomials',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'l4',
        classId: 'c2',
        subjectId: 's2',
        chapterId: 'h2',
        topicIds: const ['t3'],
        title: 'Science lesson',
        plannedDate: DateTime.utc(2026, 9, 16),
        plannedPeriods: 2,
        actualPeriods: 0,
        objective: 'Teach velocity',
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  test('derives real overall, subject, backlog and upcoming insights', () {
    final model = ProgressInsightsModel.fromWorkspace(workspace, now: now);

    expect(model.insights.activeTopics, 3);
    expect(model.insights.completedTopics, 1);
    expect(model.overallProgress, closeTo(1 / 3, 0.0001));
    expect(model.subjects, hasLength(2));
    expect(model.overdueLessons.map((item) => item.lesson.id), ['l2']);
    expect(model.upcomingLessons.map((item) => item.lesson.id), ['l4', 'l3']);
    expect(model.highPriorityPendingTopics.map((item) => item.topic.id), [
      't2',
    ]);
    expect(model.periodVariance, -5);
  });

  test('class filter scopes the complete dashboard, not just edit lists', () {
    final model = ProgressInsightsModel.fromWorkspace(
      workspace,
      classId: 'c1',
      now: now,
    );

    expect(model.subjects.map((item) => item.subjectName), ['Math']);
    expect(model.insights.activeTopics, 2);
    expect(model.insights.completedTopics, 1);
    expect(model.overallProgress, 0.5);
    expect(model.lessons.map((item) => item.id), ['l2', 'l1', 'l3']);
    expect(model.upcomingLessons.map((item) => item.lesson.id), ['l3']);
    expect(model.overdueLessons.map((item) => item.lesson.id), ['l2']);
  });

  test('subject progress uses topics when syllabus topics exist', () {
    final model = ProgressInsightsModel.fromWorkspace(
      workspace,
      classId: 'c1',
      now: now,
    );
    final math = model.subjects.single;

    expect(math.usesTopicProgress, isTrue);
    expect(math.completedTopics, 1);
    expect(math.totalTopics, 2);
    expect(math.progress, 0.5);
    expect(math.plannedPeriods, 4);
    expect(math.actualPeriods, 2);
  });
}
