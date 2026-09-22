import 'package:uuid/uuid.dart';

import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/lesson_plan.dart';
import '../domain/models/offline_sync_state.dart';
import '../domain/models/planner_chapter.dart';
import '../domain/models/planner_class.dart';
import '../domain/models/planner_priority.dart';
import '../domain/models/planner_subject.dart';
import '../domain/models/planner_topic.dart';
import '../domain/models/planner_unit.dart';
import '../domain/models/syllabus_import_package.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/models/teaching_resource_owner.dart';
import '../domain/models/teaching_status.dart';
import '../domain/repositories/curriculum_merge_repository.dart';
import '../domain/repositories/offline_sync_repository.dart';
import '../domain/repositories/teaching_planner_repository.dart';

class TeachingPlannerOperationException implements Exception {
  final String message;

  const TeachingPlannerOperationException(this.message);

  @override
  String toString() => 'TeachingPlannerOperationException: $message';
}

typedef PlannerIdGenerator = String Function();
typedef PlannerClock = DateTime Function();

class TeachingFileResourceDraft {
  final String id;
  final TeachingResourceRole role;
  final String title;
  final String originalFileName;
  final String? mimeType;
  final String? localRelativePath;
  final TeachingResourceFileOwnership fileOwnership;
  final String? externalFilePath;
  final int sizeBytes;
  final String? contentSha256;

  const TeachingFileResourceDraft({
    required this.id,
    this.role = TeachingResourceRole.teachInClass,
    required this.title,
    required this.originalFileName,
    this.mimeType,
    this.localRelativePath,
    this.fileOwnership = TeachingResourceFileOwnership.managed,
    this.externalFilePath,
    required this.sizeBytes,
    this.contentSha256,
  });
}

