import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_merge_engine.dart';
import 'package:edusheet/features/teaching_planner/application/portable_paper_import_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_restore_service.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_builder_service.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_import_service.dart';
import 'package:edusheet/features/teaching_planner/data/local_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_asset_store.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_merge_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_package.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/curriculum_merge_repository.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t1 = DateTime.utc(2026, 9, 18, 10);
  final t2 = DateTime.utc(2026, 9, 19, 10);

  test('id collision keeps local work and maps official hierarchy to new ids', () {
    var counter = 0;
    final engine = CurriculumMergeEngine(
      idGenerator: () => 'imported-${++counter}',
      clock: () => t2,
    );
    final local = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-10',
          name: 'My local Class 10',
          sortOrder: 0,
          createdAt: t1,
          updatedAt: t1,
        ),
      ],
    );

    final plan = engine.plan(
      current: local,
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );

    expect(plan.workspace.classes, hasLength(2));
    expect(plan.workspace.classById('class-10')?.name, 'My local Class 10');
    final officialRecord = plan.mergeState.replicaFor('class', 'class-10');
    expect(officialRecord, isNotNull);
    expect(officialRecord!.localId, isNot('class-10'));
    expect(
      plan.workspace.subjectById('maths')?.classId,
      officialRecord.localId,
    );
  });

  test('newer official update preserves teacher execution and private notes', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final first = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );
    final localTopic = first.workspace.topicById('topic-1')!.copyWith(
      actualPeriods: 3,
      status: TeachingProgressStatus.completed,
      plannedStart: DateTime.utc(2026, 9, 20),
      plannedEnd: DateTime.utc(2026, 9, 21),
      updatedAt: t2,
    );
    final localLesson = first.workspace.lessonPlanById('lesson-1')!.copyWith(
      notes: 'Teacher private note',
      actualPeriods: 2,
      status: TeachingProgressStatus.completed,
      reflection: 'Class needed one extra example.',
      taughtAt: DateTime.utc(2026, 9, 20),
      updatedAt: t2,
    );
    final teacherWorkspace = first.workspace.copyWith(
      topics: [localTopic],
      lessonPlans: [localLesson],
      resources: [
        TeachingResource(
          id: 'teacher-note',
          owner: const TeachingResourceOwner.chapter('chapter-1'),
          kind: TeachingResourceKind.note,
          title: 'My classroom note',
          body: 'Keep this even though the principal package does not contain it.',
          createdAt: t2,
          updatedAt: t2,
        ),
      ],
    );
    final updatedOfficial = _officialWorkspace(
      t2,
      chapterTitle: 'Quadratic Equations — Revised',
      topicTitle: 'Nature of Roots',
      lessonTitle: 'Solve and classify roots',
      objective: 'Solve and classify quadratic roots.',
    );

    final second = engine.plan(
      current: teacherWorkspace,
      state: first.mergeState,
      preview: _preview(updatedOfficial),
      localPapers: const [],
    );

    expect(
      second.workspace.chapterById('chapter-1')?.title,
      'Quadratic Equations — Revised',
    );
    final mergedTopic = second.workspace.topicById('topic-1')!;
    expect(mergedTopic.title, 'Nature of Roots');
    expect(mergedTopic.actualPeriods, 3);
    expect(mergedTopic.status, TeachingProgressStatus.completed);
    expect(mergedTopic.plannedStart, DateTime.utc(2026, 9, 20));
    final mergedLesson = second.workspace.lessonPlanById('lesson-1')!;
    expect(mergedLesson.title, 'Solve and classify roots');
    expect(mergedLesson.objective, 'Solve and classify quadratic roots.');
    expect(mergedLesson.notes, 'Teacher private note');
    expect(mergedLesson.actualPeriods, 2);
    expect(mergedLesson.status, TeachingProgressStatus.completed);
    expect(mergedLesson.reflection, 'Class needed one extra example.');
    expect(
      second.workspace.resourceById('teacher-note')?.body,
      'Keep this even though the principal package does not contain it.',
    );
  });

  test('local master edit causes conflict instead of silent overwrite', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final first = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );
    final locallyEdited = first.workspace.copyWith(
      chapters: [
        first.workspace.chapterById('chapter-1')!.copyWith(
          title: 'My locally customized chapter title',
          updatedAt: t2,
        ),
      ],
    );

    final second = engine.plan(
      current: locallyEdited,
      state: first.mergeState,
      preview: _preview(
        _officialWorkspace(t2, chapterTitle: 'Official revised title'),
      ),
      localPapers: const [],
    );

    expect(
      second.workspace.chapterById('chapter-1')?.title,
      'My locally customized chapter title',
    );
    expect(
      second.conflicts.any((item) => item.entityType == 'chapter'),
      isTrue,
    );
    expect(
      second.mergeState.replicaFor('chapter', 'chapter-1')?.sourceRevision,
      t1.millisecondsSinceEpoch,
    );
  });


  test('resource fingerprint ignores JSON map key insertion order', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final firstResource = TeachingResource(
      id: 'geometry-resource',
      owner: const TeachingResourceOwner.chapter('chapter-1'),
      kind: TeachingResourceKind.geometry,
      title: 'Geometry reference',
      geometryJson: <String, dynamic>{'b': 2, 'a': 1},
      createdAt: t1,
      updatedAt: t1,
    );
    final first = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(
        _officialWorkspace(t1).copyWith(resources: [firstResource]),
      ),
      localPapers: const [],
    );
    final reorderedResource = TeachingResource(
      id: 'geometry-resource',
      owner: const TeachingResourceOwner.chapter('chapter-1'),
      kind: TeachingResourceKind.geometry,
      title: 'Geometry reference',
      geometryJson: <String, dynamic>{'a': 1, 'b': 2},
      createdAt: t1,
      updatedAt: t1,
    );

    final second = engine.plan(
      current: first.workspace,
      state: first.mergeState,
      preview: _preview(
        _officialWorkspace(t1).copyWith(resources: [reorderedResource]),
      ),
      localPapers: const [],
    );

    expect(second.conflicts, isEmpty);
    expect(second.workspace.resourceById('geometry-resource'), isNotNull);
  });

  test('local structural re-parenting is preserved as a merge conflict', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final first = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );
    final existingSubject = first.workspace.subjectById('maths')!;
    final teacherClass = PlannerClass(
      id: 'teacher-class',
      name: 'Teacher custom class',
      sortOrder: 99,
      createdAt: t2,
      updatedAt: t2,
    );
    final reparented = PlannerSubject(
      id: existingSubject.id,
      classId: teacherClass.id,
      name: existingSubject.name,
      code: existingSubject.code,
      sortOrder: existingSubject.sortOrder,
      createdAt: existingSubject.createdAt,
      updatedAt: t2,
      archivedAt: existingSubject.archivedAt,
    );
    final reparentedLessons = first.workspace.lessonPlans
        .map(
          (lesson) => lesson.subjectId == existingSubject.id
              ? lesson.copyWith(classId: teacherClass.id, updatedAt: t2)
              : lesson,
        )
        .toList(growable: false);
    final locallyEdited = first.workspace.copyWith(
      classes: [...first.workspace.classes, teacherClass],
      subjects: [reparented],
      lessonPlans: reparentedLessons,
    );

    final second = engine.plan(
      current: locallyEdited,
      state: first.mergeState,
      preview: _preview(_officialWorkspace(t2)),
      localPapers: const [],
    );

    expect(second.workspace.subjectById('maths')?.classId, 'teacher-class');
    expect(
      second.conflicts.any((item) => item.entityType == 'subject'),
      isTrue,
    );
    expect(
      second.mergeState.replicaFor('subject', 'maths')?.sourceRevision,
      t1.millisecondsSinceEpoch,
    );
  });

  test('paper update rebinds an unchanged official paper resource', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final paperV1 = Paper(
      id: 'paper-1',
      originId: 'paper-origin',
      revision: 1,
      updatedAt: t1,
      title: 'Official algebra paper',
      createdAt: t1,
    );
    final resource = TeachingResource(
      id: 'paper-resource',
      owner: const TeachingResourceOwner.chapter('chapter-1'),
      kind: TeachingResourceKind.paper,
      title: 'Official paper',
      linkedPaperId: paperV1.id,
      createdAt: t1,
      updatedAt: t1,
    );
    final firstWorkspace = _officialWorkspace(t1).copyWith(
      resources: [resource],
    );
    final first = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(
        firstWorkspace,
        papers: {
          paperV1.id: PortablePaperSnapshot(paper: paperV1),
        },
      ),
      localPapers: const [],
    );
    final firstPaperPlan = first.paperMaterializations.single;
    final localPaperV1 = paperV1.copyWith(id: firstPaperPlan.targetLocalPaperId);

    final paperV2 = paperV1.copyWith(
      revision: 2,
      updatedAt: t2,
      title: 'Official algebra paper — revised',
    );
    final second = engine.plan(
      current: first.workspace,
      state: first.mergeState,
      preview: _preview(
        _officialWorkspace(t2).copyWith(resources: [resource]),
        papers: {
          paperV2.id: PortablePaperSnapshot(paper: paperV2),
        },
      ),
      localPapers: [localPaperV1],
    );

    final secondPaperPlan = second.paperMaterializations.single;
    expect(secondPaperPlan.targetLocalPaperId, isNot(localPaperV1.id));
    expect(
      second.workspace.resourceById('paper-resource')?.linkedPaperId,
      secondPaperPlan.targetLocalPaperId,
    );
  });


  test('older package cannot downgrade replica or receipt revision', () {
    final engine = CurriculumMergeEngine(clock: () => t2);
    final newer = engine.plan(
      current: TeachingPlannerWorkspace.empty(),
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t2)),
      localPapers: const [],
    );

    final older = engine.plan(
      current: newer.workspace,
      state: newer.mergeState,
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );

    expect(older.staleCount, greaterThan(0));
    expect(
      older.mergeState.replicaFor('chapter', 'chapter-1')?.sourceRevision,
      t2.millisecondsSinceEpoch,
    );
    expect(
      older.mergeState.receipts.single.packageRevision,
      t2.millisecondsSinceEpoch,
    );
  });

  test('re-export preserves canonical origin after local id remap', () async {
    var counter = 0;
    final engine = CurriculumMergeEngine(
      idGenerator: () => 'mapped-${++counter}',
      clock: () => t2,
    );
    final local = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'class-10',
          name: 'Existing local class',
          sortOrder: 0,
          createdAt: t1,
          updatedAt: t1,
        ),
      ],
    );
    final imported = engine.plan(
      current: local,
      state: CurriculumMergeState.empty(),
      preview: _preview(_officialWorkspace(t1)),
      localPapers: const [],
    );
    final officialClass = imported.mergeState.replicaFor('class', 'class-10')!;
    final officialLesson = imported.mergeState.replicaFor(
      'lessonPlan',
      'lesson-1',
    )!;
    final locallyProgressed = imported.workspace.copyWith(
      lessonPlans: [
        imported.workspace.lessonPlanById(officialLesson.localId)!.copyWith(
          notes: 'Teacher-only progress note',
          actualPeriods: 2,
          status: TeachingProgressStatus.completed,
          updatedAt: t2,
        ),
      ],
    );
    final temp = await Directory.systemTemp.createTemp('eds-phase6-export-');
    addTearDown(() => temp.delete(recursive: true));
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: TeachingResourceFileStore(rootResolver: () async => temp),
      paperRepository: _MemoryPaperRepository(),
    ).build(
      source: locallyProgressed,
      selection: CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.classSyllabus,
        classId: officialClass.localId,
      ),
      inclusions: const CurriculumPackageInclusions(
        includeFiles: false,
        includePapers: false,
      ),
      mergeState: imported.mergeState,
    );

    final classLineage = build.lineage.firstWhere(
      (item) => item.entityType == 'class' && item.entityId == officialClass.localId,
    );
    expect(classLineage.originId, 'class-10');
    expect(classLineage.revision, officialClass.sourceRevision);
    final lessonLineage = build.lineage.firstWhere(
      (item) =>
          item.entityType == 'lessonPlan' &&
          item.entityId == officialLesson.localId,
    );
    expect(lessonLineage.originId, 'lesson-1');
    expect(lessonLineage.revision, officialLesson.sourceRevision);
    expect(lessonLineage.updatedAt, t2);
  });


  test('re-export does not promote a local paper edit to official revision', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase6-paper-export-');
    addTearDown(() => temp.delete(recursive: true));
    final localPaper = Paper(
      id: 'local-official-paper',
      originId: 'official-paper-origin',
      revision: 9,
      updatedAt: t2,
      title: 'Teacher edited official paper',
      createdAt: t1,
    );
    final resource = TeachingResource(
      id: 'paper-resource',
      owner: const TeachingResourceOwner.chapter('chapter-1'),
      kind: TeachingResourceKind.paper,
      title: 'Official paper',
      linkedPaperId: localPaper.id,
      createdAt: t1,
      updatedAt: t2,
    );
    final mergeState = CurriculumMergeState(
      replicas: [
        CurriculumReplicaRecord(
          entityType: 'paper',
          localId: localPaper.id,
          originId: 'official-paper-origin',
          sourceRevision: 4,
          sourceUpdatedAt: t1,
          importedAt: t1,
          sourcePackageOriginId: 'assignment-1',
        ),
      ],
    );
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: TeachingResourceFileStore(rootResolver: () async => temp),
      paperRepository: _MemoryPaperRepository([localPaper]),
    ).build(
      source: _officialWorkspace(t2).copyWith(resources: [resource]),
      selection: CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.classSyllabus,
        classId: 'class-10',
      ),
      inclusions: const CurriculumPackageInclusions(includeFiles: false),
      mergeState: mergeState,
    );

    final lineage = build.lineage.firstWhere(
      (item) => item.entityType == 'paper',
    );
    expect(lineage.originId, 'official-paper-origin');
    expect(lineage.revision, 4);
    expect(lineage.updatedAt, t2);
  });

  test('import service commits origin mappings into the local repository', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase6-import-');
    addTearDown(() => temp.delete(recursive: true));
    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => File('${temp.path}/planner.json'),
    );
    final service = CurriculumPackageImportService(
      plannerRepository: repository,
      paperRepository: _MemoryPaperRepository(),
      resourceFileStore: TeachingResourceFileStore(rootResolver: () async => temp),
      mergeEngine: CurriculumMergeEngine(clock: () => t2),
    );

    final result = await service.import(_preview(_officialWorkspace(t1)));
    final stored = await repository.loadCurriculumMergeSnapshot();

    expect(result.plan.addedCount, greaterThan(0));
    expect(stored.workspace.chapterById('chapter-1')?.title, 'Quadratic Equations');
    expect(
      stored.mergeState.replicaFor('chapter', 'chapter-1')?.localId,
      'chapter-1',
    );
    expect(stored.localRevision, greaterThan(1));
  });

  test('failed compare-and-set rolls back staged teaching files', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase6-rollback-');
    addTearDown(() => temp.delete(recursive: true));
    final repository = _RejectingMergeRepository();
    final fileResource = TeachingResource(
      id: 'official-file',
      owner: const TeachingResourceOwner.chapter('chapter-1'),
      kind: TeachingResourceKind.file,
      title: 'Official worksheet',
      originalFileName: 'worksheet.pdf',
      mimeType: 'application/pdf',
      localRelativePath: 'source/worksheet.pdf',
      sizeBytes: 4,
      createdAt: t1,
      updatedAt: t1,
    );
    final service = CurriculumPackageImportService(
      plannerRepository: repository,
      paperRepository: _MemoryPaperRepository(),
      resourceFileStore: TeachingResourceFileStore(
        rootResolver: () async => temp,
      ),
      mergeEngine: CurriculumMergeEngine(clock: () => t2),
    );
    final preview = _preview(
      _officialWorkspace(t1).copyWith(resources: [fileResource]),
      resourceFiles: const <String, List<int>>{
        'official-file': <int>[1, 2, 3, 4],
      },
    );

    await expectLater(service.import(preview), throwsStateError);

    expect(repository.commitCalls, 1);
    expect((await repository.load()).resources, isEmpty);
    expect(await Directory('${temp.path}/official-file').exists(), isFalse);
  });

  test('merge-state decode rejects unsupported replica metadata', () {
    final validBase = <String, dynamic>{
      'localId': 'local-1',
      'originId': 'origin-1',
      'sourceRevision': 1,
      'sourceUpdatedAt': t1.toIso8601String(),
      'importedAt': t1.toIso8601String(),
      'sourcePackageOriginId': 'assignment-1',
    };

    expect(
      () => CurriculumMergeState.fromJson(<String, dynamic>{
        'replicas': <Map<String, dynamic>>[
          <String, dynamic>{
            ...validBase,
            'entityType': 'unsupportedType',
            'ownership': CurriculumReplicaOwnership.officialCurriculum.name,
          },
        ],
        'receipts': const <Object>[],
      }),
      throwsFormatException,
    );
    expect(
      () => CurriculumMergeState.fromJson(<String, dynamic>{
        'replicas': <Map<String, dynamic>>[
          <String, dynamic>{
            ...validBase,
            'entityType': 'class',
            'ownership': 'unknownOwnership',
          },
        ],
        'receipts': const <Object>[],
      }),
      throwsFormatException,
    );
  });

  test('local repository compare-and-set rejects stale merge commit', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase6-cas-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/planner.json');
    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => file,
    );
    final initial = await repository.loadCurriculumMergeSnapshot();
    await repository.save(_officialWorkspace(t1));

    await expectLater(
      repository.commitCurriculumMerge(
        workspace: _officialWorkspace(t2),
        mergeState: CurriculumMergeState.empty(),
        expectedLocalRevision: initial.localRevision,
      ),
      throwsStateError,
    );
    expect((await repository.load()).chapterById('chapter-1')?.title, 'Quadratic Equations');
  });



  test('backup restore remaps official paper replica after id conflict', () async {
    final temp = await Directory.systemTemp.createTemp('eds-phase6-backup-paper-');
    addTearDown(() => temp.delete(recursive: true));
    final existing = Paper(
      id: 'paper-1',
      originId: 'local-paper-origin',
      revision: 1,
      updatedAt: t1,
      title: 'Existing local paper',
      createdAt: t1,
    );
    final official = Paper(
      id: 'paper-1',
      originId: 'official-paper-origin',
      revision: 4,
      updatedAt: t2,
      title: 'Official paper',
      createdAt: t1,
    );
    final resource = TeachingResource(
      id: 'paper-resource',
      owner: const TeachingResourceOwner.plannerClass('class-10'),
      kind: TeachingResourceKind.paper,
      title: 'Official paper',
      linkedPaperId: 'paper-1',
      createdAt: t1,
      updatedAt: t2,
    );
    final mergeState = CurriculumMergeState(
      replicas: [
        CurriculumReplicaRecord(
          entityType: 'paper',
          localId: 'paper-1',
          originId: 'official-paper-origin',
          sourceRevision: 4,
          sourceUpdatedAt: t2,
          importedAt: t2,
          sourcePackageOriginId: 'assignment-1',
        ),
      ],
    );
    final payload = TeachingPlannerBackupPayload(
      workspace: TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'class-10',
            name: 'Class 10',
            sortOrder: 0,
            createdAt: t1,
            updatedAt: t1,
          ),
        ],
        resources: [resource],
      ),
      paperSnapshots: {
        'paper-1': PortablePaperSnapshot(paper: official),
      },
      mergeState: mergeState,
      version: 4,
    );
    final repository = _MemoryPaperRepository([existing]);
    final service = TeachingPlannerBackupRestoreService(
      paperRepository: repository,
      resourceFileStore: TeachingResourceFileStore(rootResolver: () async => temp),
      paperImportService: PortablePaperImportService(
        paperRepository: repository,
        idGenerator: () => 'paper-copy',
        assetStore: PortablePaperAssetStore(
          rootResolver: () async => Directory('${temp.path}/assets'),
          importDirectoryId: () => 'phase6',
        ),
      ),
    );
    CurriculumMergeState? savedState;

    final result = await service.restore(
      payload: payload,
      currentWorkspace: TeachingPlannerWorkspace.empty(),
      saveWorkspace: (workspace, state, _) async {
        savedState = state;
        expect(workspace.resourceById('paper-resource')?.linkedPaperId, 'paper-copy');
        return true;
      },
    );

    expect(result.saved, isTrue);
    expect(result.conflictCopyCount, 1);
    expect(
      savedState?.replicaFor('paper', 'official-paper-origin')?.localId,
      'paper-copy',
    );
  });

  test('v4 planner backup preserves curriculum replica lineage', () {
    final state = CurriculumMergeState(
      replicas: [
        CurriculumReplicaRecord(
          entityType: 'class',
          localId: 'local-class',
          originId: 'class-10',
          sourceRevision: t1.millisecondsSinceEpoch,
          sourceUpdatedAt: t1,
          importedAt: t1,
          sourcePackageOriginId: 'assignment-1',
          sourceFingerprint: 'abc123',
        ),
      ],
    );
    final workspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'local-class',
          name: 'Class 10',
          academicYear: '2026-27',
          sortOrder: 0,
          createdAt: t1,
          updatedAt: t1,
        ),
      ],
    );

    final source = const TeachingPlannerBackupCodec().encode(
      workspace,
      exportedAt: t2,
      mergeState: state,
    );
    final restored = const TeachingPlannerBackupCodec().decodePayload(source);

    expect(
      restored.mergeState.replicaFor('class', 'class-10')?.localId,
      'local-class',
    );
  });

  test('schema 8 migrates through schema 10 with empty merge and sync state', () {
    final codec = const TeachingPlannerDocumentCodec();
    final legacy = <String, dynamic>{
      'schemaVersion': 8,
      'updatedAt': t1.toIso8601String(),
      'workspace': _officialWorkspace(t1).toJson(),
    };

    final migrated = codec.decodeStored(legacy);

    expect(migrated.localRevision, 1);
    expect(migrated.mergeState.replicas, isEmpty);
    expect(migrated.mergeState.receipts, isEmpty);
    expect(migrated.syncState.isInitialized, isFalse);
  });
}

