import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1B syllabus move and duplicate', () {
    test('moving a subject preserves stable ids and realigns lesson class', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoClassChapter();
      final sourceSubject = workspace.subjects.first;
      final destinationClass = workspace.classes.last;
      final chapter = workspace.chapters.single;

      workspace = await fixture.service.createLessonPlan(
        classId: sourceSubject.classId,
        subjectId: sourceSubject.id,
        chapterId: chapter.id,
        title: 'Lesson 1',
        plannedDate: DateTime.utc(2026, 9, 22),
        plannedPeriods: 1,
        objective: 'Teach the chapter',
      );
      final lessonId = workspace.lessonPlans.single.id;

      workspace = await fixture.service.moveSubject(
        subjectId: sourceSubject.id,
        destinationClassId: destinationClass.id,
      );

      expect(workspace.subjectById(sourceSubject.id)?.classId, destinationClass.id);
      expect(workspace.chapterById(chapter.id)?.id, chapter.id);
      expect(workspace.lessonPlanById(lessonId)?.classId, destinationClass.id);
      expect(workspace.lessonPlanById(lessonId)?.subjectId, sourceSubject.id);
    });

    test('moving a unit across subjects realigns chapters and lessons atomically', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoSubjectUnit();
      final unit = workspace.units.single;
      final chapter = workspace.chapters.single;
      final sourceSubject = workspace.subjectById(unit.subjectId)!;
      final destinationSubject = workspace.subjects.last;

      workspace = await fixture.service.createLessonPlan(
        classId: sourceSubject.classId,
        subjectId: sourceSubject.id,
        chapterId: chapter.id,
        title: 'Existing lesson',
        plannedDate: DateTime.utc(2026, 9, 22),
        plannedPeriods: 1,
        objective: 'Keep references valid',
      );
      final lessonId = workspace.lessonPlans.single.id;

      workspace = await fixture.service.moveUnit(
        unitId: unit.id,
        destinationSubjectId: destinationSubject.id,
      );

      expect(workspace.unitById(unit.id)?.subjectId, destinationSubject.id);
      expect(workspace.chapterById(chapter.id)?.subjectId, destinationSubject.id);
      expect(workspace.chapterById(chapter.id)?.unitId, unit.id);
      expect(workspace.lessonPlanById(lessonId)?.subjectId, destinationSubject.id);
      expect(
        workspace.lessonPlanById(lessonId)?.classId,
        destinationSubject.classId,
      );
    });

    test('moving a chapter preserves chapter id and topic relationships', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoSubjectUnit();
      final chapter = workspace.chapters.single;
      final topic = workspace.topics.single;
      final destinationSubject = workspace.subjects.last;

      workspace = await fixture.service.moveChapter(
        chapterId: chapter.id,
        destinationSubjectId: destinationSubject.id,
      );

      expect(workspace.chapterById(chapter.id)?.id, chapter.id);
      expect(workspace.chapterById(chapter.id)?.subjectId, destinationSubject.id);
      expect(workspace.chapterById(chapter.id)?.unitId, isNull);
      expect(workspace.topicById(topic.id)?.chapterId, chapter.id);
    });

    test('moving a topic removes incompatible topic references but preserves lesson history', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoChapters();
      final sourceChapter = workspace.chapters.first;
      final destinationChapter = workspace.chapters.last;
      final topic = workspace.topics.single;
      final subject = workspace.subjectById(sourceChapter.subjectId)!;

      workspace = await fixture.service.createLessonPlan(
        classId: subject.classId,
        subjectId: subject.id,
        chapterId: sourceChapter.id,
        topicIds: [topic.id],
        title: 'Past lesson',
        plannedDate: DateTime.utc(2026, 9, 20),
        plannedPeriods: 1,
        objective: 'History stays',
        status: TeachingProgressStatus.completed,
      );
      final lessonId = workspace.lessonPlans.single.id;

      workspace = await fixture.service.moveTopic(
        topicId: topic.id,
        destinationChapterId: destinationChapter.id,
      );

      expect(workspace.topicById(topic.id)?.chapterId, destinationChapter.id);
      expect(workspace.lessonPlanById(lessonId), isNotNull);
      expect(workspace.lessonPlanById(lessonId)?.topicIds, isEmpty);
      expect(
        workspace.lessonPlanById(lessonId)?.status,
        TeachingProgressStatus.completed,
      );
    });

    test('duplicate chapter copies structure with fresh ids and resets progress/history', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoChapters();
      final source = workspace.chapters.first;
      final subject = workspace.subjectById(source.subjectId)!;

      workspace = await fixture.service.updateChapterProgress(
        source.id,
        status: TeachingProgressStatus.completed,
      );
      workspace = await fixture.service.createLessonPlan(
        classId: subject.classId,
        subjectId: subject.id,
        chapterId: source.id,
        title: 'Source lesson',
        plannedDate: DateTime.utc(2026, 9, 20),
        plannedPeriods: 1,
        objective: 'Do not duplicate history',
      );
      final originalChapterIds = workspace.chapters.map((e) => e.id).toSet();
      final originalTopicIds = workspace.topics.map((e) => e.id).toSet();

      workspace = await fixture.service.duplicateChapterStructure(
        chapterId: source.id,
        destinationSubjectId: subject.id,
        destinationUnitId: source.unitId,
      );

      final copy = workspace.chapters.singleWhere(
        (item) => !originalChapterIds.contains(item.id),
      );
      final copiedTopics = workspace.topics.where(
        (item) => !originalTopicIds.contains(item.id),
      );
      expect(copy.id, isNot(source.id));
      expect(copy.title, contains('copy'));
      expect(copy.status, TeachingProgressStatus.planned);
      expect(copiedTopics, isNotEmpty);
      expect(copiedTopics.every((item) => item.status == TeachingProgressStatus.planned), isTrue);
      expect(copiedTopics.every((item) => item.actualPeriods == 0), isTrue);
      expect(workspace.lessonPlans, hasLength(1));
    });

    test('duplicate unit copies chapters and topics but not lessons', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoSubjectUnit();
      final sourceUnit = workspace.units.single;
      final sourceSubject = workspace.subjectById(sourceUnit.subjectId)!;
      final destinationSubject = workspace.subjects.last;
      final sourceChapter = workspace.chapters.single;
      workspace = await fixture.service.createLessonPlan(
        classId: sourceSubject.classId,
        subjectId: sourceSubject.id,
        chapterId: sourceChapter.id,
        title: 'Source lesson',
        plannedDate: DateTime.utc(2026, 9, 23),
        plannedPeriods: 1,
        objective: 'Do not copy lesson history',
      );
      final oldUnitIds = workspace.units.map((e) => e.id).toSet();
      final oldChapterIds = workspace.chapters.map((e) => e.id).toSet();
      final oldTopicIds = workspace.topics.map((e) => e.id).toSet();

      workspace = await fixture.service.duplicateUnitStructure(
        unitId: sourceUnit.id,
        destinationSubjectId: destinationSubject.id,
      );

      final copiedUnit = workspace.units.singleWhere(
        (item) => !oldUnitIds.contains(item.id),
      );
      final copiedChapter = workspace.chapters.singleWhere(
        (item) => !oldChapterIds.contains(item.id),
      );
      final copiedTopic = workspace.topics.singleWhere(
        (item) => !oldTopicIds.contains(item.id),
      );
      expect(copiedUnit.subjectId, destinationSubject.id);
      expect(copiedUnit.title, sourceUnit.title);
      expect(copiedChapter.subjectId, destinationSubject.id);
      expect(copiedChapter.unitId, copiedUnit.id);
      expect(copiedChapter.status, TeachingProgressStatus.planned);
      expect(copiedTopic.chapterId, copiedChapter.id);
      expect(copiedTopic.status, TeachingProgressStatus.planned);
      expect(workspace.lessonPlans, hasLength(1));
      expect(workspace.lessonPlans.single.chapterId, sourceChapter.id);
    });

    test('duplicate topic uses fresh id and resets taught progress', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoChapters();
      final sourceTopic = workspace.topics.single;
      final destinationChapter = workspace.chapters.last;
      workspace = await fixture.service.updateTopicProgress(
        sourceTopic.id,
        status: TeachingProgressStatus.completed,
        actualPeriods: 3,
      );
      final originalIds = workspace.topics.map((e) => e.id).toSet();

      workspace = await fixture.service.duplicateTopicStructure(
        topicId: sourceTopic.id,
        destinationChapterId: destinationChapter.id,
      );

      final copy = workspace.topics.singleWhere(
        (item) => !originalIds.contains(item.id),
      );
      expect(copy.chapterId, destinationChapter.id);
      expect(copy.id, isNot(sourceTopic.id));
      expect(copy.status, TeachingProgressStatus.planned);
      expect(copy.actualPeriods, 0);
    });

    test('duplicate subject copies nested curriculum only with fresh ids', () async {
      final fixture = _Fixture();
      var workspace = await fixture.service.createClass(name: 'Class 8');
      final sourceClassId = workspace.classes.single.id;
      workspace = await fixture.service.createClass(name: 'Class 9');
      final destinationClassId = workspace.classes.last.id;
      workspace = await fixture.service.createSubject(
        classId: sourceClassId,
        name: 'Mathematics',
      );
      final sourceSubjectId = workspace.subjects.single.id;
      workspace = await fixture.service.createUnit(
        subjectId: sourceSubjectId,
        title: 'Algebra',
        plannedPeriods: 8,
      );
      final sourceUnitId = workspace.units.single.id;
      workspace = await fixture.service.createChapter(
        subjectId: sourceSubjectId,
        unitId: sourceUnitId,
        title: 'Linear Equations',
        plannedPeriods: 4,
      );
      final sourceChapterId = workspace.chapters.single.id;
      workspace = await fixture.service.createTopic(
        chapterId: sourceChapterId,
        title: 'One-step equations',
        plannedPeriods: 2,
      );
      workspace = await fixture.service.updateChapterProgress(
        sourceChapterId,
        status: TeachingProgressStatus.completed,
      );
      final originalIds = <String>{
        sourceSubjectId,
        sourceUnitId,
        sourceChapterId,
        workspace.topics.single.id,
      };

      workspace = await fixture.service.duplicateSubjectStructure(
        subjectId: sourceSubjectId,
        destinationClassId: destinationClassId,
      );

      final copiedSubject = workspace.subjects.singleWhere(
        (item) => item.classId == destinationClassId,
      );
      final copiedUnit = workspace.units.singleWhere(
        (item) => item.subjectId == copiedSubject.id,
      );
      final copiedChapter = workspace.chapters.singleWhere(
        (item) => item.subjectId == copiedSubject.id,
      );
      final copiedTopic = workspace.topics.singleWhere(
        (item) => item.chapterId == copiedChapter.id,
      );
      expect(copiedSubject.name, 'Mathematics');
      expect(copiedUnit.title, 'Algebra');
      expect(copiedChapter.unitId, copiedUnit.id);
      expect(copiedChapter.status, TeachingProgressStatus.planned);
      expect(copiedTopic.actualPeriods, 0);
      expect(
        <String>{copiedSubject.id, copiedUnit.id, copiedChapter.id, copiedTopic.id}
            .intersection(originalIds),
        isEmpty,
      );
      expect(workspace.lessonPlans, isEmpty);
    });

    test('destination duplicate-name conflict aborts move without partial mutation', () async {
      final fixture = _Fixture();
      var workspace = await fixture.service.createClass(name: 'Class A');
      final classA = workspace.classes.single.id;
      workspace = await fixture.service.createClass(name: 'Class B');
      final classB = workspace.classes.last.id;
      workspace = await fixture.service.createSubject(classId: classA, name: 'Math');
      final movingId = workspace.subjects.single.id;
      workspace = await fixture.service.createSubject(classId: classB, name: 'Math');

      await expectLater(
        fixture.service.moveSubject(
          subjectId: movingId,
          destinationClassId: classB,
        ),
        throwsA(isA<TeachingPlannerOperationException>()),
      );

      final after = await fixture.repository.load();
      expect(after.subjectById(movingId)?.classId, classA);
    });

    test('renaming keeps stable ids and existing lesson references', () async {
      final fixture = _Fixture();
      var workspace = await fixture.buildTwoClassChapter();
      final subject = workspace.subjects.first;
      final chapter = workspace.chapters.single;
      workspace = await fixture.service.createLessonPlan(
        classId: subject.classId,
        subjectId: subject.id,
        chapterId: chapter.id,
        title: 'Lesson',
        plannedDate: DateTime.utc(2026, 9, 22),
        plannedPeriods: 1,
        objective: 'Rename safety',
      );
      final lessonId = workspace.lessonPlans.single.id;

      workspace = await fixture.service.updateSubject(
        subject.id,
        name: 'Mathematics',
      );
      workspace = await fixture.service.updateChapter(
        chapter.id,
        title: 'Renamed chapter',
        plannedPeriods: chapter.plannedPeriods,
        priority: PlannerPriority.normal,
        unitId: chapter.unitId,
      );

      expect(workspace.subjectById(subject.id)?.name, 'Mathematics');
      expect(workspace.chapterById(chapter.id)?.title, 'Renamed chapter');
      expect(workspace.lessonPlanById(lessonId)?.subjectId, subject.id);
      expect(workspace.lessonPlanById(lessonId)?.chapterId, chapter.id);
    });
  });
}

