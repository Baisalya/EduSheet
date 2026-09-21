import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_merge_engine.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_builder_service.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_import_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/data/curriculum_eds_package_codec.dart';
import 'package:edusheet/features/teaching_planner/data/local_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_package.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_chapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_subject.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'principal update re-import preserves teacher progress and teacher-owned resources',
    () async {
      final t1 = DateTime.utc(2026, 9, 18, 9);
      final t2 = DateTime.utc(2026, 9, 19, 9);
      final temp = await Directory.systemTemp.createTemp('eds-phase8-collab-');
      addTearDown(() => temp.delete(recursive: true));

      final principalFiles = TeachingResourceFileStore(
        rootResolver: () async => Directory('${temp.path}/principal-assets'),
      );
      final teacherFiles = TeachingResourceFileStore(
        rootResolver: () async => Directory('${temp.path}/teacher-assets'),
      );
      final principalPapers = _MemoryPaperRepository();
      final teacherPapers = _MemoryPaperRepository();
      final builder = CurriculumPackageBuilderService(
        resourceFileStore: principalFiles,
        paperRepository: principalPapers,
      );
      const codec = CurriculumEdsPackageCodec();
      final selection = CurriculumPackageSelection(
        kind: CurriculumPackageScopeKind.classSyllabus,
        classId: 'class-10',
      );
      const inclusions = CurriculumPackageInclusions(
        includeFiles: false,
        includePapers: false,
      );
      const assignment = CurriculumAssignmentMetadata(
        assignmentId: 'class10-maths-riya-term1',
        assignedTo: 'Riya',
        sourceSchool: 'ABC Public School',
        note: 'Class 10 Mathematics Term 1',
      );

      final principalV1 = _principalWorkspace(t1);
      final buildV1 = await builder.build(
        source: principalV1,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: 'ABC Public School',
      );
      final edsV1 = codec.encode(
        build: buildV1,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: 'ABC Public School',
        exportedAt: t1,
      );
      final receivedV1 = codec.decode(edsV1);

      final teacherRepository = LocalTeachingPlannerRepository(
        fileResolver: () async => File('${temp.path}/teacher-planner.json'),
      );
      final importerV1 = CurriculumPackageImportService(
        plannerRepository: teacherRepository,
        paperRepository: teacherPapers,
        resourceFileStore: teacherFiles,
        mergeEngine: CurriculumMergeEngine(clock: () => t1),
      );
      final firstImport = await importerV1.import(receivedV1);
      expect(firstImport.plan.conflicts, isEmpty);
      expect(firstImport.plan.addedCount, greaterThan(0));

      final teacherService = TeachingPlannerService(
        teacherRepository,
        idGenerator: () => 'teacher-note-1',
        clock: () => t1.add(const Duration(hours: 2)),
      );
      await teacherService.recordLessonProgress(
        'lesson-1',
        status: TeachingProgressStatus.completed,
        actualPeriods: 2,
        taughtAt: t1.add(const Duration(days: 1)),
        reflection: 'Students needed one more worked example.',
      );
      await teacherService.createTeachingResource(
        lessonPlanId: 'lesson-1',
        kind: TeachingResourceKind.note,
        title: 'My classroom note',
        body: 'Use the factor tree example before the exercise.',
      );

      await expectLater(
        teacherService.updateChapter(
          'chapter-1',
          title: 'Teacher should not rewrite official master',
          plannedPeriods: 6,
          priority: principalV1.chapterById('chapter-1')!.priority,
        ),
        throwsA(isA<TeachingPlannerOperationException>()),
      );

      final principalV2 = _principalWorkspace(
        t2,
        chapterTitle: 'Quadratic Equations — Revised',
        lessonTitle: 'Solve and classify roots',
        objective: 'Solve quadratic equations and classify their roots.',
        officialNoteBody: 'Use the revised discriminant example from the master pack.',
      );
      final buildV2 = await builder.build(
        source: principalV2,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: 'ABC Public School',
      );
      final edsV2 = codec.encode(
        build: buildV2,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: 'ABC Public School',
        exportedAt: t2,
      );
      final receivedV2 = codec.decode(edsV2);

      final importerV2 = CurriculumPackageImportService(
        plannerRepository: teacherRepository,
        paperRepository: teacherPapers,
        resourceFileStore: teacherFiles,
        mergeEngine: CurriculumMergeEngine(clock: () => t2),
      );
      final secondImport = await importerV2.import(receivedV2);
      final afterUpdate = await teacherRepository.loadCurriculumMergeSnapshot();

      expect(secondImport.plan.updatedCount, greaterThan(0));
      expect(afterUpdate.workspace.chapterById('chapter-1')?.title,
          'Quadratic Equations — Revised');
      final lesson = afterUpdate.workspace.lessonPlanById('lesson-1')!;
      expect(lesson.title, 'Solve and classify roots');
      expect(lesson.objective,
          'Solve quadratic equations and classify their roots.');
      expect(lesson.actualPeriods, 2);
      expect(lesson.status, TeachingProgressStatus.completed);
      expect(lesson.reflection, 'Students needed one more worked example.');
      expect(
        afterUpdate.workspace.resourceById('official-note-1')?.body,
        'Use the revised discriminant example from the master pack.',
      );
      expect(
        afterUpdate.mergeState.isOfficialLocalId(
          'resource',
          'official-note-1',
        ),
        isTrue,
      );
      expect(
        afterUpdate.workspace.resourceById('teacher-note-1')?.body,
        'Use the factor tree example before the exercise.',
      );
      expect(
        afterUpdate.mergeState.isOfficialLocalId('resource', 'teacher-note-1'),
        isFalse,
      );
      expect(
        afterUpdate.mergeState.replicaFor('chapter', 'chapter-1')?.sourceRevision,
        t2.millisecondsSinceEpoch,
      );

      final staleResult = await importerV2.import(codec.decode(edsV1));
      final afterStale = await teacherRepository.loadCurriculumMergeSnapshot();
      expect(staleResult.plan.staleCount, greaterThan(0));
      expect(afterStale.workspace.chapterById('chapter-1')?.title,
          'Quadratic Equations — Revised');
      expect(afterStale.workspace.resourceById('teacher-note-1'), isNotNull);
    },
  );
}

