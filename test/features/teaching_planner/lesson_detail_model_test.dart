import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/lesson_detail_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15);

  test('derives lesson hierarchy, topics and teaching resources', () {
    final lesson = LessonPlan(
      id: 'lesson-1',
      classId: 'class-10',
      subjectId: 'math',
      chapterId: 'algebra',
      topicIds: const ['linear'],
      title: 'Linear equations',
      plannedDate: now,
      plannedPeriods: 2,
      startPeriod: 3,
      objective: 'Solve linear equations.',
      status: TeachingProgressStatus.inProgress,
      actualPeriods: 1,
      taughtAt: now,
      reflection: 'Needs another example.',
      createdAt: now,
      updatedAt: now,
    );
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
      chapters: [
        PlannerChapter(
          id: 'algebra',
          subjectId: 'math',
          title: 'Algebra',
          sortOrder: 0,
          plannedPeriods: 4,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      topics: [
        PlannerTopic(
          id: 'linear',
          chapterId: 'algebra',
          title: 'Linear equations',
          sortOrder: 0,
          plannedPeriods: 2,
          actualPeriods: 1,
          status: TeachingProgressStatus.inProgress,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      lessonPlans: [lesson],
      resources: [
        TeachingResource(
          id: 'resource-1',
          lessonPlanId: 'lesson-1',
          kind: TeachingResourceKind.note,
          title: 'Board examples',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final model = LessonDetailModel.fromWorkspace(workspace, lesson);

    expect(model.className, 'Class 10');
    expect(model.subjectName, 'Mathematics');
    expect(model.chapterName, 'Algebra');
    expect(model.topicNames, ['Linear equations']);
    expect(model.resourceCount, 1);
    expect(model.statusLabel, 'In progress');
    expect(model.periodLabel, 'Periods 3–4');
    expect(model.periodProgress, .5);
    expect(model.periodVariance, -1);
    expect(model.hasTeachingRecord, isTrue);
  });

  test('keeps zero-period lesson progress finite', () {
    final lesson = LessonPlan(
      id: 'lesson-0',
      classId: 'missing-class',
      subjectId: 'missing-subject',
      chapterId: 'missing-chapter',
      title: 'Zero period lesson',
      plannedDate: now,
      plannedPeriods: 0,
      objective: 'Check fallback behavior.',
      status: TeachingProgressStatus.planned,
      actualPeriods: 0,
      createdAt: now,
      updatedAt: now,
    );
    final model = LessonDetailModel.fromWorkspace(
      TeachingPlannerWorkspace(lessonPlans: [lesson]),
      lesson,
    );

    expect(model.periodProgress, 0);
    expect(model.className, 'Unknown class');
    expect(model.hasTeachingRecord, isFalse);
  });
}
