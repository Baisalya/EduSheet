import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lesson plan keeps stable syllabus links and edits without replacing id',
    () async {
      var next = 0;
      final repository = _MemoryRepository();
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => 'id-${next++}',
        clock: () => DateTime.utc(2026, 9, 8, 12),
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
      workspace = await service.createTopic(
        chapterId: chapterId,
        title: 'Linear equations',
      );
      final topicId = workspace.topics.single.id;
      workspace = await service.createLessonPlan(
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: [topicId],
        title: 'Equation introduction',
        plannedDate: DateTime.utc(2026, 9, 10),
        plannedPeriods: 2,
        objective: 'Students solve basic linear equations.',
        materials: 'Board and worksheet',
      );

      final lessonId = workspace.lessonPlans.single.id;
      expect(workspace.lessonPlans.single.topicIds, [topicId]);
      expect(workspace.activeLessonPlans.single.id, lessonId);

      workspace = await service.updateLessonPlan(
        lessonId,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: [topicId],
        title: 'Equation practice',
        plannedDate: DateTime.utc(2026, 9, 11),
        plannedPeriods: 3,
        objective: 'Students independently solve equations.',
        status: TeachingProgressStatus.inProgress,
      );

      expect(workspace.lessonPlans.single.id, lessonId);
      expect(workspace.lessonPlans.single.title, 'Equation practice');
      expect(
        workspace.lessonPlans.single.status,
        TeachingProgressStatus.inProgress,
      );
    },
  );

  test('lesson rejects topic from another chapter', () async {
    var next = 0;
    final repository = _MemoryRepository();
    final service = TeachingPlannerService(
      repository,
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
    final chapterA = workspace.chapters.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      title: 'Light',
    );
    final chapterB = workspace.chapters.last.id;
    workspace = await service.createTopic(
      chapterId: chapterB,
      title: 'Reflection',
    );
    final wrongTopic = workspace.topics.single.id;

    await expectLater(
      service.createLessonPlan(
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterA,
        topicIds: [wrongTopic],
        title: 'Force lesson',
        plannedDate: DateTime(2026, 9, 12),
        plannedPeriods: 1,
        objective: 'Understand force.',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });

  test(
    'archiving syllabus cascades to linked lessons without deleting them',
    () async {
      var next = 0;
      final repository = _MemoryRepository();
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => 'id-${next++}',
      );
      var workspace = await service.createClass(name: 'Class 7');
      final classId = workspace.classes.single.id;
      workspace = await service.createSubject(
        classId: classId,
        name: 'English',
      );
      final subjectId = workspace.subjects.single.id;
      workspace = await service.createChapter(
        subjectId: subjectId,
        title: 'Poetry',
      );
      final chapterId = workspace.chapters.single.id;
      workspace = await service.createLessonPlan(
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        title: 'Poetry lesson',
        plannedDate: DateTime(2026, 9, 12),
        plannedPeriods: 1,
        objective: 'Read a poem.',
      );

      workspace = await service.archiveChapter(chapterId);
      expect(workspace.lessonPlans, hasLength(1));
      expect(workspace.lessonPlans.single.isArchived, isTrue);
    },
  );
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
