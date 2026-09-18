import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/syllabus_node_ref.dart';
import 'package:edusheet/features/teaching_planner/presentation/models/teaching_planner_smart_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TeachingPlannerSmartAssistantService();
  final now = DateTime.utc(2026, 9, 16);

  PlannerClass plannerClass(String id, String name, {int order = 0}) =>
      PlannerClass(
        id: id,
        name: name,
        sortOrder: order,
        createdAt: now,
        updatedAt: now,
      );

  PlannerSubject subject(String id, String classId, String name) =>
      PlannerSubject(
        id: id,
        classId: classId,
        name: name,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

  PlannerChapter chapter(String id, String subjectId, String title) =>
      PlannerChapter(
        id: id,
        subjectId: subjectId,
        title: title,
        sortOrder: 0,
        plannedPeriods: 4,
        createdAt: now,
        updatedAt: now,
      );

  LessonPlan lesson(String id, String classId, String subjectId, String chapterId) =>
      LessonPlan(
        id: id,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        title: 'Lesson',
        plannedDate: now,
        plannedPeriods: 1,
        objective: 'Teach the chapter.',
        createdAt: now,
        updatedAt: now,
      );

  test('empty syllabus suggests starting the first syllabus', () {
    final result = service.recommendForSyllabus(
      workspace: TeachingPlannerWorkspace.empty(),
    );

    expect(result, isNotNull);
    expect(
      result!.action,
      TeachingPlannerSmartAssistantAction.createSyllabus,
    );
    expect(result.suggestion.primaryLabel, 'Start syllabus');
    expect(result.suggestion.requiresIncompleteAction, isTrue);
  });

  test('selected class without subjects gets class-aware subject suggestion', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [plannerClass('class-8', 'Class 8')],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.classValue('class-8'),
    );

    expect(result, isNotNull);
    expect(result!.action, TeachingPlannerSmartAssistantAction.createSubject);
    expect(result.classId, 'class-8');
    expect(result.suggestion.title, 'Add a subject to Class 8?');
    expect(result.suggestion.message, contains('Class 8'));
  });

  test('selected subject without chapters gets subject-aware chapter suggestion', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [plannerClass('class-8', 'Class 8')],
      subjects: [subject('math', 'class-8', 'Mathematics')],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.subject(
        classId: 'class-8',
        subjectId: 'math',
      ),
    );

    expect(result, isNotNull);
    expect(result!.action, TeachingPlannerSmartAssistantAction.createChapter);
    expect(result.subjectId, 'math');
    expect(result.suggestion.title, 'Add a chapter to Mathematics?');
    expect(result.suggestion.message, contains('Units and topics are optional'));
  });

  test('chapter without a lesson suggests a preselected lesson workflow', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [plannerClass('class-8', 'Class 8')],
      subjects: [subject('math', 'class-8', 'Mathematics')],
      chapters: [chapter('fractions', 'math', 'Fractions')],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.chapter(
        classId: 'class-8',
        subjectId: 'math',
        chapterId: 'fractions',
      ),
    );

    expect(result, isNotNull);
    expect(
      result!.action,
      TeachingPlannerSmartAssistantAction.planChapterLesson,
    );
    expect(result.classId, 'class-8');
    expect(result.subjectId, 'math');
    expect(result.chapterId, 'fractions');
    expect(result.suggestion.title, 'Plan a lesson for Fractions?');
    expect(result.suggestion.message, contains('Class 8 · Mathematics'));
  });

  test('chapter with a lesson but no files offers optional teaching material', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [plannerClass('class-8', 'Class 8')],
      subjects: [subject('math', 'class-8', 'Mathematics')],
      chapters: [chapter('fractions', 'math', 'Fractions')],
      lessonPlans: [lesson('lesson-1', 'class-8', 'math', 'fractions')],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.chapter(
        classId: 'class-8',
        subjectId: 'math',
        chapterId: 'fractions',
      ),
    );

    expect(result, isNotNull);
    expect(
      result!.action,
      TeachingPlannerSmartAssistantAction.addChapterMaterial,
    );
    expect(result.suggestion.primaryLabel, 'Add material');
    expect(result.suggestion.message, contains('This is optional'));
    expect(result.suggestion.requiresIncompleteAction, isFalse);
  });

  test('complete chapter with lesson and material does not nag', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [plannerClass('class-8', 'Class 8')],
      subjects: [subject('math', 'class-8', 'Mathematics')],
      chapters: [chapter('fractions', 'math', 'Fractions')],
      lessonPlans: [lesson('lesson-1', 'class-8', 'math', 'fractions')],
      resources: [
        TeachingResource(
          id: 'resource-1',
          owner: const TeachingResourceOwner.chapter('fractions'),
          kind: TeachingResourceKind.file,
          title: 'Fractions notes',
          originalFileName: 'fractions.docx',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.chapter(
        classId: 'class-8',
        subjectId: 'math',
        chapterId: 'fractions',
      ),
    );

    expect(result, isNull);
  });

  test('complete selected context does not surface another class gap', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        plannerClass('class-8', 'Class 8'),
        plannerClass('class-9', 'Class 9', order: 1),
      ],
      subjects: [subject('math', 'class-8', 'Mathematics')],
      chapters: [chapter('fractions', 'math', 'Fractions')],
      lessonPlans: [lesson('lesson-1', 'class-8', 'math', 'fractions')],
      resources: [
        TeachingResource(
          id: 'resource-1',
          owner: const TeachingResourceOwner.chapter('fractions'),
          kind: TeachingResourceKind.file,
          title: 'Fractions notes',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.subject(
        classId: 'class-8',
        subjectId: 'math',
      ),
    );

    expect(result, isNull);
  });

  test('selection context wins over an unrelated incomplete class', () {
    final workspace = TeachingPlannerWorkspace(
      classes: [
        plannerClass('class-8', 'Class 8'),
        plannerClass('class-9', 'Class 9', order: 1),
      ],
      subjects: [subject('math', 'class-8', 'Mathematics')],
      chapters: [chapter('fractions', 'math', 'Fractions')],
    );

    final result = service.recommendForSyllabus(
      workspace: workspace,
      selected: const SyllabusNodeRef.subject(
        classId: 'class-8',
        subjectId: 'math',
      ),
    );

    expect(result, isNotNull);
    expect(result!.classId, 'class-8');
    expect(result.chapterId, 'fractions');
    expect(
      result.action,
      TeachingPlannerSmartAssistantAction.planChapterLesson,
    );
  });
}
