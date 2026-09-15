import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'records lesson actual periods without replacing lesson identity',
    () async {
      var next = 0;
      final repo = _MemoryRepository();
      final service = TeachingPlannerService(
        repo,
        idGenerator: () => 'id-${next++}',
        clock: () => DateTime.utc(2026, 9, 8, 10),
      );
      var workspace = await service.createClass(name: 'Class 10');
      final classId = workspace.classes.single.id;
      workspace = await service.createSubject(classId: classId, name: 'Math');
      final subjectId = workspace.subjects.single.id;
      workspace = await service.createChapter(
        subjectId: subjectId,
        title: 'Algebra',
      );
      final chapterId = workspace.chapters.single.id;
      workspace = await service.createLessonPlan(
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        title: 'Linear equations',
        plannedDate: DateTime.utc(2026, 9, 9),
        plannedPeriods: 2,
        objective: 'Solve equations.',
      );
      final lessonId = workspace.lessonPlans.single.id;

      workspace = await service.recordLessonProgress(
        lessonId,
        status: TeachingProgressStatus.completed,
        actualPeriods: 3,
        taughtAt: DateTime.utc(2026, 9, 9),
        reflection: 'Needed one extra period.',
      );

      final lesson = workspace.lessonPlans.single;
      expect(lesson.id, lessonId);
      expect(lesson.actualPeriods, 3);
      expect(lesson.status, TeachingProgressStatus.completed);
      expect(lesson.reflection, 'Needed one extra period.');
      expect(lesson.taughtAt, DateTime.utc(2026, 9, 9));
    },
  );

  test('topic progress remains independently auditable', () async {
    var next = 0;
    final repo = _MemoryRepository();
    final service = TeachingPlannerService(
      repo,
      idGenerator: () => 'id-${next++}',
    );
    var workspace = await service.createClass(name: 'Class 8');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Science');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      title: 'Force',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createTopic(
      chapterId: chapterId,
      title: 'Friction',
      plannedPeriods: 2,
    );
    final topicId = workspace.topics.single.id;

    workspace = await service.updateTopicProgress(
      topicId,
      status: TeachingProgressStatus.inProgress,
      actualPeriods: 1,
    );

    expect(workspace.topics.single.actualPeriods, 1);
    expect(workspace.topics.single.status, TeachingProgressStatus.inProgress);
  });

  test('negative actual periods are rejected', () {
    final repo = _MemoryRepository();
    final service = TeachingPlannerService(repo, idGenerator: () => 'id');
    expect(
      () => service.updateTopicProgress(
        'missing',
        status: TeachingProgressStatus.planned,
        actualPeriods: -1,
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });
}

class _MemoryRepository implements TeachingPlannerRepository {
  TeachingPlannerWorkspace workspace = TeachingPlannerWorkspace.empty();
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
