import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('child restore is blocked while its parent remains in Trash', () async {
    final repository = _MemoryRepository();
    var clock = DateTime.utc(2026, 9, 21, 10);
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => clock,
    );

    var workspace = await service.createClass(name: 'Class 8');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      title: 'Linear Equations',
    );

    workspace = await service.trashSubject(subjectId);
    clock = clock.add(const Duration(minutes: 1));
    workspace = await service.trashClass(classId);

    expect(workspace.classById(classId)!.isTrashed, isTrue);
    expect(workspace.subjectById(subjectId)!.isTrashed, isTrue);

    await expectLater(
      service.restoreTrashedSubject(subjectId),
      throwsA(
        isA<TeachingPlannerOperationException>().having(
          (error) => error.message,
          'message',
          contains('parent syllabus'),
        ),
      ),
    );

    workspace = await service.restoreTrashedClass(classId);
    expect(workspace.classById(classId)!.isTrashed, isFalse);
    expect(
      workspace.subjectById(subjectId)!.isTrashed,
      isTrue,
      reason: 'A separately trashed child must not be resurrected by parent restore.',
    );

    workspace = await service.restoreTrashedSubject(subjectId);
    expect(workspace.subjectById(subjectId)!.isTrashed, isFalse);
    expect(workspace.chapters.single.isTrashed, isFalse);
  });

  test('restore elsewhere is atomic and realigns lesson ownership', () async {
    final repository = _MemoryRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 21, 11),
    );

    var workspace = await service.createClass(name: 'Class 8');
    final firstClassId = workspace.classes.single.id;
    workspace = await service.createClass(name: 'Class 9');
    final secondClassId = workspace.classes.last.id;
    workspace = await service.createSubject(
      classId: firstClassId,
      name: 'Mathematics',
    );
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      title: 'Algebra',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createLessonPlan(
      classId: firstClassId,
      subjectId: subjectId,
      chapterId: chapterId,
      title: 'Algebra',
      plannedDate: DateTime.utc(2026, 9, 22),
      plannedPeriods: 1,
      objective: 'Practice algebra',
    );

    workspace = await service.trashSubject(subjectId);
    expect(workspace.lessonPlans.single.isTrashed, isTrue);

    workspace = await service.restoreTrashedSubjectToClass(
      subjectId: subjectId,
      destinationClassId: secondClassId,
    );

    expect(workspace.subjectById(subjectId)!.classId, secondClassId);
    expect(workspace.subjectById(subjectId)!.isTrashed, isFalse);
    expect(workspace.lessonPlans.single.isTrashed, isFalse);
    expect(workspace.lessonPlans.single.classId, secondClassId);
    expect(workspace.lessonPlans.single.subjectId, subjectId);
  });

  test('same-name restore conflict never overwrites active syllabus data', () async {
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
    final trashedId = workspace.subjects.single.id;
    workspace = await service.trashSubject(trashedId);
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final activeId = workspace.subjects.last.id;

    await expectLater(
      service.restoreTrashedSubject(trashedId),
      throwsA(isA<TeachingPlannerOperationException>()),
    );

    workspace = await service.load();
    expect(workspace.subjectById(trashedId)!.isTrashed, isTrue);
    expect(workspace.subjectById(activeId)!.isTrashed, isFalse);
    expect(
      workspace.subjects.where((item) => !item.isTrashed && item.name == 'Math'),
      hasLength(1),
    );
  });

  test('chapter can restore to another unit without losing its lesson history', () async {
    final repository = _MemoryRepository();
    var nextId = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 21, 13),
    );

    var workspace = await service.createClass(name: 'Class 10');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Science');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createUnit(subjectId: subjectId, title: 'Physics');
    final firstUnitId = workspace.units.single.id;
    workspace = await service.createUnit(subjectId: subjectId, title: 'Mechanics');
    final secondUnitId = workspace.units.last.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      unitId: firstUnitId,
      title: 'Motion',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createLessonPlan(
      classId: classId,
      subjectId: subjectId,
      chapterId: chapterId,
      title: 'Motion',
      plannedDate: DateTime.utc(2026, 9, 23),
      plannedPeriods: 1,
      objective: 'Understand motion',
    );

    workspace = await service.trashChapter(chapterId);
    workspace = await service.restoreTrashedChapterToLocation(
      chapterId: chapterId,
      destinationSubjectId: subjectId,
      destinationUnitId: secondUnitId,
    );

    expect(workspace.chapterById(chapterId)!.unitId, secondUnitId);
    expect(workspace.chapterById(chapterId)!.isTrashed, isFalse);
    expect(workspace.lessonPlans, hasLength(1));
    expect(workspace.lessonPlans.single.chapterId, chapterId);
    expect(workspace.lessonPlans.single.isTrashed, isFalse);
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
