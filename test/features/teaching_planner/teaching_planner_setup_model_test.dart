import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/teaching_planner_setup_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 10);

  PlannerClass classValue() => PlannerClass(
    id: 'class-1',
    name: 'Class 10',
    academicYear: '2026-27',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );

  PlannerSubject subject() => PlannerSubject(
    id: 'subject-1',
    classId: 'class-1',
    name: 'Mathematics',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );

  PlannerChapter chapter() => PlannerChapter(
    id: 'chapter-1',
    subjectId: 'subject-1',
    title: 'Algebra',
    sortOrder: 0,
    plannedPeriods: 4,
    createdAt: now,
    updatedAt: now,
  );

  LessonPlan lesson() => LessonPlan(
    id: 'lesson-1',
    classId: 'class-1',
    subjectId: 'subject-1',
    chapterId: 'chapter-1',
    title: 'Algebra introduction',
    plannedDate: now,
    plannedPeriods: 1,
    objective: 'Introduce algebraic expressions.',
    createdAt: now,
    updatedAt: now,
  );

  test('empty workspace starts at class setup', () {
    final model = TeachingPlannerSetupModel.fromWorkspace(
      TeachingPlannerWorkspace.empty(),
    );

    expect(model.stage, TeachingPlannerSetupStage.classSetup);
    expect(model.currentStep, 0);
    expect(model.isComplete, isFalse);
  });

  test('class without usable chapter requires syllabus setup', () {
    final model = TeachingPlannerSetupModel.fromWorkspace(
      TeachingPlannerWorkspace(classes: [classValue()], subjects: [subject()]),
    );

    expect(model.stage, TeachingPlannerSetupStage.syllabus);
    expect(model.currentStep, 1);
    expect(model.focusClassId, 'class-1');
  });

  test('class subject and chapter require first lesson', () {
    final model = TeachingPlannerSetupModel.fromWorkspace(
      TeachingPlannerWorkspace(
        classes: [classValue()],
        subjects: [subject()],
        chapters: [chapter()],
      ),
    );

    expect(model.stage, TeachingPlannerSetupStage.firstLesson);
    expect(model.currentStep, 2);
    expect(model.focusClassId, 'class-1');
  });

  test(
    'historical lesson prevents first-run setup from reappearing after archive',
    () {
      final archivedLesson = LessonPlan(
        id: 'lesson-archived',
        classId: 'class-1',
        subjectId: 'subject-1',
        chapterId: 'chapter-1',
        title: 'Archived lesson',
        plannedDate: now,
        plannedPeriods: 1,
        objective: 'Previously completed setup marker.',
        createdAt: now,
        updatedAt: now,
        archivedAt: now,
      );
      final model = TeachingPlannerSetupModel.fromWorkspace(
        TeachingPlannerWorkspace(lessonPlans: [archivedLesson]),
      );

      expect(model.stage, TeachingPlannerSetupStage.complete);
      expect(model.isComplete, isTrue);
      expect(model.activeLessonCount, 0);
    },
  );

  test('valid first lesson completes guided setup', () {
    final model = TeachingPlannerSetupModel.fromWorkspace(
      TeachingPlannerWorkspace(
        classes: [classValue()],
        subjects: [subject()],
        chapters: [chapter()],
        lessonPlans: [lesson()],
      ),
    );

    expect(model.stage, TeachingPlannerSetupStage.complete);
    expect(model.isComplete, isTrue);
    expect(model.activeLessonCount, 1);
  });
}
