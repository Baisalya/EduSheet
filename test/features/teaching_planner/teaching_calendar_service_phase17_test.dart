import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8);
  TeachingPlannerWorkspace seed() => TeachingPlannerWorkspace(
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
        plannedPeriods: 3,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'l',
        classId: 'c',
        subjectId: 's',
        chapterId: 'h',
        title: 'Division',
        plannedDate: DateTime.utc(2026, 9, 10),
        plannedPeriods: 2,
        objective: 'Learn division',
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );

  test('schedule update preserves lesson identity and content', () async {
    final repository = _MemoryRepository(seed());
    final service = TeachingPlannerService(
      repository,
      clock: () => DateTime.utc(2026, 9, 9),
    );
    final updated = await service.scheduleLessonPlan(
      'l',
      plannedDate: DateTime.utc(2026, 9, 12),
      startPeriod: 4,
    );
    final lesson = updated.lessonPlanById('l')!;
    expect(lesson.id, 'l');
    expect(lesson.title, 'Division');
    expect(lesson.plannedDate, DateTime.utc(2026, 9, 12));
    expect(lesson.startPeriod, 4);
  });

  test('invalid start period is rejected before persistence', () {
    final service = TeachingPlannerService(_MemoryRepository(seed()));
    expect(
      () => service.scheduleLessonPlan(
        'l',
        plannedDate: DateTime.utc(2026, 9, 12),
        startPeriod: 0,
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });
}

class _MemoryRepository implements TeachingPlannerRepository {
  _MemoryRepository(this.workspace);
  TeachingPlannerWorkspace workspace;
  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;
  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async =>
      this.workspace = workspace;
  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
