import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/services/teaching_planner_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integrity rejects a lesson topic from another chapter', () {
    final now = DateTime.utc(2026, 9, 8);
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'c',
          name: 'C',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      subjects: [
        PlannerSubject(
          id: 's',
          classId: 'c',
          name: 'S',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      chapters: [
        PlannerChapter(
          id: 'a',
          subjectId: 's',
          title: 'A',
          sortOrder: 0,
          plannedPeriods: 1,
          createdAt: now,
          updatedAt: now,
        ),
        PlannerChapter(
          id: 'b',
          subjectId: 's',
          title: 'B',
          sortOrder: 1,
          plannedPeriods: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      topics: [
        PlannerTopic(
          id: 't',
          chapterId: 'b',
          title: 'T',
          sortOrder: 0,
          plannedPeriods: 1,
          actualPeriods: 0,
          status: TeachingProgressStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      lessonPlans: [
        LessonPlan(
          id: 'l',
          classId: 'c',
          subjectId: 's',
          chapterId: 'a',
          topicIds: const ['t'],
          title: 'L',
          plannedDate: now,
          plannedPeriods: 1,
          objective: 'O',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final issues = TeachingPlannerIntegrity.validate(workspace);
    expect(
      issues.any((issue) => issue.code == 'lesson_cross_chapter_topic'),
      isTrue,
    );
  });
}
