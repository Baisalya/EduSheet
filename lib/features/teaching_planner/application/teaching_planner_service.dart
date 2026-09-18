import 'package:uuid/uuid.dart';

import '../domain/models/lesson_plan.dart';
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
  final String localRelativePath;
  final int sizeBytes;

  const TeachingFileResourceDraft({
    required this.id,
    this.role = TeachingResourceRole.teachInClass,
    required this.title,
    required this.originalFileName,
    this.mimeType,
    required this.localRelativePath,
    required this.sizeBytes,
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

  Future<TeachingPlannerWorkspace> restoreWorkspace(
    TeachingPlannerWorkspace workspace,
  ) async {
    await _repository.save(workspace);
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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

  Future<TeachingPlannerWorkspace> reorderSubjects({
    required String classId,
    required List<String> orderedSubjectIds,
  }) {
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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
    int? sizeBytes,
    String? linkedPaperId,
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
    final cleanLinkedPaperId = _optionalText(linkedPaperId);
    if (sizeBytes != null) _requireNonNegative(sizeBytes, 'Resource size');
    _validateResourcePayload(
      kind: kind,
      body: cleanBody,
      url: cleanUrl,
      originalFileName: cleanOriginalName,
      localRelativePath: cleanRelativePath,
      linkedPaperId: cleanLinkedPaperId,
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
            sizeBytes: sizeBytes,
            linkedPaperId: cleanLinkedPaperId,
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
        _requiredName(file.localRelativePath, 'Stored file path');
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
              localRelativePath: _requiredName(
                file.localRelativePath,
                'Stored file path',
              ),
              sizeBytes: file.sizeBytes,
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
    return _repository.update((workspace) {
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
        linkedPaperId: existing.linkedPaperId,
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
          linkedPaperId: item.linkedPaperId,
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
            sizeBytes: item.sizeBytes,
            linkedPaperId: _optionalText(item.linkedPaperId),
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
    return _repository.update((workspace) {
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

  void _validateResourcePayload({
    required TeachingResourceKind kind,
    required String? body,
    required String? url,
    required String? originalFileName,
    required String? localRelativePath,
    required String? linkedPaperId,
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
        _requiredName(localRelativePath ?? '', 'Stored file path');
        break;
      case TeachingResourceKind.paper:
        _requiredName(linkedPaperId ?? '', 'Saved paper');
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
    return _repository.update((workspace) {
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
    return _repository.update((workspace) {
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

const Object _unset = Object();
