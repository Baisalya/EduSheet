import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/eds_import/application/eds_import_router.dart';
import 'package:edusheet/features/eds_import/domain/eds_import_inspection.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_builder_service.dart';
import 'package:edusheet/features/teaching_planner/data/curriculum_eds_package_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_package.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_unit.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  test('selected chapter package preserves hierarchy and excludes siblings', () async {
    final temp = await Directory.systemTemp.createTemp('eds-curriculum-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final filePath = await store.writeBytes(
      resourceId: 'file-r',
      fileName: 'worksheet.pdf',
      bytes: const [1, 2, 3, 4],
    );
    final paper = Paper(
      id: 'paper-1',
      originId: 'paper-origin-1',
      revision: 4,
      updatedAt: now,
      title: 'Quadratic Test',
      createdAt: now,
    );
    final workspace = _workspace(now, filePath: filePath);
    final service = CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: _MemoryPaperRepository([paper]),
    );

    final build = await service.build(
      source: workspace,
      selection: CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.selectedChapters,
        classId: 'class-10',
        subjectId: 'maths',
        chapterIds: const {'chapter-1'},
      ),
      inclusions: const CurriculumPackageInclusions(),
    );

    expect(build.contentType, EdsContentType.chapterPack);
    expect(build.workspace.classes.map((e) => e.id), ['class-10']);
    expect(build.workspace.subjects.map((e) => e.id), ['maths']);
    expect(build.workspace.units.map((e) => e.id), ['unit-1']);
    expect(build.workspace.chapters.map((e) => e.id), ['chapter-1']);
    expect(build.workspace.topics.map((e) => e.id), ['topic-1']);
    expect(build.workspace.lessonPlans.map((e) => e.id), ['lesson-1']);
    expect(build.workspace.chapterById('chapter-2'), isNull);
    expect(build.resourceFiles['file-r'], const [1, 2, 3, 4]);
    expect(build.paperSnapshots.keys, contains('paper-1'));
    expect(
      build.lineage.any(
        (item) =>
            item.entityType == 'paper' && item.originId == 'paper-origin-1',
      ),
      isTrue,
    );
  });

  test('selected unit package excludes sibling units and parent resources', () async {
    final temp = await Directory.systemTemp.createTemp('eds-unit-pack-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final workspace = _workspace(now);
    final selection = CurriculumPackageSelection(
      kind: CurriculumPackageScopeKind.selectedUnits,
      classId: 'class-10',
      subjectId: 'maths',
      unitIds: const {'unit-1'},
    );
    const inclusions = CurriculumPackageInclusions(includePapers: false);
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: _MemoryPaperRepository(),
    ).build(
      source: workspace,
      selection: selection,
      inclusions: inclusions,
    );

    expect(build.contentType, EdsContentType.subjectPack);
    expect(build.workspace.units.map((e) => e.id), ['unit-1']);
    expect(build.workspace.chapters.map((e) => e.id), ['chapter-1']);
    expect(build.workspace.lessonPlans.map((e) => e.id), ['lesson-1']);
    expect(build.workspace.unitById('unit-2'), isNull);
    expect(build.workspace.chapterById('chapter-2'), isNull);
    expect(
      build.workspace.resources.any((r) => r.id == 'subject-note'),
      isFalse,
    );
    expect(build.workspace.resources.any((r) => r.id == 'note-r'), isTrue);

    final source = const CurriculumEdsPackageCodec().encode(
      build: build,
      selection: selection,
      inclusions: inclusions,
      exportedAt: now,
    );
    final preview = const CurriculumEdsPackageCodec().decode(source);
    expect(preview.manifest.contentType, EdsContentType.subjectPack);
    expect(preview.payload.selection.kind, CurriculumPackageScopeKind.selectedUnits);
    expect(preview.payload.selection.unitIds, {'unit-1'});

    final leakedResource = workspace.resources.firstWhere(
      (resource) => resource.id == 'subject-note',
    );
    final invalidBuild = CurriculumPackageBuildResult(
      contentType: build.contentType,
      workspace: build.workspace.copyWith(
        resources: [...build.workspace.resources, leakedResource],
      ),
      resourceFiles: build.resourceFiles,
      paperSnapshots: build.paperSnapshots,
      lineage: build.lineage,
      title: build.title,
      entityId: build.entityId,
      originId: build.originId,
      revision: build.revision,
    );
    expect(
      () => const CurriculumEdsPackageCodec().encode(
        build: invalidBuild,
        selection: selection,
        inclusions: inclusions,
        exportedAt: now,
      ),
      throwsFormatException,
    );
  });

  test('teacher assignment .eds round trip carries scope, assets and intent', () async {
    final temp = await Directory.systemTemp.createTemp('eds-assignment-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final filePath = await store.writeBytes(
      resourceId: 'file-r',
      fileName: 'worksheet.pdf',
      bytes: const [9, 8, 7],
    );
    final paper = Paper(
      id: 'paper-1',
      originId: 'paper-origin-1',
      revision: 2,
      updatedAt: now,
      title: 'Quadratic Test',
      createdAt: now,
    );
    final repository = _MemoryPaperRepository([paper]);
    final workspace = _workspace(now, filePath: filePath);
    final selection = CurriculumPackageSelection(
      kind: CurriculumPackageScopeKind.subject,
      classId: 'class-10',
      subjectId: 'maths',
    );
    const inclusions = CurriculumPackageInclusions();
    const assignment = CurriculumAssignmentMetadata(
      assignmentId: 'assignment:abc:riya:2026-27:maths',
      assignedTo: 'Riya Maam',
      sourceSchool: 'ABC Public School',
      note: 'Teach Chapters 1-2 in Term 1',
    );
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: repository,
    ).build(
      source: workspace,
      selection: selection,
      inclusions: inclusions,
      assignment: assignment,
    );
    final source = const CurriculumEdsPackageCodec().encode(
      build: build,
      selection: selection,
      inclusions: inclusions,
      assignment: assignment,
      sourceSchool: 'ABC Public School',
      exportedAt: now,
    );

    final preview = const CurriculumEdsPackageCodec().decode(source);

    expect(source, startsWith('EDUSHEET/4'));
    expect(preview.manifest.contentType, EdsContentType.teacherPack);
    expect(preview.manifest.originId, assignment.assignmentId);
    expect(preview.manifest.metadata['sourceSchool'], 'ABC Public School');
    expect(preview.manifest.metadata['assignedTo'], 'Riya Maam');
    expect(preview.payload.assignment?.assignmentId, assignment.assignmentId);
    expect(preview.payload.sourceSchool, 'ABC Public School');
    expect(preview.payload.workspace.subjectById('maths'), isNotNull);
    expect(preview.payload.resourceFiles['file-r'], const [9, 8, 7]);
    expect(preview.payload.paperCount, 1);
    expect(preview.payload.lineage, isNotEmpty);
  });

  test('curriculum manifest identity must match the selected scope', () async {
    final temp = await Directory.systemTemp.createTemp('eds-identity-pack-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final selection = CurriculumPackageSelection(
      kind: CurriculumPackageScopeKind.selectedChapters,
      classId: 'class-10',
      subjectId: 'maths',
      chapterIds: const {'chapter-1'},
    );
    const inclusions = CurriculumPackageInclusions(includePapers: false);
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: _MemoryPaperRepository(),
    ).build(
      source: _workspace(now),
      selection: selection,
      inclusions: inclusions,
    );
    final encoded = const CurriculumEdsPackageCodec().encode(
      build: build,
      selection: selection,
      inclusions: inclusions,
      exportedAt: now,
    );
    final decoded = const EdsUnifiedContainer().decode(encoded);
    final tampered = const EdsUnifiedContainer().encode(
      manifest: EdsPackageManifest(
        packageId: decoded.manifest.packageId,
        contentType: decoded.manifest.contentType,
        schemaVersion: decoded.manifest.schemaVersion,
        entityId: 'chapters:wrong-id',
        originId: 'chapters:wrong-id',
        revision: decoded.manifest.revision,
        title: decoded.manifest.title,
        exportedAt: decoded.manifest.exportedAt,
        metadata: decoded.manifest.metadata,
      ),
      payload: decoded.payload,
    );

    expect(
      () => const CurriculumEdsPackageCodec().decode(tampered),
      throwsFormatException,
    );
  });

  test('teacher assignment rejects conflicting school metadata', () async {
    final temp = await Directory.systemTemp.createTemp('eds-school-pack-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final selection = CurriculumPackageSelection(
      kind: CurriculumPackageScopeKind.classSyllabus,
      classId: 'class-10',
    );
    const inclusions = CurriculumPackageInclusions(includePapers: false);
    const assignment = CurriculumAssignmentMetadata(
      assignmentId: 'assignment-school-conflict',
      assignedTo: 'Teacher A',
      sourceSchool: 'ABC Public School',
    );
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: _MemoryPaperRepository(),
    ).build(
      source: _workspace(now),
      selection: selection,
      inclusions: inclusions,
      assignment: assignment,
    );

    expect(
      () => const CurriculumEdsPackageCodec().encode(
        build: build,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: 'Different School',
        exportedAt: now,
      ),
      throwsFormatException,
    );
  });

  test('unified router validates assignment pack and exposes merge import', () async {
    final temp = await Directory.systemTemp.createTemp('eds-router-pack-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final workspace = _workspace(now);
    final repository = _MemoryPaperRepository();
    final selection = CurriculumPackageSelection(
      kind: CurriculumPackageScopeKind.classSyllabus,
      classId: 'class-10',
    );
    const inclusions = CurriculumPackageInclusions(
      includeFiles: false,
      includePapers: false,
    );
    const assignment = CurriculumAssignmentMetadata(
      assignmentId: 'assignment-class-10',
      assignedTo: 'Teacher A',
    );
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: repository,
    ).build(
      source: workspace,
      selection: selection,
      inclusions: inclusions,
      assignment: assignment,
    );
    final source = const CurriculumEdsPackageCodec().encode(
      build: build,
      selection: selection,
      inclusions: inclusions,
      assignment: assignment,
      exportedAt: now,
    );

    final inspection = await EdsImportRouter(
      paperRepository: repository,
    ).inspect(source);

    expect(inspection, isA<CurriculumPackageEdsImportInspection>());
    expect(inspection.contentType, EdsContentType.teacherPack);
    expect(inspection.destinationLabel, 'Teacher Workspace');
    expect(inspection.canImport, isTrue);
  });

  test('resource filters remove excluded portable content cleanly', () async {
    final temp = await Directory.systemTemp.createTemp('eds-filter-pack-');
    addTearDown(() => temp.delete(recursive: true));
    final store = TeachingResourceFileStore(rootResolver: () async => temp);
    final filePath = await store.writeBytes(
      resourceId: 'file-r',
      fileName: 'worksheet.pdf',
      bytes: const [1],
    );
    final workspace = _workspace(now, filePath: filePath);
    final build = await CurriculumPackageBuilderService(
      resourceFileStore: store,
      paperRepository: _MemoryPaperRepository(),
    ).build(
      source: workspace,
      selection: CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.subject,
        classId: 'class-10',
        subjectId: 'maths',
      ),
      inclusions: const CurriculumPackageInclusions(
        includeFiles: false,
        includePapers: false,
      ),
    );

    expect(
      build.workspace.resources.any((r) => r.kind == TeachingResourceKind.file),
      isFalse,
    );
    expect(
      build.workspace.resources.any((r) => r.kind == TeachingResourceKind.paper),
      isFalse,
    );
    expect(build.resourceFiles, isEmpty);
    expect(build.paperSnapshots, isEmpty);
  });

  test('malformed curriculum-looking v4 file is rejected, not trusted by type', () async {
    final source = const EdsUnifiedContainer().encode(
      manifest: EdsPackageManifest(
        packageId: 'fake',
        contentType: EdsContentType.chapterPack,
        schemaVersion: 1,
        entityId: 'chapter-1',
        originId: 'chapter-1',
        revision: 1,
        title: 'Fake chapter',
        exportedAt: now,
      ),
      payload: const <String, dynamic>{'chapter': <String, dynamic>{}},
    );

    await expectLater(
      EdsImportRouter(paperRepository: _MemoryPaperRepository()).inspect(source),
      throwsFormatException,
    );
  });
}