class TeachingPlannerService {
  TeachingPlannerService(
    this._repository, {
    PlannerIdGenerator? idGenerator,
    PlannerClock? clock,
  }) : _idGenerator = idGenerator ?? (() => Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final TeachingPlannerRepository _repository;
  final PlannerIdGenerator _idGenerator;
  final PlannerClock _clock;

  Future<TeachingPlannerWorkspace> load() => _repository.load();

  Future<CurriculumMergeState> loadCurriculumMergeState() async {
    final repository = _repository;
    final mergeRepository = switch (repository) {
      CurriculumMergeRepository value => value,
      _ => null,
    };
    if (mergeRepository == null) return CurriculumMergeState.empty();
    return (await mergeRepository.loadCurriculumMergeSnapshot()).mergeState;
  }

  Future<TeachingPlannerWorkspace> _updateCurriculumAware(
    CurriculumAwarePlannerMutation mutation,
  ) {
    final repository = _repository;
    final mergeRepository = switch (repository) {
      CurriculumMergeRepository value => value,
      _ => null,
    };
    if (mergeRepository != null) {
      return mergeRepository.updateCurriculumAware(mutation);
    }
    return repository.update(
      (workspace) => mutation(workspace, CurriculumMergeState.empty()),
    );
  }

  static void _requireTeacherOwned(
    CurriculumMergeState mergeState,
    String entityType,
    String localId,
    String label,
  ) {
    if (!mergeState.isOfficialLocalId(entityType, localId)) return;
    throw TeachingPlannerOperationException(
      '$label belongs to the official curriculum. Keep the master structure unchanged and add teacher notes, resources, papers or progress in your working layer instead.',
    );
  }

  Future<TeachingPlannerWorkspace> restoreWorkspace(
    TeachingPlannerWorkspace workspace,
  ) => restoreWorkspaceWithMergeState(workspace, CurriculumMergeState.empty());

  Future<TeachingPlannerWorkspace> restoreWorkspaceWithMergeState(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
  ) => restoreWorkspaceWithSyncMetadata(
    workspace,
    mergeState,
    OfflineSyncState.uninitialized(),
  );

  Future<TeachingPlannerWorkspace> restoreWorkspaceWithSyncMetadata(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
    OfflineSyncState syncState,
  ) async {
    final repository = _repository;
    final syncRepository = switch (repository) {
      OfflineSyncRepository value => value,
      _ => null,
    };
    if (syncRepository != null) {
      await syncRepository.replaceWorkspaceWithSyncMetadata(
        workspace: workspace,
        mergeState: mergeState,
        syncState: syncState,
      );
      return workspace;
    }
    final mergeRepository = switch (repository) {
      CurriculumMergeRepository value => value,
      _ => null,
    };
    if (mergeRepository != null) {
      await mergeRepository.replaceWorkspaceWithMergeState(
        workspace,
        mergeState,
      );
    } else {
      await repository.save(workspace);
    }
    return workspace;
  }

  Future<TeachingPlannerWorkspace> createClass({
    required String name,
    String? academicYear,
  }) {
    final cleanName = _requiredName(name, 'Class name');
    final cleanYear = _optionalText(academicYear);
    return _repository.update((workspace) {
      final now = _now();
      return workspace.copyWith(
        classes: [
          ...workspace.classes,
          PlannerClass(
            id: _idGenerator(),
            name: cleanName,
            academicYear: cleanYear,
            sortOrder: _nextSortOrder(
              workspace.classes
                  .where((item) => !item.isArchived)
                  .map((item) => item.sortOrder),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateClass(
    String classId, {
    required String name,
    Object? academicYear = _unset,
  }) {
    final cleanName = _requiredName(name, 'Class name');
    final cleanYear = academicYear is String
        ? _optionalText(academicYear)
        : null;
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'class', classId, 'Class');

      final item = workspace.classById(classId);
      _requireActive(item != null && !item.isArchived, 'Class', classId);
      final now = _now();
      return workspace.copyWith(
        classes: workspace.classes
            .map(
              (value) => value.id == classId
                  ? value.copyWith(
                      name: cleanName,
                      academicYear: identical(academicYear, _unset)
                          ? value.academicYear
                          : cleanYear,
                      updatedAt: now,
                    )
                  : value,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> createSubject({
    required String classId,
    required String name,
    String? code,
  }) {
    final cleanName = _requiredName(name, 'Subject name');
    final cleanCode = _optionalText(code);
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'class', classId, 'Class');

      final parent = workspace.classById(classId);
      _requireActive(parent != null && !parent.isArchived, 'Class', classId);
      final now = _now();
      final siblings = workspace.subjects.where(
        (item) => item.classId == classId && !item.isArchived,
      );
      return workspace.copyWith(
        subjects: [
          ...workspace.subjects,
          PlannerSubject(
            id: _idGenerator(),
            classId: classId,
            name: cleanName,
            code: cleanCode,
            sortOrder: _nextSortOrder(siblings.map((item) => item.sortOrder)),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateSubject(
    String subjectId, {
    required String name,
    Object? code = _unset,
  }) {
    final cleanName = _requiredName(name, 'Subject name');
    final cleanCode = code is String ? _optionalText(code) : null;
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');

      final item = workspace.subjectById(subjectId);
      _requireActive(item != null && !item.isArchived, 'Subject', subjectId);
      final now = _now();
      return workspace.copyWith(
        subjects: workspace.subjects
            .map(
              (value) => value.id == subjectId
                  ? value.copyWith(
                      name: cleanName,
                      code: identical(code, _unset) ? value.code : cleanCode,
                      updatedAt: now,
                    )
                  : value,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> createUnit({
    required String subjectId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
  }) {
    final cleanTitle = _requiredName(title, 'Unit title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');

      final parent = workspace.subjectById(subjectId);
      _requireActive(
        parent != null && !parent.isArchived,
        'Subject',
        subjectId,
      );
      final now = _now();
      final siblings = workspace.units.where(
        (item) => item.subjectId == subjectId && !item.isArchived,
      );
      return workspace.copyWith(
        units: [
          ...workspace.units,
          PlannerUnit(
            id: _idGenerator(),
            subjectId: subjectId,
            title: cleanTitle,
            sortOrder: _nextSortOrder(siblings.map((item) => item.sortOrder)),
            plannedPeriods: plannedPeriods,
            priority: priority,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateUnit(
    String unitId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) {
    final cleanTitle = _requiredName(title, 'Unit title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');

      final item = workspace.unitById(unitId);
      _requireActive(item != null && !item.isArchived, 'Unit', unitId);
      final now = _now();
      return workspace.copyWith(
        units: workspace.units
            .map(
              (value) => value.id == unitId
                  ? value.copyWith(
                      title: cleanTitle,
                      plannedPeriods: plannedPeriods,
                      priority: priority,
                      updatedAt: now,
                    )
                  : value,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> createChapter({
    required String subjectId,
    String? unitId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
  }) {
    final cleanTitle = _requiredName(title, 'Chapter title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      if (unitId != null) {
        _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
      }

      _validateChapterParent(workspace, subjectId, unitId);
      final now = _now();
      final siblings = workspace.chapters.where(
        (item) =>
            item.subjectId == subjectId &&
            item.unitId == unitId &&
            !item.isArchived,
      );
      return workspace.copyWith(
        chapters: [
          ...workspace.chapters,
          PlannerChapter(
            id: _idGenerator(),
            subjectId: subjectId,
            unitId: unitId,
            title: cleanTitle,
            sortOrder: _nextSortOrder(siblings.map((item) => item.sortOrder)),
            plannedPeriods: plannedPeriods,
            priority: priority,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateChapter(
    String chapterId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
    Object? unitId = _unset,
  }) {
    final cleanTitle = _requiredName(title, 'Chapter title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');

      final item = workspace.chapterById(chapterId);
      _requireActive(item != null && !item.isArchived, 'Chapter', chapterId);
      final nextUnitId = identical(unitId, _unset)
          ? item!.unitId
          : unitId as String?;
      _validateChapterParent(workspace, item!.subjectId, nextUnitId);
      final now = _now();
      final siblings = workspace.chapters.where(
        (value) =>
            value.subjectId == item.subjectId &&
            value.unitId == nextUnitId &&
            value.id != chapterId &&
            !value.isArchived,
      );
      final requestedOrder = siblings.isEmpty
          ? 0
          : _nextSortOrder(siblings.map((value) => value.sortOrder));
      return workspace.copyWith(
        chapters: workspace.chapters
            .map(
              (value) => value.id == chapterId
                  ? value.copyWith(
                      unitId: nextUnitId,
                      title: cleanTitle,
                      plannedPeriods: plannedPeriods,
                      priority: priority,
                      sortOrder: nextUnitId == item.unitId
                          ? item.sortOrder
                          : requestedOrder,
                      updatedAt: now,
                    )
                  : value,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> createTopic({
    required String chapterId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
    DateTime? plannedStart,
    DateTime? plannedEnd,
  }) {
    final cleanTitle = _requiredName(title, 'Topic title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    _validateDateRange(plannedStart, plannedEnd);
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');

      final parent = workspace.chapterById(chapterId);
      _requireActive(
        parent != null && !parent.isArchived,
        'Chapter',
        chapterId,
      );
      final now = _now();
      final siblings = workspace.topics.where(
        (item) => item.chapterId == chapterId && !item.isArchived,
      );
      return workspace.copyWith(
        topics: [
          ...workspace.topics,
          PlannerTopic(
            id: _idGenerator(),
            chapterId: chapterId,
            title: cleanTitle,
            sortOrder: _nextSortOrder(siblings.map((item) => item.sortOrder)),
            plannedPeriods: plannedPeriods,
            priority: priority,
            actualPeriods: 0,
            status: TeachingProgressStatus.planned,
            plannedStart: plannedStart?.toUtc(),
            plannedEnd: plannedEnd?.toUtc(),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateTopic(
    String topicId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
    Object? plannedStart = _unset,
    Object? plannedEnd = _unset,
  }) {
    final cleanTitle = _requiredName(title, 'Topic title');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');

      final item = workspace.topicById(topicId);
      _requireActive(item != null && !item.isArchived, 'Topic', topicId);
      final nextStart = identical(plannedStart, _unset)
          ? item!.plannedStart
          : plannedStart as DateTime?;
      final nextEnd = identical(plannedEnd, _unset)
          ? item!.plannedEnd
          : plannedEnd as DateTime?;
      _validateDateRange(nextStart, nextEnd);
      final now = _now();
      return workspace.copyWith(
        topics: workspace.topics
            .map(
              (value) => value.id == topicId
                  ? value.copyWith(
                      title: cleanTitle,
                      plannedPeriods: plannedPeriods,
                      priority: priority,
                      plannedStart: nextStart,
                      plannedEnd: nextEnd,
                      updatedAt: now,
                    )
                  : value,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> moveSubject({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final subject = workspace.subjectById(subjectId);
      final destinationClass = workspace.classById(destinationClassId);
      _requireActive(subject != null && !subject.isArchived, 'Subject', subjectId);
      _requireActive(
        destinationClass != null && !destinationClass.isArchived,
        'Class',
        destinationClassId,
      );
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      _requireTeacherOwned(
        mergeState,
        'class',
        destinationClassId,
        'Destination class',
      );
      _requireTeacherOwnedSubjectTree(workspace, mergeState, subjectId);
      if (subject!.classId == destinationClassId) return workspace;
      _requireUniqueSubjectName(
        workspace,
        classId: destinationClassId,
        name: subject.name,
      );

      final now = _now();
      final nextOrder = _nextSortOrder(
        workspace.subjects
            .where(
              (item) =>
                  item.classId == destinationClassId && !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        subjects: workspace.subjects
            .map(
              (item) => item.id == subjectId
                  ? item.copyWith(
                      classId: destinationClassId,
                      sortOrder: nextOrder,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.subjectId == subjectId
                  ? item.copyWith(classId: destinationClassId, updatedAt: now)
                  : item,
            )
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> moveUnit({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final unit = workspace.unitById(unitId);
      final destinationSubject = workspace.subjectById(destinationSubjectId);
      _requireActive(unit != null && !unit.isArchived, 'Unit', unitId);
      _requireActive(
        destinationSubject != null && !destinationSubject.isArchived,
        'Subject',
        destinationSubjectId,
      );
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
      _requireTeacherOwned(
        mergeState,
        'subject',
        destinationSubjectId,
        'Destination subject',
      );
      _requireTeacherOwnedUnitTree(workspace, mergeState, unitId);
      if (unit!.subjectId == destinationSubjectId) return workspace;
      _requireUniqueUnitTitle(
        workspace,
        subjectId: destinationSubjectId,
        title: unit.title,
      );

      final chapterIds = workspace.chapters
          .where((item) => item.unitId == unitId)
          .map((item) => item.id)
          .toSet();
      final now = _now();
      final nextOrder = _nextSortOrder(
        workspace.units
            .where(
              (item) =>
                  item.subjectId == destinationSubjectId && !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        units: workspace.units
            .map(
              (item) => item.id == unitId
                  ? item.copyWith(
                      subjectId: destinationSubjectId,
                      sortOrder: nextOrder,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
        chapters: workspace.chapters
            .map(
              (item) => chapterIds.contains(item.id)
                  ? item.copyWith(
                      subjectId: destinationSubjectId,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => chapterIds.contains(item.chapterId)
                  ? item.copyWith(
                      classId: destinationSubject!.classId,
                      subjectId: destinationSubjectId,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> moveChapter({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final chapter = workspace.chapterById(chapterId);
      final destinationSubject = workspace.subjectById(destinationSubjectId);
      _requireActive(chapter != null && !chapter.isArchived, 'Chapter', chapterId);
      _requireActive(
        destinationSubject != null && !destinationSubject.isArchived,
        'Subject',
        destinationSubjectId,
      );
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');
      _requireTeacherOwned(
        mergeState,
        'subject',
        destinationSubjectId,
        'Destination subject',
      );
      _requireTeacherOwnedChapterTree(workspace, mergeState, chapterId);
      if (destinationUnitId != null) {
        _requireTeacherOwned(
          mergeState,
          'unit',
          destinationUnitId,
          'Destination unit',
        );
      }
      _validateChapterParent(
        workspace,
        destinationSubjectId,
        destinationUnitId,
      );
      if (chapter!.subjectId == destinationSubjectId &&
          chapter.unitId == destinationUnitId) {
        return workspace;
      }
      _requireUniqueChapterTitle(
        workspace,
        subjectId: destinationSubjectId,
        unitId: destinationUnitId,
        title: chapter.title,
        excludingId: chapterId,
      );

      final now = _now();
      final nextOrder = _nextSortOrder(
        workspace.chapters
            .where(
              (item) =>
                  item.subjectId == destinationSubjectId &&
                  item.unitId == destinationUnitId &&
                  item.id != chapterId &&
                  !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        chapters: workspace.chapters
            .map(
              (item) => item.id == chapterId
                  ? item.copyWith(
                      subjectId: destinationSubjectId,
                      unitId: destinationUnitId,
                      sortOrder: nextOrder,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.chapterId == chapterId
                  ? item.copyWith(
                      classId: destinationSubject!.classId,
                      subjectId: destinationSubjectId,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> moveTopic({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final topic = workspace.topicById(topicId);
      final destinationChapter = workspace.chapterById(destinationChapterId);
      _requireActive(topic != null && !topic.isArchived, 'Topic', topicId);
      _requireActive(
        destinationChapter != null && !destinationChapter.isArchived,
        'Chapter',
        destinationChapterId,
      );
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');
      _requireTeacherOwned(
        mergeState,
        'chapter',
        destinationChapterId,
        'Destination chapter',
      );
      if (topic!.chapterId == destinationChapterId) return workspace;
      _requireUniqueTopicTitle(
        workspace,
        chapterId: destinationChapterId,
        title: topic.title,
        excludingId: topicId,
      );

      final now = _now();
      final nextOrder = _nextSortOrder(
        workspace.topics
            .where(
              (item) =>
                  item.chapterId == destinationChapterId &&
                  item.id != topicId &&
                  !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        topics: workspace.topics
            .map(
              (item) => item.id == topicId
                  ? item.copyWith(
                      chapterId: destinationChapterId,
                      sortOrder: nextOrder,
                      updatedAt: now,
                    )
                  : item,
            )
            .toList(growable: false),
        lessonPlans: workspace.lessonPlans
            .map((lesson) {
              if (!lesson.topicIds.contains(topicId) ||
                  lesson.chapterId == destinationChapterId) {
                return lesson;
              }
              return lesson.copyWith(
                topicIds: lesson.topicIds
                    .where((id) => id != topicId)
                    .toList(growable: false),
                updatedAt: now,
              );
            })
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> duplicateSubjectStructure({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final source = workspace.subjectById(subjectId);
      final destinationClass = workspace.classById(destinationClassId);
      _requireActive(source != null && !source.isArchived, 'Subject', subjectId);
      _requireActive(
        destinationClass != null && !destinationClass.isArchived,
        'Class',
        destinationClassId,
      );
      _requireTeacherOwnedSubjectTree(workspace, mergeState, subjectId);
      _requireTeacherOwned(
        mergeState,
        'class',
        destinationClassId,
        'Destination class',
      );

      final now = _now();
      final newSubjectId = _idGenerator();
      final newSubjectName = _uniqueCopyName(
        source!.name,
        workspace.subjects
            .where(
              (item) => item.classId == destinationClassId && !item.isArchived,
            )
            .map((item) => item.name),
      );
      final unitIdMap = <String, String>{};
      final chapterIdMap = <String, String>{};
      final unitsToCopy = workspace.units
          .where((item) => item.subjectId == subjectId && !item.isArchived)
          .toList();
      final chaptersToCopy = workspace.chapters
          .where((item) => item.subjectId == subjectId && !item.isArchived)
          .toList();
      final chapterIds = chaptersToCopy.map((item) => item.id).toSet();
      final topicsToCopy = workspace.topics
          .where((item) => chapterIds.contains(item.chapterId) && !item.isArchived)
          .toList();

      for (final unit in unitsToCopy) {
        unitIdMap[unit.id] = _idGenerator();
      }
      for (final chapter in chaptersToCopy) {
        chapterIdMap[chapter.id] = _idGenerator();
      }

      final subjectOrder = _nextSortOrder(
        workspace.subjects
            .where(
              (item) => item.classId == destinationClassId && !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        subjects: [
          ...workspace.subjects,
          PlannerSubject(
            id: newSubjectId,
            classId: destinationClassId,
            name: newSubjectName,
            code: source.code,
            sortOrder: subjectOrder,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        units: [
          ...workspace.units,
          for (final unit in unitsToCopy)
            PlannerUnit(
              id: unitIdMap[unit.id]!,
              subjectId: newSubjectId,
              title: unit.title,
              sortOrder: unit.sortOrder,
              plannedPeriods: unit.plannedPeriods,
              priority: unit.priority,
              createdAt: now,
              updatedAt: now,
            ),
        ],
        chapters: [
          ...workspace.chapters,
          for (final chapter in chaptersToCopy)
            PlannerChapter(
              id: chapterIdMap[chapter.id]!,
              subjectId: newSubjectId,
              unitId: chapter.unitId == null ? null : unitIdMap[chapter.unitId!],
              title: chapter.title,
              sortOrder: chapter.sortOrder,
              plannedPeriods: chapter.plannedPeriods,
              priority: chapter.priority,
              status: TeachingProgressStatus.planned,
              createdAt: now,
              updatedAt: now,
            ),
        ],
        topics: [
          ...workspace.topics,
          for (final topic in topicsToCopy)
            PlannerTopic(
              id: _idGenerator(),
              chapterId: chapterIdMap[topic.chapterId]!,
              title: topic.title,
              sortOrder: topic.sortOrder,
              plannedPeriods: topic.plannedPeriods,
              priority: topic.priority,
              actualPeriods: 0,
              status: TeachingProgressStatus.planned,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> duplicateUnitStructure({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final source = workspace.unitById(unitId);
      final destinationSubject = workspace.subjectById(destinationSubjectId);
      _requireActive(source != null && !source.isArchived, 'Unit', unitId);
      _requireActive(
        destinationSubject != null && !destinationSubject.isArchived,
        'Subject',
        destinationSubjectId,
      );
      _requireTeacherOwnedUnitTree(workspace, mergeState, unitId);
      _requireTeacherOwned(
        mergeState,
        'subject',
        destinationSubjectId,
        'Destination subject',
      );

      final now = _now();
      final newUnitId = _idGenerator();
      final newUnitTitle = _uniqueCopyName(
        source!.title,
        workspace.units
            .where(
              (item) => item.subjectId == destinationSubjectId && !item.isArchived,
            )
            .map((item) => item.title),
      );
      final chaptersToCopy = workspace.chapters
          .where((item) => item.unitId == unitId && !item.isArchived)
          .toList();
      final chapterIdMap = <String, String>{
        for (final chapter in chaptersToCopy) chapter.id: _idGenerator(),
      };
      final chapterIds = chaptersToCopy.map((item) => item.id).toSet();
      final topicsToCopy = workspace.topics
          .where((item) => chapterIds.contains(item.chapterId) && !item.isArchived)
          .toList();
      final unitOrder = _nextSortOrder(
        workspace.units
            .where(
              (item) => item.subjectId == destinationSubjectId && !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        units: [
          ...workspace.units,
          PlannerUnit(
            id: newUnitId,
            subjectId: destinationSubjectId,
            title: newUnitTitle,
            sortOrder: unitOrder,
            plannedPeriods: source.plannedPeriods,
            priority: source.priority,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        chapters: [
          ...workspace.chapters,
          for (final chapter in chaptersToCopy)
            PlannerChapter(
              id: chapterIdMap[chapter.id]!,
              subjectId: destinationSubjectId,
              unitId: newUnitId,
              title: chapter.title,
              sortOrder: chapter.sortOrder,
              plannedPeriods: chapter.plannedPeriods,
              priority: chapter.priority,
              status: TeachingProgressStatus.planned,
              createdAt: now,
              updatedAt: now,
            ),
        ],
        topics: [
          ...workspace.topics,
          for (final topic in topicsToCopy)
            PlannerTopic(
              id: _idGenerator(),
              chapterId: chapterIdMap[topic.chapterId]!,
              title: topic.title,
              sortOrder: topic.sortOrder,
              plannedPeriods: topic.plannedPeriods,
              priority: topic.priority,
              actualPeriods: 0,
              status: TeachingProgressStatus.planned,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> duplicateChapterStructure({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final source = workspace.chapterById(chapterId);
      _requireActive(source != null && !source.isArchived, 'Chapter', chapterId);
      _requireTeacherOwnedChapterTree(workspace, mergeState, chapterId);
      _requireTeacherOwned(
        mergeState,
        'subject',
        destinationSubjectId,
        'Destination subject',
      );
      if (destinationUnitId != null) {
        _requireTeacherOwned(
          mergeState,
          'unit',
          destinationUnitId,
          'Destination unit',
        );
      }
      _validateChapterParent(
        workspace,
        destinationSubjectId,
        destinationUnitId,
      );
      final now = _now();
      final newChapterId = _idGenerator();
      final newTitle = _uniqueCopyName(
        source!.title,
        workspace.chapters
            .where(
              (item) =>
                  item.subjectId == destinationSubjectId &&
                  item.unitId == destinationUnitId &&
                  !item.isArchived,
            )
            .map((item) => item.title),
      );
      final chapterOrder = _nextSortOrder(
        workspace.chapters
            .where(
              (item) =>
                  item.subjectId == destinationSubjectId &&
                  item.unitId == destinationUnitId &&
                  !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      final topicsToCopy = workspace.topics
          .where((item) => item.chapterId == chapterId && !item.isArchived)
          .toList();
      return workspace.copyWith(
        chapters: [
          ...workspace.chapters,
          PlannerChapter(
            id: newChapterId,
            subjectId: destinationSubjectId,
            unitId: destinationUnitId,
            title: newTitle,
            sortOrder: chapterOrder,
            plannedPeriods: source.plannedPeriods,
            priority: source.priority,
            status: TeachingProgressStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        topics: [
          ...workspace.topics,
          for (final topic in topicsToCopy)
            PlannerTopic(
              id: _idGenerator(),
              chapterId: newChapterId,
              title: topic.title,
              sortOrder: topic.sortOrder,
              plannedPeriods: topic.plannedPeriods,
              priority: topic.priority,
              actualPeriods: 0,
              status: TeachingProgressStatus.planned,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> duplicateTopicStructure({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final source = workspace.topicById(topicId);
      final destinationChapter = workspace.chapterById(destinationChapterId);
      _requireActive(source != null && !source.isArchived, 'Topic', topicId);
      _requireActive(
        destinationChapter != null && !destinationChapter.isArchived,
        'Chapter',
        destinationChapterId,
      );
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');
      _requireTeacherOwned(
        mergeState,
        'chapter',
        destinationChapterId,
        'Destination chapter',
      );
      final now = _now();
      final newTitle = _uniqueCopyName(
        source!.title,
        workspace.topics
            .where(
              (item) =>
                  item.chapterId == destinationChapterId && !item.isArchived,
            )
            .map((item) => item.title),
      );
      final topicOrder = _nextSortOrder(
        workspace.topics
            .where(
              (item) =>
                  item.chapterId == destinationChapterId && !item.isArchived,
            )
            .map((item) => item.sortOrder),
      );
      return workspace.copyWith(
        topics: [
          ...workspace.topics,
          PlannerTopic(
            id: _idGenerator(),
            chapterId: destinationChapterId,
            title: newTitle,
            sortOrder: topicOrder,
            plannedPeriods: source.plannedPeriods,
            priority: source.priority,
            actualPeriods: 0,
            status: TeachingProgressStatus.planned,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> importSyllabus(
    SyllabusImportPackage package,
  ) {
    final cleanClassName = _requiredName(package.className, 'Class name');
    return _repository.update((workspace) {
      final now = _now();
      final classId = _idGenerator();
      var classes = [
        ...workspace.classes,
        PlannerClass(
          id: classId,
          name: cleanClassName,
          academicYear: _optionalText(package.academicYear),
          sortOrder: _nextSortOrder(
            workspace.classes
                .where((item) => !item.isArchived)
                .map((item) => item.sortOrder),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      ];
      var subjects = [...workspace.subjects];
      var units = [...workspace.units];
      var chapters = [...workspace.chapters];
      var topics = [...workspace.topics];

      for (
        var subjectIndex = 0;
        subjectIndex < package.subjects.length;
        subjectIndex++
      ) {
        final sourceSubject = package.subjects[subjectIndex];
        final subjectId = _idGenerator();
        subjects.add(
          PlannerSubject(
            id: subjectId,
            classId: classId,
            name: _requiredName(sourceSubject.name, 'Subject name'),
            code: _optionalText(sourceSubject.code),
            sortOrder: subjectIndex,
            createdAt: now,
            updatedAt: now,
          ),
        );

        var subjectChapterOrder = 0;
        for (
          var unitIndex = 0;
          unitIndex < sourceSubject.units.length;
          unitIndex++
        ) {
          final sourceUnit = sourceSubject.units[unitIndex];
          final unitId = _idGenerator();
          var chapterOrder = 0;
          units.add(
            PlannerUnit(
              id: unitId,
              subjectId: subjectId,
              title: _requiredName(sourceUnit.title, 'Unit title'),
              sortOrder: unitIndex,
              plannedPeriods: _nonNegativeImported(
                sourceUnit.plannedPeriods,
                'Unit planned periods',
              ),
              priority: sourceUnit.priority,
              createdAt: now,
              updatedAt: now,
            ),
          );
          for (final sourceChapter in sourceUnit.chapters) {
            final chapterId = _idGenerator();
            chapters.add(
              PlannerChapter(
                id: chapterId,
                subjectId: subjectId,
                unitId: unitId,
                title: _requiredName(sourceChapter.title, 'Chapter title'),
                sortOrder: chapterOrder++,
                plannedPeriods: _nonNegativeImported(
                  sourceChapter.plannedPeriods,
                  'Chapter planned periods',
                ),
                priority: sourceChapter.priority,
                createdAt: now,
                updatedAt: now,
              ),
            );
            for (
              var topicIndex = 0;
              topicIndex < sourceChapter.topics.length;
              topicIndex++
            ) {
              final sourceTopic = sourceChapter.topics[topicIndex];
              topics.add(
                PlannerTopic(
                  id: _idGenerator(),
                  chapterId: chapterId,
                  title: _requiredName(sourceTopic.title, 'Topic title'),
                  sortOrder: topicIndex,
                  plannedPeriods: _nonNegativeImported(
                    sourceTopic.plannedPeriods,
                    'Topic planned periods',
                  ),
                  priority: sourceTopic.priority,
                  actualPeriods: 0,
                  status: TeachingProgressStatus.planned,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
            }
          }
        }

        for (final sourceChapter in sourceSubject.chapters) {
          final chapterId = _idGenerator();
          chapters.add(
            PlannerChapter(
              id: chapterId,
              subjectId: subjectId,
              unitId: null,
              title: _requiredName(sourceChapter.title, 'Chapter title'),
              sortOrder: subjectChapterOrder++,
              plannedPeriods: _nonNegativeImported(
                sourceChapter.plannedPeriods,
                'Chapter planned periods',
              ),
              priority: sourceChapter.priority,
              createdAt: now,
              updatedAt: now,
            ),
          );
          for (
            var topicIndex = 0;
            topicIndex < sourceChapter.topics.length;
            topicIndex++
          ) {
            final sourceTopic = sourceChapter.topics[topicIndex];
            topics.add(
              PlannerTopic(
                id: _idGenerator(),
                chapterId: chapterId,
                title: _requiredName(sourceTopic.title, 'Topic title'),
                sortOrder: topicIndex,
                plannedPeriods: _nonNegativeImported(
                  sourceTopic.plannedPeriods,
                  'Topic planned periods',
                ),
                priority: sourceTopic.priority,
                actualPeriods: 0,
                status: TeachingProgressStatus.planned,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      }

      return workspace.copyWith(
        classes: classes,
        subjects: subjects,
        units: units,
        chapters: chapters,
        topics: topics,
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveClass(String classId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'class', classId, 'Class');

      final parent = workspace.classById(classId);
      _requireActive(parent != null && !parent.isArchived, 'Class', classId);
      final now = _now();
      final subjectIds = workspace.subjects
          .where((item) => item.classId == classId)
          .map((item) => item.id)
          .toSet();
      final unitIds = workspace.units
          .where((item) => subjectIds.contains(item.subjectId))
          .map((item) => item.id)
          .toSet();
      final chapterIds = workspace.chapters
          .where((item) => subjectIds.contains(item.subjectId))
          .map((item) => item.id)
          .toSet();

      return workspace.copyWith(
        classes: workspace.classes
            .map(
              (item) => item.id == classId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        subjects: workspace.subjects
            .map(
              (item) => subjectIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        units: workspace.units
            .map(
              (item) => unitIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        chapters: workspace.chapters
            .map(
              (item) => chapterIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        topics: workspace.topics
            .map(
              (item) => chapterIds.contains(item.chapterId)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.classId == classId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveSubject(String subjectId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');

      final parent = workspace.subjectById(subjectId);
      _requireActive(
        parent != null && !parent.isArchived,
        'Subject',
        subjectId,
      );
      final now = _now();
      final unitIds = workspace.units
          .where((item) => item.subjectId == subjectId)
          .map((item) => item.id)
          .toSet();
      final chapterIds = workspace.chapters
          .where((item) => item.subjectId == subjectId)
          .map((item) => item.id)
          .toSet();

      return workspace.copyWith(
        subjects: workspace.subjects
            .map(
              (item) => item.id == subjectId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        units: workspace.units
            .map(
              (item) => unitIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        chapters: workspace.chapters
            .map(
              (item) => chapterIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        topics: workspace.topics
            .map(
              (item) => chapterIds.contains(item.chapterId)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.subjectId == subjectId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveUnit(String unitId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');

      final parent = workspace.unitById(unitId);
      _requireActive(parent != null && !parent.isArchived, 'Unit', unitId);
      final now = _now();
      final chapterIds = workspace.chapters
          .where((item) => item.unitId == unitId)
          .map((item) => item.id)
          .toSet();
      return workspace.copyWith(
        units: workspace.units
            .map(
              (item) => item.id == unitId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        chapters: workspace.chapters
            .map(
              (item) => chapterIds.contains(item.id)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        topics: workspace.topics
            .map(
              (item) => chapterIds.contains(item.chapterId)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => chapterIds.contains(item.chapterId)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveChapter(String chapterId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');

      final parent = workspace.chapterById(chapterId);
      _requireActive(
        parent != null && !parent.isArchived,
        'Chapter',
        chapterId,
      );
      final now = _now();
      return workspace.copyWith(
        chapters: workspace.chapters
            .map(
              (item) => item.id == chapterId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        topics: workspace.topics
            .map(
              (item) => item.chapterId == chapterId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.chapterId == chapterId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveTopic(String topicId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');

      final topic = workspace.topicById(topicId);
      _requireActive(topic != null && !topic.isArchived, 'Topic', topicId);
      final now = _now();
      return workspace.copyWith(
        topics: workspace.topics
            .map(
              (item) => item.id == topicId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.topicIds.contains(topicId)
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }


  Future<TeachingPlannerWorkspace> trashClass(String classId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'class', classId, 'Class');
      final value = workspace.classById(classId);
      _requireActive(value != null && !value.isTrashed, 'Class', classId);
      final now = _now();
      return _trashSyllabusScope(workspace, _scopeForClass(workspace, classId), now);
    });
  }

  Future<TeachingPlannerWorkspace> trashSubject(String subjectId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      final value = workspace.subjectById(subjectId);
      _requireActive(value != null && !value.isTrashed, 'Subject', subjectId);
      final now = _now();
      return _trashSyllabusScope(workspace, _scopeForSubject(workspace, subjectId), now);
    });
  }

  Future<TeachingPlannerWorkspace> trashUnit(String unitId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
      final value = workspace.unitById(unitId);
      _requireActive(value != null && !value.isTrashed, 'Unit', unitId);
      final now = _now();
      return _trashSyllabusScope(workspace, _scopeForUnit(workspace, unitId), now);
    });
  }

  Future<TeachingPlannerWorkspace> trashChapter(String chapterId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');
      final value = workspace.chapterById(chapterId);
      _requireActive(value != null && !value.isTrashed, 'Chapter', chapterId);
      final now = _now();
      return _trashSyllabusScope(workspace, _scopeForChapter(workspace, chapterId), now);
    });
  }

  Future<TeachingPlannerWorkspace> trashTopic(String topicId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');
      final value = workspace.topicById(topicId);
      _requireActive(value != null && !value.isTrashed, 'Topic', topicId);
      final now = _now();
      return _trashSyllabusScope(workspace, _scopeForTopic(workspace, topicId), now);
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedClass(String classId) {
    return _repository.update((workspace) {
      final value = workspace.classById(classId);
      final trashedAt = value?.trashedAt;
      if (value == null || trashedAt == null) {
        throw TeachingPlannerOperationException('Class is not in Trash.');
      }
      return _restoreSyllabusScope(
        workspace,
        _scopeForClass(workspace, classId),
        trashedAt,
        _now(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedSubject(String subjectId) {
    return _repository.update((workspace) {
      final value = workspace.subjectById(subjectId);
      final trashedAt = value?.trashedAt;
      if (value == null || trashedAt == null) {
        throw TeachingPlannerOperationException('Subject is not in Trash.');
      }
      final parent = workspace.classById(value.classId);
      if (parent == null || parent.isTrashed || parent.isArchived) {
        throw const TeachingPlannerOperationException(
          'Restore the parent syllabus first, or restore this subject to another active class.',
        );
      }
      _requireUniqueSubjectName(
        workspace,
        classId: value.classId,
        name: value.name,
        excludingId: value.id,
      );
      return _restoreSyllabusScope(
        workspace,
        _scopeForSubject(workspace, subjectId),
        trashedAt,
        _now(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedUnit(String unitId) {
    return _repository.update((workspace) {
      final value = workspace.unitById(unitId);
      final trashedAt = value?.trashedAt;
      if (value == null || trashedAt == null) {
        throw TeachingPlannerOperationException('Unit is not in Trash.');
      }
      final parent = workspace.subjectById(value.subjectId);
      if (parent == null || parent.isTrashed || parent.isArchived) {
        throw const TeachingPlannerOperationException(
          'Restore the parent subject first, or restore this unit to another active subject.',
        );
      }
      _requireUniqueUnitTitle(
        workspace,
        subjectId: value.subjectId,
        title: value.title,
        excludingId: value.id,
      );
      return _restoreSyllabusScope(
        workspace,
        _scopeForUnit(workspace, unitId),
        trashedAt,
        _now(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedChapter(String chapterId) {
    return _repository.update((workspace) {
      final value = workspace.chapterById(chapterId);
      final trashedAt = value?.trashedAt;
      if (value == null || trashedAt == null) {
        throw TeachingPlannerOperationException('Chapter is not in Trash.');
      }
      final subject = workspace.subjectById(value.subjectId);
      final unit = value.unitId == null ? null : workspace.unitById(value.unitId!);
      if (subject == null || subject.isTrashed || subject.isArchived ||
          (value.unitId != null && (unit == null || unit.isTrashed || unit.isArchived))) {
        throw const TeachingPlannerOperationException(
          'Restore the parent syllabus hierarchy first, or restore this chapter to another active location.',
        );
      }
      _requireUniqueChapterTitle(
        workspace,
        subjectId: value.subjectId,
        unitId: value.unitId,
        title: value.title,
        excludingId: value.id,
      );
      return _restoreSyllabusScope(
        workspace,
        _scopeForChapter(workspace, chapterId),
        trashedAt,
        _now(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedTopic(String topicId) {
    return _repository.update((workspace) {
      final value = workspace.topicById(topicId);
      final trashedAt = value?.trashedAt;
      if (value == null || trashedAt == null) {
        throw TeachingPlannerOperationException('Topic is not in Trash.');
      }
      final parent = workspace.chapterById(value.chapterId);
      if (parent == null || parent.isTrashed || parent.isArchived) {
        throw const TeachingPlannerOperationException(
          'Restore the parent chapter first, or restore this topic to another active chapter.',
        );
      }
      _requireUniqueTopicTitle(
        workspace,
        chapterId: value.chapterId,
        title: value.title,
        excludingId: value.id,
      );
      return _restoreSyllabusScope(
        workspace,
        _scopeForTopic(workspace, topicId),
        trashedAt,
        _now(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedSubjectToClass({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final subject = workspace.subjectById(subjectId);
      final trashedAt = subject?.trashedAt;
      if (subject == null || trashedAt == null) {
        throw const TeachingPlannerOperationException('Subject is not in Trash.');
      }
      final destination = workspace.classById(destinationClassId);
      _requireActive(
        destination != null && !destination.isArchived && !destination.isTrashed,
        'Destination class',
        destinationClassId,
      );
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      _requireTeacherOwned(mergeState, 'class', destinationClassId, 'Destination class');
      _requireUniqueSubjectName(
        workspace,
        classId: destinationClassId,
        name: subject.name,
        excludingId: subjectId,
      );
      final now = _now();
      final restored = _restoreSyllabusScope(
        workspace,
        _scopeForSubject(workspace, subjectId),
        trashedAt,
        now,
      );
      final order = _nextSortOrder(
        restored.subjects
            .where((item) => item.classId == destinationClassId && !item.isArchived && !item.isTrashed && item.id != subjectId)
            .map((item) => item.sortOrder),
      );
      return restored.copyWith(
        subjects: restored.subjects
            .map((item) => item.id == subjectId
                ? item.copyWith(classId: destinationClassId, sortOrder: order, updatedAt: now)
                : item)
            .toList(growable: false),
        lessonPlans: restored.lessonPlans
            .map((item) => item.subjectId == subjectId
                ? item.copyWith(classId: destinationClassId, updatedAt: now)
                : item)
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedUnitToSubject({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final unit = workspace.unitById(unitId);
      final trashedAt = unit?.trashedAt;
      if (unit == null || trashedAt == null) {
        throw const TeachingPlannerOperationException('Unit is not in Trash.');
      }
      final destination = workspace.subjectById(destinationSubjectId);
      _requireActive(
        destination != null && !destination.isArchived && !destination.isTrashed,
        'Destination subject',
        destinationSubjectId,
      );
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
      _requireTeacherOwned(mergeState, 'subject', destinationSubjectId, 'Destination subject');
      _requireUniqueUnitTitle(
        workspace,
        subjectId: destinationSubjectId,
        title: unit.title,
        excludingId: unitId,
      );
      final chapterIds = workspace.chapters
          .where((item) => item.unitId == unitId)
          .map((item) => item.id)
          .toSet();
      final now = _now();
      final restored = _restoreSyllabusScope(
        workspace,
        _scopeForUnit(workspace, unitId),
        trashedAt,
        now,
      );
      final order = _nextSortOrder(
        restored.units
            .where((item) => item.subjectId == destinationSubjectId && !item.isArchived && !item.isTrashed && item.id != unitId)
            .map((item) => item.sortOrder),
      );
      return restored.copyWith(
        units: restored.units
            .map((item) => item.id == unitId
                ? item.copyWith(subjectId: destinationSubjectId, sortOrder: order, updatedAt: now)
                : item)
            .toList(growable: false),
        chapters: restored.chapters
            .map((item) => chapterIds.contains(item.id)
                ? item.copyWith(subjectId: destinationSubjectId, updatedAt: now)
                : item)
            .toList(growable: false),
        lessonPlans: restored.lessonPlans
            .map((item) => chapterIds.contains(item.chapterId)
                ? item.copyWith(classId: destination!.classId, subjectId: destinationSubjectId, updatedAt: now)
                : item)
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedChapterToLocation({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final chapter = workspace.chapterById(chapterId);
      final trashedAt = chapter?.trashedAt;
      if (chapter == null || trashedAt == null) {
        throw const TeachingPlannerOperationException('Chapter is not in Trash.');
      }
      final destination = workspace.subjectById(destinationSubjectId);
      _requireActive(
        destination != null && !destination.isArchived && !destination.isTrashed,
        'Destination subject',
        destinationSubjectId,
      );
      if (destinationUnitId != null) {
        final unit = workspace.unitById(destinationUnitId);
        _requireActive(
          unit != null && !unit.isArchived && !unit.isTrashed && unit.subjectId == destinationSubjectId,
          'Destination unit',
          destinationUnitId,
        );
      }
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');
      _requireTeacherOwned(mergeState, 'subject', destinationSubjectId, 'Destination subject');
      if (destinationUnitId != null) {
        _requireTeacherOwned(mergeState, 'unit', destinationUnitId, 'Destination unit');
      }
      _requireUniqueChapterTitle(
        workspace,
        subjectId: destinationSubjectId,
        unitId: destinationUnitId,
        title: chapter.title,
        excludingId: chapterId,
      );
      final now = _now();
      final restored = _restoreSyllabusScope(
        workspace,
        _scopeForChapter(workspace, chapterId),
        trashedAt,
        now,
      );
      final order = _nextSortOrder(
        restored.chapters
            .where((item) => item.subjectId == destinationSubjectId && item.unitId == destinationUnitId && !item.isArchived && !item.isTrashed && item.id != chapterId)
            .map((item) => item.sortOrder),
      );
      return restored.copyWith(
        chapters: restored.chapters
            .map((item) => item.id == chapterId
                ? item.copyWith(subjectId: destinationSubjectId, unitId: destinationUnitId, sortOrder: order, updatedAt: now)
                : item)
            .toList(growable: false),
        lessonPlans: restored.lessonPlans
            .map((item) => item.chapterId == chapterId
                ? item.copyWith(classId: destination!.classId, subjectId: destinationSubjectId, updatedAt: now)
                : item)
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> restoreTrashedTopicToChapter({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      final topic = workspace.topicById(topicId);
      final trashedAt = topic?.trashedAt;
      if (topic == null || trashedAt == null) {
        throw const TeachingPlannerOperationException('Topic is not in Trash.');
      }
      final destination = workspace.chapterById(destinationChapterId);
      _requireActive(
        destination != null && !destination.isArchived && !destination.isTrashed,
        'Destination chapter',
        destinationChapterId,
      );
      _requireTeacherOwned(mergeState, 'topic', topicId, 'Topic');
      _requireTeacherOwned(mergeState, 'chapter', destinationChapterId, 'Destination chapter');
      _requireUniqueTopicTitle(
        workspace,
        chapterId: destinationChapterId,
        title: topic.title,
        excludingId: topicId,
      );
      final now = _now();
      final restored = _restoreSyllabusScope(
        workspace,
        _scopeForTopic(workspace, topicId),
        trashedAt,
        now,
      );
      final order = _nextSortOrder(
        restored.topics
            .where((item) => item.chapterId == destinationChapterId && !item.isArchived && !item.isTrashed && item.id != topicId)
            .map((item) => item.sortOrder),
      );
      return restored.copyWith(
        topics: restored.topics
            .map((item) => item.id == topicId
                ? item.copyWith(chapterId: destinationChapterId, sortOrder: order, updatedAt: now)
                : item)
            .toList(growable: false),
        lessonPlans: restored.lessonPlans
            .map((lesson) {
              if (!lesson.topicIds.contains(topicId) || lesson.chapterId == destinationChapterId) {
                return lesson;
              }
              return lesson.copyWith(
                topicIds: lesson.topicIds.where((id) => id != topicId).toList(growable: false),
                updatedAt: now,
              );
            })
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> deleteClassPermanently(String classId) {
    return _repository.update(
      (workspace) => _deleteSyllabusScope(
        workspace,
        _scopeForClass(workspace, classId),
        rootIsTrashed: workspace.classById(classId)?.isTrashed ?? false,
      ),
    );
  }

  Future<TeachingPlannerWorkspace> deleteSubjectPermanently(String subjectId) {
    return _repository.update(
      (workspace) => _deleteSyllabusScope(
        workspace,
        _scopeForSubject(workspace, subjectId),
        rootIsTrashed: workspace.subjectById(subjectId)?.isTrashed ?? false,
      ),
    );
  }

  Future<TeachingPlannerWorkspace> deleteUnitPermanently(String unitId) {
    return _repository.update(
      (workspace) => _deleteSyllabusScope(
        workspace,
        _scopeForUnit(workspace, unitId),
        rootIsTrashed: workspace.unitById(unitId)?.isTrashed ?? false,
      ),
    );
  }

  Future<TeachingPlannerWorkspace> deleteChapterPermanently(String chapterId) {
    return _repository.update(
      (workspace) => _deleteSyllabusScope(
        workspace,
        _scopeForChapter(workspace, chapterId),
        rootIsTrashed: workspace.chapterById(chapterId)?.isTrashed ?? false,
      ),
    );
  }

  Future<TeachingPlannerWorkspace> deleteTopicPermanently(String topicId) {
    return _repository.update((workspace) {
      final scope = _scopeForTopic(workspace, topicId);
      final root = workspace.topicById(topicId);
      final next = _deleteSyllabusScope(
        workspace,
        scope,
        rootIsTrashed: root?.isTrashed ?? false,
      );
      return next.copyWith(
        lessonPlans: next.lessonPlans
            .map(
              (lesson) => lesson.topicIds.contains(topicId)
                  ? lesson.copyWith(
                      topicIds: lesson.topicIds
                          .where((id) => id != topicId)
                          .toList(growable: false),
                      updatedAt: _now(),
                    )
                  : lesson,
            )
            .toList(growable: false),
      );
    });
  }

  Future<TeachingPlannerWorkspace> reorderSubjects({
    required String classId,
    required List<String> orderedSubjectIds,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'class', classId, 'Class');
      for (final id in orderedSubjectIds) {
        _requireTeacherOwned(mergeState, 'subject', id, 'Subject');
      }

      final parent = workspace.classById(classId);
      _requireActive(parent != null && !parent.isArchived, 'Class', classId);
      final active = workspace.activeSubjectsForClass(classId);
      _requireExactOrderSet(
        active.map((item) => item.id),
        orderedSubjectIds,
        label: 'subjects',
      );
      final order = <String, int>{
        for (var i = 0; i < orderedSubjectIds.length; i++)
          orderedSubjectIds[i]: i,
      };
      final now = _now();
      return workspace.copyWith(
        subjects: workspace.subjects
            .map(
              (item) => order.containsKey(item.id)
                  ? item.copyWith(sortOrder: order[item.id], updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> reorderUnits({
    required String subjectId,
    required List<String> orderedUnitIds,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      for (final id in orderedUnitIds) {
        _requireTeacherOwned(mergeState, 'unit', id, 'Unit');
      }

      final parent = workspace.subjectById(subjectId);
      _requireActive(
        parent != null && !parent.isArchived,
        'Subject',
        subjectId,
      );
      final active = workspace.activeUnitsForSubject(subjectId);
      _requireExactOrderSet(
        active.map((item) => item.id),
        orderedUnitIds,
        label: 'units',
      );
      final order = <String, int>{
        for (var i = 0; i < orderedUnitIds.length; i++) orderedUnitIds[i]: i,
      };
      final now = _now();
      return workspace.copyWith(
        units: workspace.units
            .map(
              (item) => order.containsKey(item.id)
                  ? item.copyWith(sortOrder: order[item.id], updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> reorderTopics({
    required String chapterId,
    required List<String> orderedTopicIds,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');
      for (final id in orderedTopicIds) {
        _requireTeacherOwned(mergeState, 'topic', id, 'Topic');
      }

      final chapter = workspace.chapterById(chapterId);
      _requireActive(
        chapter != null && !chapter.isArchived,
        'Chapter',
        chapterId,
      );
      final active = workspace.activeTopicsForChapter(chapterId);
      _requireExactOrderSet(
        active.map((item) => item.id),
        orderedTopicIds,
        label: 'topics',
      );
      final order = <String, int>{
        for (var i = 0; i < orderedTopicIds.length; i++) orderedTopicIds[i]: i,
      };
      final now = _now();
      return workspace.copyWith(
        topics: workspace.topics
            .map(
              (item) => order.containsKey(item.id)
                  ? item.copyWith(sortOrder: order[item.id], updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> reorderChapters({
    required String subjectId,
    String? unitId,
    required List<String> orderedChapterIds,
  }) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
      if (unitId != null) {
        _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
      }
      for (final id in orderedChapterIds) {
        _requireTeacherOwned(mergeState, 'chapter', id, 'Chapter');
      }

      final subject = workspace.subjectById(subjectId);
      _requireActive(
        subject != null && !subject.isArchived,
        'Subject',
        subjectId,
      );
      _validateChapterParent(workspace, subjectId, unitId);
      final active = workspace.activeChaptersForSubject(
        subjectId,
        unitId: unitId,
      );
      _requireExactOrderSet(
        active.map((item) => item.id),
        orderedChapterIds,
        label: 'chapters',
      );
      final order = <String, int>{
        for (var i = 0; i < orderedChapterIds.length; i++)
          orderedChapterIds[i]: i,
      };
      final now = _now();
      return workspace.copyWith(
        chapters: workspace.chapters
            .map(
              (item) => order.containsKey(item.id)
                  ? item.copyWith(sortOrder: order[item.id], updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> createTeachingResource({
    String? resourceId,
    String? lessonPlanId,
    TeachingResourceOwner? owner,
    required TeachingResourceKind kind,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
    required String title,
    String? body,
    String? url,
    String? originalFileName,
    String? mimeType,
    String? localRelativePath,
    TeachingResourceFileOwnership fileOwnership =
        TeachingResourceFileOwnership.managed,
    String? externalFilePath,
    int? sizeBytes,
    String? linkedPaperId,
    String? linkedSmartDocumentId,
    Map<String, dynamic>? geometryJson,
  }) {
    final targetOwner = _resolveResourceOwner(
      owner: owner,
      lessonPlanId: lessonPlanId,
    );
    final cleanTitle = _requiredName(title, 'Resource title');
    final cleanBody = _optionalText(body);
    final cleanUrl = _optionalText(url);
    final cleanOriginalName = _optionalText(originalFileName);
    final cleanMimeType = _optionalText(mimeType);
    final cleanRelativePath = _optionalText(localRelativePath);
    final cleanExternalPath = _optionalText(externalFilePath);
    final cleanLinkedPaperId = _optionalText(linkedPaperId);
    final cleanLinkedSmartDocumentId = _optionalText(linkedSmartDocumentId);
    if (sizeBytes != null) _requireNonNegative(sizeBytes, 'Resource size');
    _validateResourcePayload(
      kind: kind,
      body: cleanBody,
      url: cleanUrl,
      originalFileName: cleanOriginalName,
      localRelativePath: cleanRelativePath,
      fileOwnership: fileOwnership,
      externalFilePath: cleanExternalPath,
      linkedPaperId: cleanLinkedPaperId,
      linkedSmartDocumentId: cleanLinkedSmartDocumentId,
      geometryJson: geometryJson,
    );
    return _repository.update((workspace) {
      _validateResourceOwner(workspace, targetOwner);
      if (kind == TeachingResourceKind.paper &&
          workspace.resources.any(
            (item) =>
                !item.isArchived &&
                item.owner == targetOwner &&
                item.kind == TeachingResourceKind.paper &&
                item.linkedPaperId == cleanLinkedPaperId,
          )) {
        throw const TeachingPlannerOperationException(
          'This saved paper is already linked here.',
        );
      }
      if (kind == TeachingResourceKind.smartDocument &&
          workspace.resources.any(
            (item) =>
                !item.isArchived &&
                item.owner == targetOwner &&
                item.kind == TeachingResourceKind.smartDocument &&
                item.linkedSmartDocumentId == cleanLinkedSmartDocumentId,
          )) {
        throw const TeachingPlannerOperationException(
          'This Smart Editor document is already linked here.',
        );
      }
      final id = resourceId ?? _idGenerator();
      if (workspace.resourceById(id) != null) {
        throw const TeachingPlannerOperationException(
          'Teaching resource id already exists.',
        );
      }
      final now = _now();
      return workspace.copyWith(
        resources: [
          ...workspace.resources,
          TeachingResource(
            id: id,
            owner: targetOwner,
            kind: kind,
            role: role,
            title: cleanTitle,
            body: cleanBody,
            url: cleanUrl,
            originalFileName: cleanOriginalName,
            mimeType: cleanMimeType,
            localRelativePath: cleanRelativePath,
            fileOwnership: fileOwnership,
            externalFilePath: cleanExternalPath,
            sizeBytes: sizeBytes,
            linkedPaperId: cleanLinkedPaperId,
            linkedSmartDocumentId: cleanLinkedSmartDocumentId,
            geometryJson: geometryJson == null
                ? null
                : Map<String, dynamic>.from(geometryJson),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> createTeachingFileResources({
    required TeachingResourceOwner owner,
    required List<TeachingFileResourceDraft> files,
  }) {
    if (files.isEmpty) {
      throw const TeachingPlannerOperationException(
        'Choose at least one file to attach.',
      );
    }
    return _repository.update((workspace) {
      _validateResourceOwner(workspace, owner);
      final incomingIds = <String>{};
      for (final file in files) {
        if (!incomingIds.add(file.id) ||
            workspace.resourceById(file.id) != null) {
          throw const TeachingPlannerOperationException(
            'Teaching resource id already exists.',
          );
        }
        _requiredName(file.title, 'Resource title');
        _requiredName(file.originalFileName, 'File name');
        _validateFileLocation(
          ownership: file.fileOwnership,
          localRelativePath: file.localRelativePath,
          externalFilePath: file.externalFilePath,
        );
        _requireNonNegative(file.sizeBytes, 'Resource size');
      }
      final now = _now();
      final additions = files
          .map(
            (file) => TeachingResource(
              id: file.id,
              owner: owner,
              kind: TeachingResourceKind.file,
              role: file.role,
              title: _requiredName(file.title, 'Resource title'),
              originalFileName: _requiredName(
                file.originalFileName,
                'File name',
              ),
              mimeType: _optionalText(file.mimeType),
              localRelativePath: _optionalText(file.localRelativePath),
              fileOwnership: file.fileOwnership,
              externalFilePath: _optionalText(file.externalFilePath),
              sizeBytes: file.sizeBytes,
              contentSha256: _optionalText(file.contentSha256),
              createdAt: now,
              updatedAt: now,
            ),
          )
          .toList(growable: false);
      return workspace.copyWith(
        resources: [...workspace.resources, ...additions],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateTeachingFileLocation(
    String resourceId, {
    required String originalFileName,
    required String? mimeType,
    required TeachingResourceFileOwnership fileOwnership,
    String? localRelativePath,
    String? externalFilePath,
    required int sizeBytes,
    String? contentSha256,
  }) {
    final cleanName = _requiredName(originalFileName, 'File name');
    final cleanMime = _optionalText(mimeType);
    final cleanRelative = _optionalText(localRelativePath);
    final cleanExternal = _optionalText(externalFilePath);
    _requireNonNegative(sizeBytes, 'Resource size');
    final cleanHash = _optionalText(contentSha256);
    _validateFileLocation(
      ownership: fileOwnership,
      localRelativePath: cleanRelative,
      externalFilePath: cleanExternal,
    );
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(
        mergeState,
        'resource',
        resourceId,
        'Teaching resource',
      );
      final existing = workspace.resourceById(resourceId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Teaching resource',
        resourceId,
      );
      if (existing!.kind != TeachingResourceKind.file) {
        throw const TeachingPlannerOperationException(
          'Only file resources can change attachment location.',
        );
      }
      final now = _now();
      return workspace.copyWith(
        resources: workspace.resources.map((item) {
          if (item.id != resourceId) return item;
          return item.copyWith(
            title: cleanName,
            originalFileName: cleanName,
            mimeType: cleanMime,
            localRelativePath: cleanRelative,
            fileOwnership: fileOwnership,
            externalFilePath: cleanExternal,
            sizeBytes: sizeBytes,
            contentSha256: cleanHash,
            updatedAt: now,
          );
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateTeachingResource(
    String resourceId, {
    required TeachingResourceRole role,
    required String title,
    String? body,
    String? url,
    Map<String, dynamic>? geometryJson,
  }) {
    final cleanTitle = _requiredName(title, 'Resource title');
    final cleanBody = _optionalText(body);
    final cleanUrl = _optionalText(url);
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(
        mergeState,
        'resource',
        resourceId,
        'Teaching resource',
      );

      final existing = workspace.resourceById(resourceId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Teaching resource',
        resourceId,
      );
      _validateResourceOwner(workspace, existing!.owner);
      _validateResourcePayload(
        kind: existing.kind,
        body: existing.kind == TeachingResourceKind.note
            ? cleanBody
            : existing.body,
        url: existing.kind == TeachingResourceKind.link
            ? cleanUrl
            : existing.url,
        originalFileName: existing.originalFileName,
        localRelativePath: existing.localRelativePath,
        fileOwnership: existing.fileOwnership,
        externalFilePath: existing.externalFilePath,
        linkedPaperId: existing.linkedPaperId,
        linkedSmartDocumentId: existing.linkedSmartDocumentId,
        geometryJson: existing.kind == TeachingResourceKind.geometry
            ? geometryJson
            : existing.geometryJson,
      );
      final now = _now();
      return workspace.copyWith(
        resources: workspace.resources.map((item) {
          if (item.id != resourceId) return item;
          return item.copyWith(
            role: role,
            title: cleanTitle,
            body: item.kind == TeachingResourceKind.note
                ? cleanBody
                : item.body,
            url: item.kind == TeachingResourceKind.link ? cleanUrl : item.url,
            geometryJson: item.kind == TeachingResourceKind.geometry
                ? (geometryJson == null
                      ? item.geometryJson
                      : Map<String, dynamic>.from(geometryJson))
                : item.geometryJson,
            updatedAt: now,
          );
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> importTeachingResources({
    String? lessonPlanId,
    TeachingResourceOwner? owner,
    required List<TeachingResource> resources,
  }) {
    if (resources.isEmpty) {
      throw const TeachingPlannerOperationException(
        'Teaching Pack has no resources to import.',
      );
    }
    final targetOwner = _resolveResourceOwner(
      owner: owner,
      lessonPlanId: lessonPlanId,
    );
    return _repository.update((workspace) {
      _validateResourceOwner(workspace, targetOwner);
      final incomingIds = <String>{};
      final now = _now();
      final normalized = <TeachingResource>[];
      for (final item in resources) {
        if (!incomingIds.add(item.id) ||
            workspace.resourceById(item.id) != null) {
          throw const TeachingPlannerOperationException(
            'Teaching Pack contains a duplicate resource id.',
          );
        }
        if (item.sizeBytes != null) {
          _requireNonNegative(item.sizeBytes!, 'Resource size');
        }
        _validateResourcePayload(
          kind: item.kind,
          body: item.body,
          url: item.url,
          originalFileName: item.originalFileName,
          localRelativePath: item.localRelativePath,
          fileOwnership: item.fileOwnership,
          externalFilePath: item.externalFilePath,
          linkedPaperId: item.linkedPaperId,
          linkedSmartDocumentId: item.linkedSmartDocumentId,
          geometryJson: item.geometryJson,
        );
        normalized.add(
          TeachingResource(
            id: item.id,
            owner: targetOwner,
            kind: item.kind,
            role: item.role,
            title: _requiredName(item.title, 'Resource title'),
            body: _optionalText(item.body),
            url: _optionalText(item.url),
            originalFileName: _optionalText(item.originalFileName),
            mimeType: _optionalText(item.mimeType),
            localRelativePath: _optionalText(item.localRelativePath),
            fileOwnership: item.fileOwnership,
            externalFilePath: _optionalText(item.externalFilePath),
            sizeBytes: item.sizeBytes,
            contentSha256: item.contentSha256,
            linkedPaperId: _optionalText(item.linkedPaperId),
            linkedSmartDocumentId: _optionalText(item.linkedSmartDocumentId),
            geometryJson: item.geometryJson == null
                ? null
                : Map<String, dynamic>.from(item.geometryJson!),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return workspace.copyWith(
        resources: [...workspace.resources, ...normalized],
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveTeachingResource(String resourceId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(
        mergeState,
        'resource',
        resourceId,
        'Teaching resource',
      );

      final existing = workspace.resourceById(resourceId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Teaching resource',
        resourceId,
      );
      final now = _now();
      return workspace.copyWith(
        resources: workspace.resources
            .map(
              (item) => item.id == resourceId
                  ? item.copyWith(updatedAt: now, archivedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }

  static TeachingResourceOwner _resolveResourceOwner({
    TeachingResourceOwner? owner,
    String? lessonPlanId,
  }) {
    final cleanLegacyLessonId = _optionalText(lessonPlanId);
    if (owner == null && cleanLegacyLessonId == null) {
      throw const TeachingPlannerOperationException(
        'Teaching resource owner is required.',
      );
    }
    if (owner != null && cleanLegacyLessonId != null) {
      if (owner.type != TeachingResourceOwnerType.lessonPlan ||
          owner.id != cleanLegacyLessonId) {
        throw const TeachingPlannerOperationException(
          'Teaching resource owner conflicts with lessonPlanId.',
        );
      }
    }
    final resolved =
        owner ?? TeachingResourceOwner.lessonPlan(cleanLegacyLessonId!);
    if (resolved.id.trim().isEmpty) {
      throw const TeachingPlannerOperationException(
        'Teaching resource owner cannot be empty.',
      );
    }
    return resolved;
  }

  static void _validateResourceOwner(
    TeachingPlannerWorkspace workspace,
    TeachingResourceOwner owner,
  ) {
    switch (owner.type) {
      case TeachingResourceOwnerType.plannerClass:
        final item = workspace.classById(owner.id);
        _requireActive(item != null && !item.isArchived, 'Class', owner.id);
        break;
      case TeachingResourceOwnerType.subject:
        final item = workspace.subjectById(owner.id);
        _requireActive(item != null && !item.isArchived, 'Subject', owner.id);
        break;
      case TeachingResourceOwnerType.unit:
        final item = workspace.unitById(owner.id);
        _requireActive(item != null && !item.isArchived, 'Unit', owner.id);
        break;
      case TeachingResourceOwnerType.chapter:
        final item = workspace.chapterById(owner.id);
        _requireActive(item != null && !item.isArchived, 'Chapter', owner.id);
        break;
      case TeachingResourceOwnerType.topic:
        final item = workspace.topicById(owner.id);
        _requireActive(item != null && !item.isArchived, 'Topic', owner.id);
        break;
      case TeachingResourceOwnerType.lessonPlan:
        final item = workspace.lessonPlanById(owner.id);
        _requireActive(
          item != null && !item.isArchived,
          'Lesson plan',
          owner.id,
        );
        break;
    }
  }

  void _validateFileLocation({
    required TeachingResourceFileOwnership ownership,
    required String? localRelativePath,
    required String? externalFilePath,
  }) {
    switch (ownership) {
      case TeachingResourceFileOwnership.managed:
        _requiredName(localRelativePath ?? '', 'Stored file path');
        return;
      case TeachingResourceFileOwnership.linkedExternal:
        _requiredName(externalFilePath ?? '', 'Linked file path');
        return;
    }
  }

  void _validateResourcePayload({
    required TeachingResourceKind kind,
    required String? body,
    required String? url,
    required String? originalFileName,
    required String? localRelativePath,
    TeachingResourceFileOwnership fileOwnership =
        TeachingResourceFileOwnership.managed,
    String? externalFilePath,
    required String? linkedPaperId,
    required String? linkedSmartDocumentId,
    required Map<String, dynamic>? geometryJson,
  }) {
    switch (kind) {
      case TeachingResourceKind.note:
        _requiredName(body ?? '', 'Teaching note');
        break;
      case TeachingResourceKind.link:
        final parsed = Uri.tryParse(url ?? '');
        if (parsed == null ||
            !(parsed.isScheme('http') || parsed.isScheme('https'))) {
          throw const TeachingPlannerOperationException(
            'Link must start with http:// or https://.',
          );
        }
        break;
      case TeachingResourceKind.file:
        _requiredName(originalFileName ?? '', 'File name');
        _validateFileLocation(
          ownership: fileOwnership,
          localRelativePath: localRelativePath,
          externalFilePath: externalFilePath,
        );
        break;
      case TeachingResourceKind.paper:
        _requiredName(linkedPaperId ?? '', 'Saved paper');
        break;
      case TeachingResourceKind.smartDocument:
        _requiredName(
          linkedSmartDocumentId ?? '',
          'Smart Editor document',
        );
        break;
      case TeachingResourceKind.geometry:
        if (geometryJson == null) {
          throw const TeachingPlannerOperationException(
            'Geometry diagram is required.',
          );
        }
        break;
    }
  }

  DateTime _now() => _clock().toUtc();

  Future<TeachingPlannerWorkspace> createLessonPlan({
    required String classId,
    required String subjectId,
    required String chapterId,
    List<String> topicIds = const [],
    required String title,
    required DateTime plannedDate,
    required int plannedPeriods,
    required String objective,
    String? materials,
    String? activities,
    String? homework,
    String? notes,
    TeachingProgressStatus status = TeachingProgressStatus.planned,
  }) {
    final cleanTitle = _requiredName(title, 'Lesson title');
    final cleanObjective = _requiredName(objective, 'Lesson objective');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _repository.update((workspace) {
      _validateLessonSyllabus(
        workspace,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: topicIds,
      );
      final now = _now();
      return workspace.copyWith(
        lessonPlans: [
          ...workspace.lessonPlans,
          LessonPlan(
            id: _idGenerator(),
            classId: classId,
            subjectId: subjectId,
            chapterId: chapterId,
            topicIds: List.unmodifiable(topicIds),
            title: cleanTitle,
            plannedDate: plannedDate.toUtc(),
            plannedPeriods: plannedPeriods,
            objective: cleanObjective,
            materials: _optionalText(materials),
            activities: _optionalText(activities),
            homework: _optionalText(homework),
            notes: _optionalText(notes),
            status: status,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateLessonPlan(
    String lessonPlanId, {
    required String classId,
    required String subjectId,
    required String chapterId,
    List<String> topicIds = const [],
    required String title,
    required DateTime plannedDate,
    required int plannedPeriods,
    required String objective,
    String? materials,
    String? activities,
    String? homework,
    String? notes,
    required TeachingProgressStatus status,
  }) {
    final cleanTitle = _requiredName(title, 'Lesson title');
    final cleanObjective = _requiredName(objective, 'Lesson objective');
    _requireNonNegative(plannedPeriods, 'Planned periods');
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(
        mergeState,
        'lessonPlan',
        lessonPlanId,
        'Lesson plan',
      );

      final existing = workspace.lessonPlanById(lessonPlanId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Lesson plan',
        lessonPlanId,
      );
      _validateLessonSyllabus(
        workspace,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: topicIds,
      );
      final now = _now();
      return workspace.copyWith(
        lessonPlans: workspace.lessonPlans.map((item) {
          if (item.id != lessonPlanId) return item;
          return item.copyWith(
            classId: classId,
            subjectId: subjectId,
            chapterId: chapterId,
            topicIds: topicIds,
            title: cleanTitle,
            plannedDate: plannedDate.toUtc(),
            plannedPeriods: plannedPeriods,
            objective: cleanObjective,
            materials: _optionalText(materials),
            activities: _optionalText(activities),
            homework: _optionalText(homework),
            notes: _optionalText(notes),
            status: status,
            updatedAt: now,
          );
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> recordLessonProgress(
    String lessonPlanId, {
    required TeachingProgressStatus status,
    required int actualPeriods,
    DateTime? taughtAt,
    String? reflection,
    TeachingProgressStatus? chapterStatus,
  }) {
    _requireNonNegative(actualPeriods, 'Actual periods');
    return _repository.update((workspace) {
      final existing = workspace.lessonPlanById(lessonPlanId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Lesson plan',
        lessonPlanId,
      );
      final now = _now();
      final resolvedTaughtAt =
          status == TeachingProgressStatus.completed ||
              status == TeachingProgressStatus.inProgress
          ? (taughtAt ?? existing!.taughtAt ?? now)
          : taughtAt;
      final resolvedChapterStatus = chapterStatus ??
          ((status == TeachingProgressStatus.completed ||
                      status == TeachingProgressStatus.inProgress) &&
                  workspace.chapterById(existing!.chapterId)?.status !=
                      TeachingProgressStatus.completed
              ? TeachingProgressStatus.inProgress
              : null);
      return workspace.copyWith(
        lessonPlans: workspace.lessonPlans.map((item) {
          if (item.id != lessonPlanId) return item;
          return item.copyWith(
            status: status,
            actualPeriods: actualPeriods,
            taughtAt: resolvedTaughtAt?.toUtc(),
            reflection: _optionalText(reflection),
            updatedAt: now,
          );
        }).toList(),
        chapters: resolvedChapterStatus == null
            ? workspace.chapters
            : workspace.chapters.map((item) {
                if (item.id != existing!.chapterId) return item;
                return item.copyWith(
                  status: resolvedChapterStatus,
                  updatedAt: now,
                );
              }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateChapterProgress(
    String chapterId, {
    required TeachingProgressStatus status,
  }) {
    return _repository.update((workspace) {
      final existing = workspace.chapterById(chapterId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Chapter',
        chapterId,
      );
      final now = _now();
      return workspace.copyWith(
        chapters: workspace.chapters.map((item) {
          if (item.id != chapterId) return item;
          return item.copyWith(status: status, updatedAt: now);
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> updateTopicProgress(
    String topicId, {
    required TeachingProgressStatus status,
    required int actualPeriods,
  }) {
    _requireNonNegative(actualPeriods, 'Actual periods');
    return _repository.update((workspace) {
      final existing = workspace.topicById(topicId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Topic',
        topicId,
      );
      final now = _now();
      return workspace.copyWith(
        topics: workspace.topics.map((item) {
          if (item.id != topicId) return item;
          return item.copyWith(
            status: status,
            actualPeriods: actualPeriods,
            updatedAt: now,
          );
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> scheduleLessonPlan(
    String lessonPlanId, {
    required DateTime plannedDate,
    int? startPeriod,
  }) {
    if (startPeriod != null && startPeriod < 1) {
      throw const TeachingPlannerOperationException(
        'Start period must be 1 or greater.',
      );
    }
    return _repository.update((workspace) {
      final existing = workspace.lessonPlanById(lessonPlanId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Lesson plan',
        lessonPlanId,
      );
      final now = _now();
      return workspace.copyWith(
        lessonPlans: workspace.lessonPlans.map((item) {
          if (item.id != lessonPlanId) return item;
          return item.copyWith(
            plannedDate: plannedDate.toUtc(),
            startPeriod: startPeriod,
            updatedAt: now,
          );
        }).toList(),
      );
    });
  }

  Future<TeachingPlannerWorkspace> archiveLessonPlan(String lessonPlanId) {
    return _updateCurriculumAware((workspace, mergeState) {
      _requireTeacherOwned(
        mergeState,
        'lessonPlan',
        lessonPlanId,
        'Lesson plan',
      );

      final existing = workspace.lessonPlanById(lessonPlanId);
      _requireActive(
        existing != null && !existing.isArchived,
        'Lesson plan',
        lessonPlanId,
      );
      final now = _now();
      return workspace.copyWith(
        lessonPlans: workspace.lessonPlans
            .map(
              (item) => item.id == lessonPlanId
                  ? item.copyWith(archivedAt: now, updatedAt: now)
                  : item,
            )
            .toList(),
      );
    });
  }


  static _SyllabusTrashScope _scopeForClass(
    TeachingPlannerWorkspace workspace,
    String classId,
  ) {
    final subjectIds = workspace.subjects
        .where((item) => item.classId == classId)
        .map((item) => item.id)
        .toSet();
    final unitIds = workspace.units
        .where((item) => subjectIds.contains(item.subjectId))
        .map((item) => item.id)
        .toSet();
    final chapterIds = workspace.chapters
        .where((item) => subjectIds.contains(item.subjectId))
        .map((item) => item.id)
        .toSet();
    final topicIds = workspace.topics
        .where((item) => chapterIds.contains(item.chapterId))
        .map((item) => item.id)
        .toSet();
    final lessonIds = workspace.lessonPlans
        .where((item) => item.classId == classId)
        .map((item) => item.id)
        .toSet();
    return _SyllabusTrashScope(
      classIds: {classId},
      subjectIds: subjectIds,
      unitIds: unitIds,
      chapterIds: chapterIds,
      topicIds: topicIds,
      lessonIds: lessonIds,
    );
  }

  static _SyllabusTrashScope _scopeForSubject(
    TeachingPlannerWorkspace workspace,
    String subjectId,
  ) {
    final unitIds = workspace.units
        .where((item) => item.subjectId == subjectId)
        .map((item) => item.id)
        .toSet();
    final chapterIds = workspace.chapters
        .where((item) => item.subjectId == subjectId)
        .map((item) => item.id)
        .toSet();
    final topicIds = workspace.topics
        .where((item) => chapterIds.contains(item.chapterId))
        .map((item) => item.id)
        .toSet();
    final lessonIds = workspace.lessonPlans
        .where((item) => item.subjectId == subjectId)
        .map((item) => item.id)
        .toSet();
    return _SyllabusTrashScope(
      subjectIds: {subjectId},
      unitIds: unitIds,
      chapterIds: chapterIds,
      topicIds: topicIds,
      lessonIds: lessonIds,
    );
  }

  static _SyllabusTrashScope _scopeForUnit(
    TeachingPlannerWorkspace workspace,
    String unitId,
  ) {
    final chapterIds = workspace.chapters
        .where((item) => item.unitId == unitId)
        .map((item) => item.id)
        .toSet();
    final topicIds = workspace.topics
        .where((item) => chapterIds.contains(item.chapterId))
        .map((item) => item.id)
        .toSet();
    final lessonIds = workspace.lessonPlans
        .where((item) => chapterIds.contains(item.chapterId))
        .map((item) => item.id)
        .toSet();
    return _SyllabusTrashScope(
      unitIds: {unitId},
      chapterIds: chapterIds,
      topicIds: topicIds,
      lessonIds: lessonIds,
    );
  }

  static _SyllabusTrashScope _scopeForChapter(
    TeachingPlannerWorkspace workspace,
    String chapterId,
  ) {
    final topicIds = workspace.topics
        .where((item) => item.chapterId == chapterId)
        .map((item) => item.id)
        .toSet();
    final lessonIds = workspace.lessonPlans
        .where((item) => item.chapterId == chapterId)
        .map((item) => item.id)
        .toSet();
    return _SyllabusTrashScope(
      chapterIds: {chapterId},
      topicIds: topicIds,
      lessonIds: lessonIds,
    );
  }

  static _SyllabusTrashScope _scopeForTopic(
    TeachingPlannerWorkspace workspace,
    String topicId,
  ) => _SyllabusTrashScope(topicIds: {topicId});

  static TeachingPlannerWorkspace _trashSyllabusScope(
    TeachingPlannerWorkspace workspace,
    _SyllabusTrashScope scope,
    DateTime now,
  ) {
    return workspace.copyWith(
      classes: workspace.classes
          .map(
            (item) => scope.classIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      subjects: workspace.subjects
          .map(
            (item) => scope.subjectIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      units: workspace.units
          .map(
            (item) => scope.unitIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      chapters: workspace.chapters
          .map(
            (item) => scope.chapterIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      topics: workspace.topics
          .map(
            (item) => scope.topicIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      lessonPlans: workspace.lessonPlans
          .map(
            (item) => scope.lessonIds.contains(item.id) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      resources: workspace.resources
          .map(
            (item) => _resourceInTrashScope(item, scope) && !item.isTrashed
                ? item.copyWith(trashedAt: now, updatedAt: now)
                : item,
          )
          .toList(growable: false),
    );
  }

  static TeachingPlannerWorkspace _restoreSyllabusScope(
    TeachingPlannerWorkspace workspace,
    _SyllabusTrashScope scope,
    DateTime groupAt,
    DateTime now,
  ) {
    bool sameGroup(DateTime? value) => value == groupAt;
    return workspace.copyWith(
      classes: workspace.classes
          .map(
            (item) => scope.classIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      subjects: workspace.subjects
          .map(
            (item) => scope.subjectIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      units: workspace.units
          .map(
            (item) => scope.unitIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      chapters: workspace.chapters
          .map(
            (item) => scope.chapterIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      topics: workspace.topics
          .map(
            (item) => scope.topicIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      lessonPlans: workspace.lessonPlans
          .map(
            (item) => scope.lessonIds.contains(item.id) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
      resources: workspace.resources
          .map(
            (item) => _resourceInTrashScope(item, scope) && sameGroup(item.trashedAt)
                ? item.copyWith(trashedAt: null, updatedAt: now)
                : item,
          )
          .toList(growable: false),
    );
  }

  static TeachingPlannerWorkspace _deleteSyllabusScope(
    TeachingPlannerWorkspace workspace,
    _SyllabusTrashScope scope, {
    required bool rootIsTrashed,
  }) {
    if (!rootIsTrashed) {
      throw const TeachingPlannerOperationException(
        'Move this syllabus item to Trash before deleting it permanently.',
      );
    }
    return workspace.copyWith(
      classes: workspace.classes
          .where((item) => !scope.classIds.contains(item.id))
          .toList(growable: false),
      subjects: workspace.subjects
          .where((item) => !scope.subjectIds.contains(item.id))
          .toList(growable: false),
      units: workspace.units
          .where((item) => !scope.unitIds.contains(item.id))
          .toList(growable: false),
      chapters: workspace.chapters
          .where((item) => !scope.chapterIds.contains(item.id))
          .toList(growable: false),
      topics: workspace.topics
          .where((item) => !scope.topicIds.contains(item.id))
          .toList(growable: false),
      lessonPlans: workspace.lessonPlans
          .where((item) => !scope.lessonIds.contains(item.id))
          .toList(growable: false),
      resources: workspace.resources
          .where((item) => !_resourceInTrashScope(item, scope))
          .toList(growable: false),
    );
  }

  static bool _resourceInTrashScope(
    TeachingResource resource,
    _SyllabusTrashScope scope,
  ) {
    return switch (resource.owner.type) {
      TeachingResourceOwnerType.plannerClass =>
        scope.classIds.contains(resource.owner.id),
      TeachingResourceOwnerType.subject =>
        scope.subjectIds.contains(resource.owner.id),
      TeachingResourceOwnerType.unit => scope.unitIds.contains(resource.owner.id),
      TeachingResourceOwnerType.chapter =>
        scope.chapterIds.contains(resource.owner.id),
      TeachingResourceOwnerType.topic => scope.topicIds.contains(resource.owner.id),
      TeachingResourceOwnerType.lessonPlan =>
        scope.lessonIds.contains(resource.owner.id),
    };
  }

  static void _validateLessonSyllabus(
    TeachingPlannerWorkspace workspace, {
    required String classId,
    required String subjectId,
    required String chapterId,
    required List<String> topicIds,
  }) {
    final plannerClass = workspace.classById(classId);
    _requireActive(
      plannerClass != null && !plannerClass.isArchived,
      'Class',
      classId,
    );
    final subject = workspace.subjectById(subjectId);
    _requireActive(
      subject != null && !subject.isArchived,
      'Subject',
      subjectId,
    );
    if (subject!.classId != classId) {
      throw const TeachingPlannerOperationException(
        'Lesson subject must belong to the selected class.',
      );
    }
    final chapter = workspace.chapterById(chapterId);
    _requireActive(
      chapter != null && !chapter.isArchived,
      'Chapter',
      chapterId,
    );
    if (chapter!.subjectId != subjectId) {
      throw const TeachingPlannerOperationException(
        'Lesson chapter must belong to the selected subject.',
      );
    }
    final unique = topicIds.toSet();
    if (unique.length != topicIds.length) {
      throw const TeachingPlannerOperationException(
        'A lesson cannot include the same topic more than once.',
      );
    }
    for (final topicId in topicIds) {
      final topic = workspace.topicById(topicId);
      _requireActive(topic != null && !topic.isArchived, 'Topic', topicId);
      if (topic!.chapterId != chapterId) {
        throw const TeachingPlannerOperationException(
          'Every lesson topic must belong to the selected chapter.',
        );
      }
    }
  }

  static void _requireTeacherOwnedSubjectTree(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
    String subjectId,
  ) {
    _requireTeacherOwned(mergeState, 'subject', subjectId, 'Subject');
    final unitIds = workspace.units
        .where((item) => item.subjectId == subjectId)
        .map((item) => item.id)
        .toSet();
    final chapters = workspace.chapters
        .where((item) => item.subjectId == subjectId)
        .toList(growable: false);
    for (final unitId in unitIds) {
      _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
    }
    for (final chapter in chapters) {
      _requireTeacherOwned(mergeState, 'chapter', chapter.id, 'Chapter');
      for (final topic in workspace.topics.where(
        (item) => item.chapterId == chapter.id,
      )) {
        _requireTeacherOwned(mergeState, 'topic', topic.id, 'Topic');
      }
    }
  }

  static void _requireTeacherOwnedUnitTree(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
    String unitId,
  ) {
    _requireTeacherOwned(mergeState, 'unit', unitId, 'Unit');
    for (final chapter in workspace.chapters.where(
      (item) => item.unitId == unitId,
    )) {
      _requireTeacherOwned(mergeState, 'chapter', chapter.id, 'Chapter');
      for (final topic in workspace.topics.where(
        (item) => item.chapterId == chapter.id,
      )) {
        _requireTeacherOwned(mergeState, 'topic', topic.id, 'Topic');
      }
    }
  }

  static void _requireTeacherOwnedChapterTree(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
    String chapterId,
  ) {
    _requireTeacherOwned(mergeState, 'chapter', chapterId, 'Chapter');
    for (final topic in workspace.topics.where(
      (item) => item.chapterId == chapterId,
    )) {
      _requireTeacherOwned(mergeState, 'topic', topic.id, 'Topic');
    }
  }

  static String _normalizedName(String value) => value.trim().toLowerCase();

  static void _requireUniqueSubjectName(
    TeachingPlannerWorkspace workspace, {
    required String classId,
    required String name,
    String? excludingId,
  }) {
    final normalized = _normalizedName(name);
    final conflict = workspace.subjects.any(
      (item) =>
          item.classId == classId &&
          item.id != excludingId &&
          !item.isArchived &&
          !item.isTrashed &&
          _normalizedName(item.name) == normalized,
    );
    if (conflict) {
      throw const TeachingPlannerOperationException(
        'A subject with the same name already exists in the destination class.',
      );
    }
  }

  static void _requireUniqueUnitTitle(
    TeachingPlannerWorkspace workspace, {
    required String subjectId,
    required String title,
    String? excludingId,
  }) {
    final normalized = _normalizedName(title);
    final conflict = workspace.units.any(
      (item) =>
          item.subjectId == subjectId &&
          item.id != excludingId &&
          !item.isArchived &&
          !item.isTrashed &&
          _normalizedName(item.title) == normalized,
    );
    if (conflict) {
      throw const TeachingPlannerOperationException(
        'A unit with the same name already exists in the destination subject.',
      );
    }
  }

  static void _requireUniqueChapterTitle(
    TeachingPlannerWorkspace workspace, {
    required String subjectId,
    required String? unitId,
    required String title,
    String? excludingId,
  }) {
    final normalized = _normalizedName(title);
    final conflict = workspace.chapters.any(
      (item) =>
          item.subjectId == subjectId &&
          item.unitId == unitId &&
          item.id != excludingId &&
          !item.isArchived &&
          !item.isTrashed &&
          _normalizedName(item.title) == normalized,
    );
    if (conflict) {
      throw const TeachingPlannerOperationException(
        'A chapter with the same name already exists in the destination.',
      );
    }
  }

  static void _requireUniqueTopicTitle(
    TeachingPlannerWorkspace workspace, {
    required String chapterId,
    required String title,
    String? excludingId,
  }) {
    final normalized = _normalizedName(title);
    final conflict = workspace.topics.any(
      (item) =>
          item.chapterId == chapterId &&
          item.id != excludingId &&
          !item.isArchived &&
          !item.isTrashed &&
          _normalizedName(item.title) == normalized,
    );
    if (conflict) {
      throw const TeachingPlannerOperationException(
        'A topic with the same name already exists in the destination chapter.',
      );
    }
  }

  static String _uniqueCopyName(String source, Iterable<String> existingNames) {
    final existing = existingNames.map(_normalizedName).toSet();
    if (!existing.contains(_normalizedName(source))) return source;
    final firstCopy = '$source copy';
    if (!existing.contains(_normalizedName(firstCopy))) return firstCopy;
    var suffix = 2;
    while (existing.contains(_normalizedName('$source copy $suffix'))) {
      suffix += 1;
    }
    return '$source copy $suffix';
  }

  static int _nextSortOrder(Iterable<int> values) {
    var max = -1;
    for (final value in values) {
      if (value > max) max = value;
    }
    return max + 1;
  }

  static int _nonNegativeImported(int value, String label) {
    _requireNonNegative(value, label);
    return value;
  }

  static String _requiredName(String value, String label) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      throw TeachingPlannerOperationException('$label cannot be empty.');
    }
    return cleaned;
  }

  static String? _optionalText(String? value) {
    final cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  static void _requireNonNegative(int value, String label) {
    if (value < 0) {
      throw TeachingPlannerOperationException('$label cannot be negative.');
    }
  }

  static void _requireActive(bool exists, String type, String id) {
    if (!exists) {
      throw TeachingPlannerOperationException(
        '$type $id does not exist or is archived.',
      );
    }
  }

  static void _validateChapterParent(
    TeachingPlannerWorkspace workspace,
    String subjectId,
    String? unitId,
  ) {
    final subject = workspace.subjectById(subjectId);
    _requireActive(
      subject != null && !subject.isArchived,
      'Subject',
      subjectId,
    );
    if (unitId == null) return;
    final unit = workspace.unitById(unitId);
    _requireActive(unit != null && !unit.isArchived, 'Unit', unitId);
    if (unit!.subjectId != subjectId) {
      throw const TeachingPlannerOperationException(
        'A chapter cannot be attached to a unit from another subject.',
      );
    }
  }

  static void _validateDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && end.isBefore(start)) {
      throw const TeachingPlannerOperationException(
        'Planned end cannot be before planned start.',
      );
    }
  }

  static void _requireExactOrderSet(
    Iterable<String> currentIds,
    List<String> requestedIds, {
    required String label,
  }) {
    final current = currentIds.toSet();
    final requested = requestedIds.toSet();
    if (requested.length != requestedIds.length ||
        current.length != requested.length ||
        !current.containsAll(requested)) {
      throw TeachingPlannerOperationException(
        'Reordering $label requires every active sibling exactly once.',
      );
    }
  }

}

class _SyllabusTrashScope {
  const _SyllabusTrashScope({
    this.classIds = const <String>{},
    this.subjectIds = const <String>{},
    this.unitIds = const <String>{},
    this.chapterIds = const <String>{},
    this.topicIds = const <String>{},
    this.lessonIds = const <String>{},
  });

  final Set<String> classIds;
  final Set<String> subjectIds;
  final Set<String> unitIds;
  final Set<String> chapterIds;
  final Set<String> topicIds;
  final Set<String> lessonIds;
}

const Object _unset = Object();