TeachingPlannerWorkspace _officialWorkspace(
  DateTime updatedAt, {
  String chapterTitle = 'Quadratic Equations',
  String topicTitle = 'Roots',
  String lessonTitle = 'Solve roots',
  String objective = 'Solve quadratic roots.',
}) {
  final createdAt = DateTime.utc(2026, 9, 1);
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'maths',
        classId: 'class-10',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'maths',
        title: chapterTitle,
        sortOrder: 0,
        plannedPeriods: 6,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: topicTitle,
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'lesson-1',
        classId: 'class-10',
        subjectId: 'maths',
        chapterId: 'chapter-1',
        topicIds: const ['topic-1'],
        title: lessonTitle,
        plannedDate: DateTime.utc(2026, 9, 20),
        plannedPeriods: 1,
        objective: objective,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
  );
}

CurriculumPackagePreview _preview(
  TeachingPlannerWorkspace workspace, {
  Map<String, PortablePaperSnapshot> papers = const {},
  Map<String, List<int>> resourceFiles = const {},
}) {
  final lineage = <CurriculumEntityLineage>[
    for (final item in workspace.classes)
      _line('class', item.id, item.updatedAt),
    for (final item in workspace.subjects)
      _line('subject', item.id, item.updatedAt),
    for (final item in workspace.units)
      _line('unit', item.id, item.updatedAt),
    for (final item in workspace.chapters)
      _line('chapter', item.id, item.updatedAt),
    for (final item in workspace.topics)
      _line('topic', item.id, item.updatedAt),
    for (final item in workspace.lessonPlans)
      _line('lessonPlan', item.id, item.updatedAt),
    for (final item in workspace.resources)
      _line('resource', item.id, item.updatedAt),
    for (final snapshot in papers.values)
      _line(
        'paper',
        snapshot.paper.id,
        snapshot.paper.updatedAt,
        originId: snapshot.paper.originId,
        revision: snapshot.paper.revision,
      ),
  ];
  final revision = lineage
      .map((item) => item.revision)
      .fold<int>(1, (a, b) => a > b ? a : b);
  return CurriculumPackagePreview(
    manifest: EdsPackageManifest(
      packageId: 'pkg-$revision',
      contentType: EdsContentType.teacherPack,
      schemaVersion: 1,
      entityId: 'assignment-1',
      originId: 'assignment-1',
      revision: revision,
      title: 'Class 10 Mathematics',
      exportedAt: DateTime.utc(2026, 9, 18),
    ),
    payload: CurriculumPackagePayload(
      contentType: EdsContentType.teacherPack,
      selection: CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.schoolCurriculum,
      ),
      inclusions: const CurriculumPackageInclusions(),
      workspace: workspace,
      resourceFiles: resourceFiles,
      paperSnapshotsJson: <String, dynamic>{
        for (final entry in papers.entries) entry.key: entry.value.toJson(),
      },
      lineage: lineage,
      assignment: const CurriculumAssignmentMetadata(
        assignmentId: 'assignment-1',
        assignedTo: 'Teacher A',
      ),
      sourceSchool: 'ABC School',
    ),
  );
}