TeachingPlannerWorkspace _workspace(DateTime now, {String? filePath}) {
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'maths',
        classId: 'class-10',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    units: [
      PlannerUnit(
        id: 'unit-1',
        subjectId: 'maths',
        title: 'Algebra',
        sortOrder: 0,
        plannedPeriods: 12,
        priority: PlannerPriority.high,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerUnit(
        id: 'unit-2',
        subjectId: 'maths',
        title: 'Sequences',
        sortOrder: 1,
        plannedPeriods: 8,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    chapters: [
      PlannerChapter(
        id: 'chapter-1',
        subjectId: 'maths',
        unitId: 'unit-1',
        title: 'Quadratic Equations',
        sortOrder: 0,
        plannedPeriods: 6,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerChapter(
        id: 'chapter-2',
        subjectId: 'maths',
        unitId: 'unit-2',
        title: 'Sequences',
        sortOrder: 1,
        plannedPeriods: 6,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: 'Roots',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
      PlannerTopic(
        id: 'topic-2',
        chapterId: 'chapter-2',
        title: 'AP',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    lessonPlans: [
      LessonPlan(
        id: 'lesson-1',
        classId: 'class-10',
        subjectId: 'maths',
        chapterId: 'chapter-1',
        topicIds: const ['topic-1'],
        title: 'Solve quadratic roots',
        plannedDate: now,
        plannedPeriods: 1,
        objective: 'Solve quadratic equations by factorisation.',
        createdAt: now,
        updatedAt: now,
      ),
      LessonPlan(
        id: 'lesson-2',
        classId: 'class-10',
        subjectId: 'maths',
        chapterId: 'chapter-2',
        topicIds: const ['topic-2'],
        title: 'Arithmetic progression',
        plannedDate: now.add(const Duration(days: 1)),
        plannedPeriods: 1,
        objective: 'Identify arithmetic progressions.',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    resources: [
      TeachingResource(
        id: 'subject-note',
        owner: const TeachingResourceOwner.subject('maths'),
        kind: TeachingResourceKind.note,
        title: 'Whole subject note',
        body: 'Do not leak into a selected unit package.',
        createdAt: now,
        updatedAt: now,
      ),
      TeachingResource(
        id: 'note-r',
        owner: const TeachingResourceOwner.chapter('chapter-1'),
        kind: TeachingResourceKind.note,
        title: 'Board notes',
        body: 'Key factorisation steps',
        createdAt: now,
        updatedAt: now,
      ),
      if (filePath != null)
        TeachingResource(
          id: 'file-r',
          owner: const TeachingResourceOwner.lessonPlan('lesson-1'),
          kind: TeachingResourceKind.file,
          title: 'Worksheet',
          originalFileName: 'worksheet.pdf',
          mimeType: 'application/pdf',
          localRelativePath: filePath,
          sizeBytes: 4,
          createdAt: now,
          updatedAt: now,
        ),
      TeachingResource(
        id: 'paper-r',
        owner: const TeachingResourceOwner.chapter('chapter-1'),
        kind: TeachingResourceKind.paper,
        title: 'Quadratic Test',
        linkedPaperId: 'paper-1',
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
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
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