class _Fixture {
  _Fixture() {
    service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${_counter++}',
      clock: () => DateTime.utc(2026, 9, 21, 12),
    );
  }

  int _counter = 0;
  final _MemoryPlannerRepository repository = _MemoryPlannerRepository();
  late final TeachingPlannerService service;

  Future<TeachingPlannerWorkspace> buildTwoClassChapter() async {
    repository.workspace = TeachingPlannerWorkspace.empty();
    var workspace = await service.createClass(name: 'Class 8');
    final classA = workspace.classes.single.id;
    workspace = await service.createClass(name: 'Class 9');
    workspace = await service.createSubject(classId: classA, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(subjectId: subjectId, title: 'Algebra');
    return workspace;
  }

  Future<TeachingPlannerWorkspace> buildTwoSubjectUnit() async {
    repository.workspace = TeachingPlannerWorkspace.empty();
    var workspace = await service.createClass(name: 'Class 8');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectA = workspace.subjects.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Science');
    workspace = await service.createUnit(subjectId: subjectA, title: 'Unit 1');
    final unitId = workspace.units.single.id;
    workspace = await service.createChapter(
      subjectId: subjectA,
      unitId: unitId,
      title: 'Real Numbers',
    );
    workspace = await service.createTopic(
      chapterId: workspace.chapters.single.id,
      title: 'Euclid',
    );
    return workspace;
  }

  Future<TeachingPlannerWorkspace> buildTwoChapters() async {
    repository.workspace = TeachingPlannerWorkspace.empty();
    var workspace = await service.createClass(name: 'Class 8');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createChapter(subjectId: subjectId, title: 'Chapter A');
    final chapterA = workspace.chapters.single.id;
    workspace = await service.createChapter(subjectId: subjectId, title: 'Chapter B');
    workspace = await service.createTopic(chapterId: chapterA, title: 'Topic A');
    return workspace;
  }
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
