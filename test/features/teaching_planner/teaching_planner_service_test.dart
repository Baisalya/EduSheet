import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'service builds hierarchy with deterministic ordering and stable ids',
    () async {
      final ids = <String>[
        'class-10',
        'math',
        'unit-1',
        'chapter-1',
        'topic-a',
        'topic-b',
      ];
      var index = 0;
      final repository = _MemoryPlannerRepository();
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => ids[index++],
        clock: () => DateTime.utc(2026, 9, 8, 12),
      );

      var workspace = await service.createClass(name: ' Class 10 ');
      workspace = await service.createSubject(
        classId: workspace.classes.single.id,
        name: 'Mathematics',
      );
      workspace = await service.createUnit(
        subjectId: workspace.subjects.single.id,
        title: 'Unit 1',
        plannedPeriods: 10,
      );
      workspace = await service.createChapter(
        subjectId: workspace.subjects.single.id,
        unitId: workspace.units.single.id,
        title: 'Real Numbers',
        plannedPeriods: 6,
      );
      workspace = await service.createTopic(
        chapterId: workspace.chapters.single.id,
        title: 'Euclid Lemma',
        plannedPeriods: 2,
      );
      workspace = await service.createTopic(
        chapterId: workspace.chapters.single.id,
        title: 'HCF and LCM',
        plannedPeriods: 2,
      );

      expect(workspace.classes.single.id, 'class-10');
      expect(workspace.classes.single.name, 'Class 10');
      expect(workspace.subjects.single.id, 'math');
      expect(workspace.topics.map((topic) => topic.sortOrder), [0, 1]);

      workspace = await service.reorderTopics(
        chapterId: 'chapter-1',
        orderedTopicIds: const ['topic-b', 'topic-a'],
      );
      expect(
        workspace.activeTopicsForChapter('chapter-1').map((topic) => topic.id),
        ['topic-b', 'topic-a'],
      );
    },
  );

  test('archiving a class cascades without destructive deletion', () async {
    final repository = _MemoryPlannerRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 8, 13),
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
      title: 'Contact force',
    );

    workspace = await service.archiveClass(classId);

    expect(workspace.classes.single.isArchived, isTrue);
    expect(workspace.subjects.single.isArchived, isTrue);
    expect(workspace.chapters.single.isArchived, isTrue);
    expect(workspace.topics.single.isArchived, isTrue);
    expect(workspace.classes, hasLength(1));
    expect(workspace.topics, hasLength(1));
  });

  test('service rejects cross-subject chapter/unit relationship', () async {
    final repository = _MemoryPlannerRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 8),
    );

    var workspace = await service.createClass(name: 'Class 10');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final mathId = workspace.subjects.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Science');
    final scienceId = workspace.subjects.last.id;
    workspace = await service.createUnit(subjectId: mathId, title: 'Math unit');
    final mathUnitId = workspace.units.single.id;

    await expectLater(
      service.createChapter(
        subjectId: scienceId,
        unitId: mathUnitId,
        title: 'Invalid chapter',
      ),
      throwsA(isA<TeachingPlannerOperationException>()),
    );
  });
}

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  TeachingPlannerWorkspace workspace = TeachingPlannerWorkspace.empty();

  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    this.workspace = workspace;
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