CurriculumEntityLineage _line(
  String type,
  String id,
  DateTime updatedAt, {
  String? originId,
  int? revision,
}) {
  return CurriculumEntityLineage(
    entityType: type,
    entityId: id,
    originId: originId ?? id,
    revision: revision ?? updatedAt.millisecondsSinceEpoch,
    updatedAt: updatedAt,
  );
}

class _RejectingMergeRepository
    implements TeachingPlannerRepository, CurriculumMergeRepository {
  TeachingPlannerWorkspace _workspace = TeachingPlannerWorkspace.empty();
  CurriculumMergeState _mergeState = CurriculumMergeState.empty();
  int _localRevision = 1;
  int commitCalls = 0;

  @override
  Future<TeachingPlannerWorkspace> load() async => _workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    _workspace = workspace;
    _localRevision++;
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    _workspace = mutation(_workspace);
    _localRevision++;
    return _workspace;
  }

  @override
  Future<TeachingPlannerWorkspace> updateCurriculumAware(
    CurriculumAwarePlannerMutation mutation,
  ) async {
    _workspace = mutation(_workspace, _mergeState);
    _localRevision++;
    return _workspace;
  }

  @override
  Future<CurriculumMergeRepositorySnapshot> loadCurriculumMergeSnapshot() async {
    return CurriculumMergeRepositorySnapshot(
      workspace: _workspace,
      mergeState: _mergeState,
      localRevision: _localRevision,
    );
  }

  @override
  Future<CurriculumMergeRepositorySnapshot> commitCurriculumMerge({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required int expectedLocalRevision,
  }) async {
    commitCalls++;
    throw StateError('Simulated concurrent planner edit.');
  }

  @override
  Future<void> replaceWorkspaceWithMergeState(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
  ) async {
    _workspace = workspace;
    _mergeState = mergeState;
    _localRevision++;
  }

  @override
  Future<void> replaceWorkspaceAndResetMergeState(
    TeachingPlannerWorkspace workspace,
  ) async {
    _workspace = workspace;
    _mergeState = CurriculumMergeState.empty();
    _localRevision++;
  }
}

class _MemoryPaperRepository implements PaperRepository {
  _MemoryPaperRepository([Iterable<Paper> papers = const []]) {
    for (final paper in papers) {
      _papers[paper.id] = Paper.fromJson(paper.toJson());
    }
  }

  final Map<String, Paper> _papers = <String, Paper>{};

  @override
  Future<List<Paper>> getAllPapers() async => _papers.values
      .map((paper) => Paper.fromJson(paper.toJson()))
      .toList(growable: false);

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = paper;
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