TeachingPlannerWorkspace _principalWorkspace(
  DateTime updatedAt, {
  String chapterTitle = 'Quadratic Equations',
  String lessonTitle = 'Introduction to roots',
  String objective = 'Understand quadratic roots.',
  String officialNoteBody = 'Use the standard discriminant example.',
}) {
  return TeachingPlannerWorkspace(
    classes: [
      PlannerClass(
        id: 'class-10',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: updatedAt,
      ),
    ],
    subjects: [
      PlannerSubject(
        id: 'maths',
        classId: 'class-10',
        name: 'Mathematics',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 9, 1),
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
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: updatedAt,
      ),
    ],
    topics: [
      PlannerTopic(
        id: 'topic-1',
        chapterId: 'chapter-1',
        title: 'Nature of roots',
        sortOrder: 0,
        plannedPeriods: 2,
        actualPeriods: 0,
        status: TeachingProgressStatus.planned,
        createdAt: DateTime.utc(2026, 9, 1),
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
        status: TeachingProgressStatus.planned,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: updatedAt,
      ),
    ],
    resources: [
      TeachingResource(
        id: 'official-note-1',
        lessonPlanId: 'lesson-1',
        kind: TeachingResourceKind.note,
        title: 'Principal teaching note',
        body: officialNoteBody,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: updatedAt,
      ),
    ],
  );
}

class _MemoryPaperRepository implements PaperRepository {
  final Map<String, Paper> _papers = <String, Paper>{};

  @override
  Future<List<Paper>> getAllPapers() async =>
      _papers.values.toList(growable: false);

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = paper;
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
