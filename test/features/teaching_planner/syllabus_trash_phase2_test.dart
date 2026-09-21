import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy syllabus json without trashedAt remains active', () {
    final chapter = PlannerChapter.fromJson({
      'id': 'chapter-1',
      'subjectId': 'subject-1',
      'title': 'Real Numbers',
      'sortOrder': 0,
      'plannedPeriods': 4,
      'priority': 'normal',
      'status': 'planned',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'updatedAt': '2026-09-01T00:00:00.000Z',
    });

    expect(chapter.trashedAt, isNull);
    expect(chapter.isTrashed, isFalse);
    expect(chapter.isArchived, isFalse);
  });

  test('class trash cascades and restore is non-destructive', () async {
    final repository = _MemoryRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 21, 12),
    );

    var workspace = await service.createClass(name: 'Class 8');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createUnit(subjectId: subjectId, title: 'Algebra');
    final unitId = workspace.units.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      unitId: unitId,
      title: 'Linear Equations',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createTopic(
      chapterId: chapterId,
      title: 'One variable',
    );
    final topicId = workspace.topics.single.id;
    workspace = await service.createLessonPlan(
      classId: classId,
      subjectId: subjectId,
      chapterId: chapterId,
      topicIds: [topicId],
      title: 'Linear Equations',
      plannedDate: DateTime.utc(2026, 9, 22),
      plannedPeriods: 1,
      objective: 'Introduce equations',
    );
    workspace = await service.createTeachingResource(
      owner: TeachingResourceOwner.chapter(chapterId),
      kind: TeachingResourceKind.note,
      title: 'Board notes',
      body: 'Examples',
    );

    workspace = await service.trashClass(classId);

    final roundTripped = TeachingPlannerWorkspace.fromJson(workspace.toJson());
    expect(roundTripped.classes.single.isTrashed, isTrue);
    expect(roundTripped.lessonPlans.single.isTrashed, isTrue);
    expect(roundTripped.resources.single.isTrashed, isTrue);

    expect(workspace.classes.single.isTrashed, isTrue);
    expect(workspace.subjects.single.isTrashed, isTrue);
    expect(workspace.units.single.isTrashed, isTrue);
    expect(workspace.chapters.single.isTrashed, isTrue);
    expect(workspace.topics.single.isTrashed, isTrue);
    expect(workspace.lessonPlans.single.isTrashed, isTrue);
    expect(workspace.resources.single.isTrashed, isTrue);
    expect(workspace.activeClasses, isEmpty);
    expect(workspace.classes, hasLength(1), reason: 'Trash must not hard delete data.');

    workspace = await service.restoreTrashedClass(classId);

    expect(workspace.classes.single.isTrashed, isFalse);
    expect(workspace.subjects.single.isTrashed, isFalse);
    expect(workspace.units.single.isTrashed, isFalse);
    expect(workspace.chapters.single.isTrashed, isFalse);
    expect(workspace.topics.single.isTrashed, isFalse);
    expect(workspace.lessonPlans.single.isTrashed, isFalse);
    expect(workspace.resources.single.isTrashed, isFalse);
    expect(workspace.activeClasses.single.id, classId);
  });

  test('permanent chapter delete is only allowed after Trash', () async {
    final repository = _MemoryRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 21, 13),
    );

    var workspace = await service.createClass(name: 'Class 9');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Science');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      title: 'Motion',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createTopic(chapterId: chapterId, title: 'Speed');
    workspace = await service.createLessonPlan(
      classId: classId,
      subjectId: subjectId,
      chapterId: chapterId,
      title: 'Motion',
      plannedDate: DateTime.utc(2026, 9, 23),
      plannedPeriods: 1,
      objective: 'Understand speed',
    );
    workspace = await service.createTeachingResource(
      owner: TeachingResourceOwner.chapter(chapterId),
      kind: TeachingResourceKind.note,
      title: 'Motion notes',
      body: 'Notes',
    );

    await expectLater(
      service.deleteChapterPermanently(chapterId),
      throwsA(isA<TeachingPlannerOperationException>()),
    );

    workspace = await service.trashChapter(chapterId);
    expect(workspace.chapters.single.isTrashed, isTrue);

    workspace = await service.deleteChapterPermanently(chapterId);
    expect(workspace.chapters, isEmpty);
    expect(workspace.topics, isEmpty);
    expect(workspace.lessonPlans, isEmpty);
    expect(workspace.resources, isEmpty);
    expect(workspace.classes, hasLength(1));
    expect(workspace.subjects, hasLength(1));
  });


  test('topic trash keeps lesson history and permanent delete removes only topic reference', () async {
    final repository = _MemoryRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 21, 14),
    );

    var workspace = await service.createClass(name: 'Class 7');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(subjectId: subjectId, title: 'Fractions');
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createTopic(chapterId: chapterId, title: 'Addition');
    final topicId = workspace.topics.single.id;
    workspace = await service.createLessonPlan(
      classId: classId,
      subjectId: subjectId,
      chapterId: chapterId,
      topicIds: [topicId],
      title: 'Fractions',
      plannedDate: DateTime.utc(2026, 9, 24),
      plannedPeriods: 1,
      objective: 'Add fractions',
    );

    workspace = await service.trashTopic(topicId);
    expect(workspace.topics.single.isTrashed, isTrue);
    expect(workspace.lessonPlans.single.isTrashed, isFalse);
    expect(workspace.lessonPlans.single.topicIds, contains(topicId));

    workspace = await service.deleteTopicPermanently(topicId);
    expect(workspace.topics, isEmpty);
    expect(workspace.lessonPlans, hasLength(1));
    expect(workspace.lessonPlans.single.topicIds, isEmpty);
  });
}

class _MemoryRepository implements TeachingPlannerRepository {
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
