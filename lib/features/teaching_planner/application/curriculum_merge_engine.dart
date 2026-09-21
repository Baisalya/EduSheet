import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';

import '../data/portable_paper_snapshot.dart';
import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/curriculum_package.dart';
import '../domain/models/lesson_plan.dart';
import '../domain/models/planner_chapter.dart';
import '../domain/models/planner_class.dart';
import '../domain/models/planner_subject.dart';
import '../domain/models/planner_topic.dart';
import '../domain/models/planner_unit.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/models/teaching_resource_owner.dart';
import '../domain/services/teaching_planner_integrity.dart';

class CurriculumMergeException implements Exception {
  final String message;

  const CurriculumMergeException(this.message);

  @override
  String toString() => 'CurriculumMergeException: $message';
}

class CurriculumMergeConflict {
  final String entityType;
  final String originId;
  final String? localId;
  final String message;

  const CurriculumMergeConflict({
    required this.entityType,
    required this.originId,
    required this.message,
    this.localId,
  });
}

class CurriculumPaperMaterializationPlan {
  final String sourcePaperId;
  final String targetLocalPaperId;
  final PortablePaperSnapshot snapshot;
  final String? supersededLocalPaperId;
  final bool cleanupSupersededWhenUnreferenced;

  const CurriculumPaperMaterializationPlan({
    required this.sourcePaperId,
    required this.targetLocalPaperId,
    required this.snapshot,
    this.supersededLocalPaperId,
    this.cleanupSupersededWhenUnreferenced = false,
  });
}

class CurriculumResourceFileMaterializationPlan {
  final String sourceResourceId;
  final String targetLocalResourceId;
  final String fileName;
  final List<int> bytes;
  final String? supersededLocalResourceId;
  final bool cleanupSuperseded;

  const CurriculumResourceFileMaterializationPlan({
    required this.sourceResourceId,
    required this.targetLocalResourceId,
    required this.fileName,
    required this.bytes,
    this.supersededLocalResourceId,
    this.cleanupSuperseded = false,
  });
}

class CurriculumMergePlan {
  final TeachingPlannerWorkspace workspace;
  final CurriculumMergeState mergeState;
  final List<CurriculumPaperMaterializationPlan> paperMaterializations;
  final List<CurriculumResourceFileMaterializationPlan> fileMaterializations;
  final List<CurriculumMergeConflict> conflicts;
  final int addedCount;
  final int updatedCount;
  final int unchangedCount;
  final int staleCount;

  const CurriculumMergePlan({
    required this.workspace,
    required this.mergeState,
    required this.paperMaterializations,
    required this.fileMaterializations,
    required this.conflicts,
    required this.addedCount,
    required this.updatedCount,
    required this.unchangedCount,
    required this.staleCount,
  });

  bool get hasChanges => addedCount > 0 || updatedCount > 0;
}

typedef CurriculumMergeIdGenerator = String Function();
typedef CurriculumMergeClock = DateTime Function();

/// Pure origin/revision merge planner. It never touches disk or repositories.
///
/// Official curriculum entities are tracked in [CurriculumMergeState].
/// Anything not tracked remains teacher/local-owned and is never deleted by a
/// package import. Package absence is not interpreted as deletion; tombstones
/// belong to the later sync-contract phase.
class CurriculumMergeEngine {
  CurriculumMergeEngine({
    CurriculumMergeIdGenerator? idGenerator,
    CurriculumMergeClock? clock,
  }) : _idGenerator = idGenerator ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final CurriculumMergeIdGenerator _idGenerator;
  final CurriculumMergeClock _clock;

  CurriculumMergePlan plan({
    required TeachingPlannerWorkspace current,
    required CurriculumMergeState state,
    required CurriculumPackagePreview preview,
    required List<Paper> localPapers,
  }) {
    TeachingPlannerIntegrity.validateOrThrow(current);
    final payload = preview.payload;
    TeachingPlannerIntegrity.validateOrThrow(payload.workspace);
    final now = _clock().toUtc();
    final lineage = <String, CurriculumEntityLineage>{
      for (final item in payload.lineage)
        '${item.entityType}:${item.entityId}': item,
    };
    final records = <String, CurriculumReplicaRecord>{
      for (final item in state.replicas) item.key: item,
    };
    final conflicts = <CurriculumMergeConflict>[];
    final plannerIds = _plannerIds(current);
    final paperIds = localPapers.map((item) => item.id).toSet();
    final localPapersById = <String, Paper>{
      for (final item in localPapers) item.id: item,
    };

    var added = 0;
    var updated = 0;
    var unchanged = 0;
    var stale = 0;

    CurriculumEntityLineage line(String type, String sourceId) {
      final item = lineage['$type:$sourceId'];
      if (item == null) {
        throw CurriculumMergeException(
          'The curriculum package is missing $type lineage for $sourceId.',
        );
      }
      return item;
    }

    String incomingOrigin(String type, String sourceId) =>
        line(type, sourceId).originId;

    String localOrigin(String type, String localId) =>
        state.replicaForLocalId(type, localId)?.originId ?? localId;

    String? incomingOptionalOrigin(String type, String? sourceId) {
      if (sourceId == null || sourceId.trim().isEmpty) return null;
      return incomingOrigin(type, sourceId);
    }

    String? localOptionalOrigin(String type, String? localId) {
      if (localId == null || localId.trim().isEmpty) return null;
      return localOrigin(type, localId);
    }

    String ownerEntityType(TeachingResourceOwnerType type) => switch (type) {
      TeachingResourceOwnerType.plannerClass => 'class',
      TeachingResourceOwnerType.subject => 'subject',
      TeachingResourceOwnerType.unit => 'unit',
      TeachingResourceOwnerType.chapter => 'chapter',
      TeachingResourceOwnerType.topic => 'topic',
      TeachingResourceOwnerType.lessonPlan => 'lessonPlan',
    };

    String incomingOwnerOrigin(TeachingResourceOwner owner) =>
        '${owner.type.name}:${incomingOrigin(ownerEntityType(owner.type), owner.id)}';

    String localOwnerOrigin(TeachingResourceOwner owner) =>
        '${owner.type.name}:${localOrigin(ownerEntityType(owner.type), owner.id)}';

    String allocatePlannerId(String preferred) {
      if (preferred.trim().isNotEmpty && !plannerIds.contains(preferred)) {
        plannerIds.add(preferred);
        return preferred;
      }
      return _allocateUnique(plannerIds);
    }

    String allocatePaperId(String preferred) {
      if (preferred.trim().isNotEmpty && !paperIds.contains(preferred)) {
        paperIds.add(preferred);
        return preferred;
      }
      return _allocateUnique(paperIds);
    }

    final classes = <String, PlannerClass>{
      for (final item in current.classes) item.id: item,
    };
    final subjects = <String, PlannerSubject>{
      for (final item in current.subjects) item.id: item,
    };
    final units = <String, PlannerUnit>{
      for (final item in current.units) item.id: item,
    };
    final chapters = <String, PlannerChapter>{
      for (final item in current.chapters) item.id: item,
    };
    final topics = <String, PlannerTopic>{
      for (final item in current.topics) item.id: item,
    };
    final lessons = <String, LessonPlan>{
      for (final item in current.lessonPlans) item.id: item,
    };
    final resources = <String, TeachingResource>{
      for (final item in current.resources) item.id: item,
    };

    final classIds = <String, String>{};
    final subjectIds = <String, String>{};
    final unitIds = <String, String>{};
    final chapterIds = <String, String>{};
    final topicIds = <String, String>{};
    final lessonIds = <String, String>{};
    final paperLocalIds = <String, String>{};

    String resolveLocalId({
      required String type,
      required String sourceId,
      required bool Function(String id) exists,
      required String Function(String preferred) allocate,
    }) {
      final sourceLineage = line(type, sourceId);
      final key = '$type:${sourceLineage.originId}';
      final record = records[key];
      if (record != null) {
        if (exists(record.localId)) return record.localId;
        if (record.sourceRevision > sourceLineage.revision) {
          throw CurriculumMergeException(
            'A newer tracked $type replica is missing locally, but this package is older. EduSheet blocked the downgrade.',
          );
        }
        return allocate(record.localId);
      }
      return allocate(sourceId);
    }

    CurriculumReplicaRecord recordFor({
      required String type,
      required String localId,
      required CurriculumEntityLineage sourceLineage,
      required String? fingerprint,
    }) => CurriculumReplicaRecord(
      entityType: type,
      localId: localId,
      originId: sourceLineage.originId,
      sourceRevision: sourceLineage.revision,
      sourceUpdatedAt: sourceLineage.updatedAt,
      importedAt: now,
      sourcePackageOriginId: preview.manifest.originId,
      sourceFingerprint: fingerprint,
      sourceSchool: payload.sourceSchool,
      assignmentId: payload.assignment?.assignmentId,
    );

    bool shouldApply({
      required String type,
      required String localId,
      required CurriculumEntityLineage sourceLineage,
      required String incomingFingerprint,
      required String currentFingerprint,
    }) {
      final key = '$type:${sourceLineage.originId}';
      final record = records[key];
      if (record == null) {
        added++;
        return true;
      }
      if (sourceLineage.revision < record.sourceRevision) {
        stale++;
        return false;
      }
      if (sourceLineage.revision == record.sourceRevision) {
        if (record.sourceFingerprint != null &&
            record.sourceFingerprint != incomingFingerprint) {
          throw CurriculumMergeException(
            'The package contains different $type content with the same certified revision.',
          );
        }
        unchanged++;
        return false;
      }
      final expected = record.sourceFingerprint;
      if (expected != null && currentFingerprint != expected) {
        conflicts.add(
          CurriculumMergeConflict(
            entityType: type,
            originId: sourceLineage.originId,
            localId: localId,
            message:
                'Local master fields changed after the previous import, so the newer official $type was not silently applied.',
          ),
        );
        return false;
      }
      updated++;
      return true;
    }

    for (final source in payload.workspace.classes) {
      final sourceLineage = line('class', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'class');
      final localId = resolveLocalId(
        type: 'class',
        sourceId: source.id,
        exists: classes.containsKey,
        allocate: allocatePlannerId,
      );
      classIds[source.id] = localId;
      final local = classes[localId];
      final incomingFingerprint = _fingerprintClass(source);
      if (local == null) {
        classes[localId] = PlannerClass(
          id: localId,
          name: source.name,
          academicYear: source.academicYear,
          sortOrder: source.sortOrder,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['class:${sourceLineage.originId}'] = recordFor(
          type: 'class',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'class',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintClass(local),
      );
      if (apply) {
        classes[localId] = PlannerClass(
          id: localId,
          name: source.name,
          academicYear: source.academicYear,
          sortOrder: source.sortOrder,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['class:${sourceLineage.originId}'] = recordFor(
          type: 'class',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    for (final source in payload.workspace.subjects) {
      final sourceLineage = line('subject', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'subject');
      final localId = resolveLocalId(
        type: 'subject',
        sourceId: source.id,
        exists: subjects.containsKey,
        allocate: allocatePlannerId,
      );
      subjectIds[source.id] = localId;
      final mappedClass = _mapped(classIds, source.classId, 'class');
      final local = subjects[localId];
      final incomingFingerprint = _fingerprintSubject(
        source,
        classOrigin: incomingOrigin('class', source.classId),
      );
      if (local == null) {
        subjects[localId] = PlannerSubject(
          id: localId,
          classId: mappedClass,
          name: source.name,
          code: source.code,
          sortOrder: source.sortOrder,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['subject:${sourceLineage.originId}'] = recordFor(
          type: 'subject',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'subject',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintSubject(
          local,
          classOrigin: localOrigin('class', local.classId),
        ),
      );
      if (apply) {
        subjects[localId] = PlannerSubject(
          id: localId,
          classId: mappedClass,
          name: source.name,
          code: source.code,
          sortOrder: source.sortOrder,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['subject:${sourceLineage.originId}'] = recordFor(
          type: 'subject',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    for (final source in payload.workspace.units) {
      final sourceLineage = line('unit', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'unit');
      final localId = resolveLocalId(
        type: 'unit',
        sourceId: source.id,
        exists: units.containsKey,
        allocate: allocatePlannerId,
      );
      unitIds[source.id] = localId;
      final mappedSubject = _mapped(subjectIds, source.subjectId, 'subject');
      final local = units[localId];
      final incomingFingerprint = _fingerprintUnit(
        source,
        subjectOrigin: incomingOrigin('subject', source.subjectId),
      );
      if (local == null) {
        units[localId] = PlannerUnit(
          id: localId,
          subjectId: mappedSubject,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['unit:${sourceLineage.originId}'] = recordFor(
          type: 'unit',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'unit',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintUnit(
          local,
          subjectOrigin: localOrigin('subject', local.subjectId),
        ),
      );
      if (apply) {
        units[localId] = PlannerUnit(
          id: localId,
          subjectId: mappedSubject,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['unit:${sourceLineage.originId}'] = recordFor(
          type: 'unit',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    for (final source in payload.workspace.chapters) {
      final sourceLineage = line('chapter', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'chapter');
      final localId = resolveLocalId(
        type: 'chapter',
        sourceId: source.id,
        exists: chapters.containsKey,
        allocate: allocatePlannerId,
      );
      chapterIds[source.id] = localId;
      final mappedSubject = _mapped(subjectIds, source.subjectId, 'subject');
      final mappedUnit = source.unitId == null
          ? null
          : _mapped(unitIds, source.unitId!, 'unit');
      final local = chapters[localId];
      final incomingFingerprint = _fingerprintChapter(
        source,
        subjectOrigin: incomingOrigin('subject', source.subjectId),
        unitOrigin: incomingOptionalOrigin('unit', source.unitId),
      );
      if (local == null) {
        chapters[localId] = PlannerChapter(
          id: localId,
          subjectId: mappedSubject,
          unitId: mappedUnit,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['chapter:${sourceLineage.originId}'] = recordFor(
          type: 'chapter',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'chapter',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintChapter(
          local,
          subjectOrigin: localOrigin('subject', local.subjectId),
          unitOrigin: localOptionalOrigin('unit', local.unitId),
        ),
      );
      if (apply) {
        chapters[localId] = PlannerChapter(
          id: localId,
          subjectId: mappedSubject,
          unitId: mappedUnit,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          status: local.status,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['chapter:${sourceLineage.originId}'] = recordFor(
          type: 'chapter',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    for (final source in payload.workspace.topics) {
      final sourceLineage = line('topic', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'topic');
      final localId = resolveLocalId(
        type: 'topic',
        sourceId: source.id,
        exists: topics.containsKey,
        allocate: allocatePlannerId,
      );
      topicIds[source.id] = localId;
      final mappedChapter = _mapped(chapterIds, source.chapterId, 'chapter');
      final local = topics[localId];
      final incomingFingerprint = _fingerprintTopic(
        source,
        chapterOrigin: incomingOrigin('chapter', source.chapterId),
      );
      if (local == null) {
        topics[localId] = PlannerTopic(
          id: localId,
          chapterId: mappedChapter,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          actualPeriods: source.actualPeriods,
          status: source.status,
          plannedStart: source.plannedStart,
          plannedEnd: source.plannedEnd,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['topic:${sourceLineage.originId}'] = recordFor(
          type: 'topic',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'topic',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintTopic(
          local,
          chapterOrigin: localOrigin('chapter', local.chapterId),
        ),
      );
      if (apply) {
        topics[localId] = PlannerTopic(
          id: localId,
          chapterId: mappedChapter,
          title: source.title,
          sortOrder: source.sortOrder,
          plannedPeriods: source.plannedPeriods,
          priority: source.priority,
          // Teacher execution stays local across official curriculum updates.
          actualPeriods: local.actualPeriods,
          status: local.status,
          plannedStart: local.plannedStart,
          plannedEnd: local.plannedEnd,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['topic:${sourceLineage.originId}'] = recordFor(
          type: 'topic',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    for (final source in payload.workspace.lessonPlans) {
      final sourceLineage = line('lessonPlan', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'lessonPlan');
      final localId = resolveLocalId(
        type: 'lessonPlan',
        sourceId: source.id,
        exists: lessons.containsKey,
        allocate: allocatePlannerId,
      );
      lessonIds[source.id] = localId;
      final mappedClass = _mapped(classIds, source.classId, 'class');
      final mappedSubject = _mapped(subjectIds, source.subjectId, 'subject');
      final mappedChapter = _mapped(chapterIds, source.chapterId, 'chapter');
      final mappedTopics = source.topicIds
          .map((id) => _mapped(topicIds, id, 'topic'))
          .toList(growable: false);
      final local = lessons[localId];
      final incomingFingerprint = _fingerprintLesson(
        source,
        classOrigin: incomingOrigin('class', source.classId),
        subjectOrigin: incomingOrigin('subject', source.subjectId),
        chapterOrigin: incomingOrigin('chapter', source.chapterId),
        topicOrigins: source.topicIds
            .map((id) => incomingOrigin('topic', id))
            .toList(growable: false),
      );
      if (local == null) {
        lessons[localId] = LessonPlan(
          id: localId,
          classId: mappedClass,
          subjectId: mappedSubject,
          chapterId: mappedChapter,
          topicIds: mappedTopics,
          title: source.title,
          plannedDate: source.plannedDate,
          plannedPeriods: source.plannedPeriods,
          startPeriod: source.startPeriod,
          objective: source.objective,
          materials: source.materials,
          activities: source.activities,
          homework: source.homework,
          notes: source.notes,
          status: source.status,
          actualPeriods: source.actualPeriods,
          taughtAt: source.taughtAt,
          reflection: source.reflection,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
          archivedAt: source.archivedAt,
        );
        records['lessonPlan:${sourceLineage.originId}'] = recordFor(
          type: 'lessonPlan',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
        added++;
        continue;
      }
      final apply = shouldApply(
        type: 'lessonPlan',
        localId: localId,
        sourceLineage: sourceLineage,
        incomingFingerprint: incomingFingerprint,
        currentFingerprint: _fingerprintLesson(
          local,
          classOrigin: localOrigin('class', local.classId),
          subjectOrigin: localOrigin('subject', local.subjectId),
          chapterOrigin: localOrigin('chapter', local.chapterId),
          topicOrigins: local.topicIds
              .map((id) => localOrigin('topic', id))
              .toList(growable: false),
        ),
      );
      if (apply) {
        lessons[localId] = LessonPlan(
          id: localId,
          classId: mappedClass,
          subjectId: mappedSubject,
          chapterId: mappedChapter,
          topicIds: mappedTopics,
          title: source.title,
          // Teacher schedule/execution and private notes stay local.
          plannedDate: local.plannedDate,
          plannedPeriods: source.plannedPeriods,
          startPeriod: local.startPeriod,
          objective: source.objective,
          materials: source.materials,
          activities: source.activities,
          homework: source.homework,
          notes: local.notes,
          status: local.status,
          actualPeriods: local.actualPeriods,
          taughtAt: local.taughtAt,
          reflection: local.reflection,
          createdAt: local.createdAt,
          updatedAt: _latest(local.updatedAt, source.updatedAt),
          archivedAt: source.archivedAt,
        );
        records['lessonPlan:${sourceLineage.originId}'] = recordFor(
          type: 'lessonPlan',
          localId: localId,
          sourceLineage: sourceLineage,
          fingerprint: incomingFingerprint,
        );
      }
    }

    final paperMaterializations = <CurriculumPaperMaterializationPlan>[];
    for (final entry in payload.paperSnapshotsJson.entries) {
      if (entry.value is! Map) {
        throw const CurriculumMergeException(
          'Curriculum paper snapshot is invalid.',
        );
      }
      final snapshot = PortablePaperSnapshot.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      final sourceId = entry.key;
      final sourceLineage = line('paper', sourceId);
      if (snapshot.paper.originId != sourceLineage.originId ||
          snapshot.paper.revision != sourceLineage.revision ||
          snapshot.paper.updatedAt.toUtc() != sourceLineage.updatedAt.toUtc()) {
        throw const CurriculumMergeException(
          'Curriculum paper lineage does not match its embedded paper.',
        );
      }
      final key = 'paper:${sourceLineage.originId}';
      final record = records[key];
      final existingPaper = record == null
          ? null
          : localPapersById[record.localId];
      final incomingPaperFingerprint = _fingerprint(snapshot.toJson());
      if (record != null && sourceLineage.revision < record.sourceRevision) {
        if (existingPaper == null) {
          throw const CurriculumMergeException(
            'A newer official paper replica is missing locally; an older package cannot restore it safely.',
          );
        }
        paperLocalIds[sourceId] = record.localId;
        stale++;
        continue;
      }
      if (record != null && sourceLineage.revision == record.sourceRevision) {
        if (record.sourceFingerprint != null &&
            record.sourceFingerprint != incomingPaperFingerprint) {
          throw const CurriculumMergeException(
            'The package contains different paper content with the same certified revision.',
          );
        }
        if (existingPaper != null) {
          paperLocalIds[sourceId] = record.localId;
          unchanged++;
          continue;
        }
      }

      final targetId = record == null
          ? allocatePaperId(sourceId)
          : allocatePaperId('');
      final locallyDiverged =
          existingPaper != null &&
          record != null &&
          existingPaper.revision > record.sourceRevision;
      paperLocalIds[sourceId] = targetId;
      paperMaterializations.add(
        CurriculumPaperMaterializationPlan(
          sourcePaperId: sourceId,
          targetLocalPaperId: targetId,
          snapshot: snapshot,
          supersededLocalPaperId: existingPaper?.id,
          cleanupSupersededWhenUnreferenced:
              existingPaper != null && !locallyDiverged,
        ),
      );
      records[key] = recordFor(
        type: 'paper',
        localId: targetId,
        sourceLineage: sourceLineage,
        fingerprint: incomingPaperFingerprint,
      );
      if (record == null || existingPaper == null) {
        added++;
      } else {
        updated++;
        if (locallyDiverged) {
          conflicts.add(
            CurriculumMergeConflict(
              entityType: 'paper',
              originId: sourceLineage.originId,
              localId: existingPaper.id,
              message:
                  'The tracked paper was edited locally. EduSheet kept that local copy and imported the newer official paper separately.',
            ),
          );
        }
      }
    }

    final fileMaterializations = <CurriculumResourceFileMaterializationPlan>[];
    for (final source in payload.workspace.resources) {
      final sourceLineage = line('resource', source.id);
      _validateLineageTimestamp(source.updatedAt, sourceLineage, 'resource');
      final key = 'resource:${sourceLineage.originId}';
      final record = records[key];
      final existing = record == null ? null : resources[record.localId];
      final mappedOwner = _mapOwner(
        source.owner,
        classIds: classIds,
        subjectIds: subjectIds,
        unitIds: unitIds,
        chapterIds: chapterIds,
        topicIds: topicIds,
        lessonIds: lessonIds,
      );
      final mappedPaperId = source.kind == TeachingResourceKind.paper
          ? _mapped(paperLocalIds, source.linkedPaperId ?? '', 'linked paper')
          : source.linkedPaperId;
      final incomingFingerprint = _fingerprintResource(
        source,
        ownerOrigin: incomingOwnerOrigin(source.owner),
        linkedPaperOrigin: source.kind == TeachingResourceKind.paper
            ? incomingOptionalOrigin('paper', source.linkedPaperId)
            : null,
      );

      if (record != null && sourceLineage.revision < record.sourceRevision) {
        if (existing == null) {
          throw const CurriculumMergeException(
            'A newer official resource replica is missing locally; an older package cannot restore it safely.',
          );
        }
        stale++;
        continue;
      }

      String? existingFingerprint;
      if (existing != null) {
        existingFingerprint = _fingerprintResource(
          existing,
          ownerOrigin: localOwnerOrigin(existing.owner),
          linkedPaperOrigin: existing.kind == TeachingResourceKind.paper
              ? localOptionalOrigin('paper', existing.linkedPaperId)
              : null,
        );
      }

      if (record != null && sourceLineage.revision == record.sourceRevision) {
        if (record.sourceFingerprint != null &&
            record.sourceFingerprint != incomingFingerprint) {
          throw const CurriculumMergeException(
            'The package contains different resource content with the same certified revision.',
          );
        }
        if (existing != null) {
          if (record.sourceFingerprint != null &&
              existingFingerprint != record.sourceFingerprint) {
            conflicts.add(
              CurriculumMergeConflict(
                entityType: 'resource',
                originId: sourceLineage.originId,
                localId: existing.id,
                message:
                    'A locally edited official resource was preserved. Re-importing the same official revision did not overwrite it.',
              ),
            );
            unchanged++;
            continue;
          }

          final ownerNeedsRebind = existing.owner != mappedOwner;
          final paperNeedsRebind =
              source.kind == TeachingResourceKind.paper &&
              existing.linkedPaperId != mappedPaperId;
          if (ownerNeedsRebind || paperNeedsRebind) {
            resources[existing.id] = existing.copyWith(
              owner: mappedOwner,
              linkedPaperId: source.kind == TeachingResourceKind.paper
                  ? mappedPaperId
                  : existing.linkedPaperId,
              updatedAt: _latest(existing.updatedAt, source.updatedAt),
            );
            updated++;
          } else {
            unchanged++;
          }
          continue;
        }
      }

      final expectedFingerprint = record?.sourceFingerprint;
      final localDiverged =
          existing != null &&
          expectedFingerprint != null &&
          existingFingerprint != expectedFingerprint;
      final requiresFreshId =
          record == null ||
          existing == null ||
          localDiverged ||
          source.kind == TeachingResourceKind.file;
      final targetId = requiresFreshId
          ? allocatePlannerId(record == null ? source.id : '')
          : record.localId;
      final imported = TeachingResource(
        id: targetId,
        owner: mappedOwner,
        kind: source.kind,
        role: source.role,
        title: source.title,
        body: source.body,
        url: source.url,
        originalFileName: source.originalFileName,
        mimeType: source.mimeType,
        localRelativePath: source.kind == TeachingResourceKind.file
            ? '__pending__/$targetId'
            : source.localRelativePath,
        sizeBytes: source.sizeBytes,
        contentSha256: source.contentSha256,
        linkedPaperId: mappedPaperId,
        geometryJson: source.geometryJson,
        createdAt: existing?.createdAt ?? source.createdAt,
        updatedAt: source.updatedAt,
        archivedAt: source.archivedAt,
      );

      if (existing != null && localDiverged) {
        conflicts.add(
          CurriculumMergeConflict(
            entityType: 'resource',
            originId: sourceLineage.originId,
            localId: existing.id,
            message:
                'A locally edited resource was preserved as teacher-owned work; the newer official resource was imported separately.',
          ),
        );
      }

      if (existing != null && targetId != existing.id && !localDiverged) {
        resources.remove(existing.id);
      }
      resources[targetId] = imported;
      if (source.kind == TeachingResourceKind.file) {
        final bytes = payload.resourceFiles[source.id];
        if (bytes == null) {
          throw const CurriculumMergeException(
            'Curriculum package is missing an embedded teaching file.',
          );
        }
        if (source.sizeBytes != null && source.sizeBytes != bytes.length) {
          throw const CurriculumMergeException(
            'Curriculum teaching file size does not match its certified resource metadata.',
          );
        }
        final fileName = source.originalFileName?.trim();
        fileMaterializations.add(
          CurriculumResourceFileMaterializationPlan(
            sourceResourceId: source.id,
            targetLocalResourceId: targetId,
            fileName: fileName == null || fileName.isEmpty
                ? '${source.title}.bin'
                : fileName,
            bytes: bytes,
            supersededLocalResourceId: existing?.id,
            cleanupSuperseded:
                existing != null && targetId != existing.id && !localDiverged,
          ),
        );
      }
      records[key] = recordFor(
        type: 'resource',
        localId: targetId,
        sourceLineage: sourceLineage,
        fingerprint: incomingFingerprint,
      );
      if (record == null || existing == null) {
        added++;
      } else {
        updated++;
      }
    }

    final merged = TeachingPlannerWorkspace(
      classes: classes.values.toList(growable: false),
      subjects: subjects.values.toList(growable: false),
      units: units.values.toList(growable: false),
      chapters: chapters.values.toList(growable: false),
      topics: topics.values.toList(growable: false),
      lessonPlans: lessons.values.toList(growable: false),
      resources: resources.values.toList(growable: false),
    );
    // File resources receive real local paths in the import service before the
    // final integrity check and repository commit.
    _validateWithoutPendingFiles(merged);

    CurriculumImportReceipt? previousReceipt;
    for (final item in state.receipts) {
      if (item.packageOriginId == preview.manifest.originId) {
        previousReceipt = item;
        break;
      }
    }
    final receipt =
        previousReceipt != null &&
            previousReceipt.packageRevision > preview.manifest.revision
        ? previousReceipt
        : CurriculumImportReceipt(
            packageOriginId: preview.manifest.originId,
            packageRevision: preview.manifest.revision,
            contentType: preview.manifest.contentType,
            importedAt: now,
            conflictCount: conflicts.length,
            sourceSchool: payload.sourceSchool,
            assignmentId: payload.assignment?.assignmentId,
          );
    final receipts =
        state.receipts
            .where((item) => item.packageOriginId != preview.manifest.originId)
            .toList(growable: true)
          ..add(receipt);
    receipts.sort((a, b) => a.importedAt.compareTo(b.importedAt));

    return CurriculumMergePlan(
      workspace: merged,
      mergeState: CurriculumMergeState(
        replicas: records.values.toList(growable: false),
        receipts: receipts,
      ),
      paperMaterializations: List.unmodifiable(paperMaterializations),
      fileMaterializations: List.unmodifiable(fileMaterializations),
      conflicts: List.unmodifiable(conflicts),
      addedCount: added,
      updatedCount: updated,
      unchangedCount: unchanged,
      staleCount: stale,
    );
  }

  String _allocateUnique(Set<String> reserved) {
    for (var attempt = 0; attempt < 200; attempt++) {
      final candidate = _idGenerator().trim();
      if (candidate.isNotEmpty && reserved.add(candidate)) return candidate;
    }
    throw const CurriculumMergeException(
      'EduSheet could not allocate a collision-safe local id.',
    );
  }
}

Set<String> _plannerIds(TeachingPlannerWorkspace workspace) => <String>{
  ...workspace.classes.map((item) => item.id),
  ...workspace.subjects.map((item) => item.id),
  ...workspace.units.map((item) => item.id),
  ...workspace.chapters.map((item) => item.id),
  ...workspace.topics.map((item) => item.id),
  ...workspace.lessonPlans.map((item) => item.id),
  ...workspace.resources.map((item) => item.id),
};

String _mapped(Map<String, String> mapping, String sourceId, String label) {
  final value = mapping[sourceId];
  if (value == null) {
    throw CurriculumMergeException(
      'Curriculum package references a $label outside its validated hierarchy.',
    );
  }
  return value;
}

TeachingResourceOwner _mapOwner(
  TeachingResourceOwner owner, {
  required Map<String, String> classIds,
  required Map<String, String> subjectIds,
  required Map<String, String> unitIds,
  required Map<String, String> chapterIds,
  required Map<String, String> topicIds,
  required Map<String, String> lessonIds,
}) {
  final localId = switch (owner.type) {
    TeachingResourceOwnerType.plannerClass => _mapped(
      classIds,
      owner.id,
      'resource class',
    ),
    TeachingResourceOwnerType.subject => _mapped(
      subjectIds,
      owner.id,
      'resource subject',
    ),
    TeachingResourceOwnerType.unit => _mapped(
      unitIds,
      owner.id,
      'resource unit',
    ),
    TeachingResourceOwnerType.chapter => _mapped(
      chapterIds,
      owner.id,
      'resource chapter',
    ),
    TeachingResourceOwnerType.topic => _mapped(
      topicIds,
      owner.id,
      'resource topic',
    ),
    TeachingResourceOwnerType.lessonPlan => _mapped(
      lessonIds,
      owner.id,
      'resource lesson',
    ),
  };
  return TeachingResourceOwner(type: owner.type, id: localId);
}

void _validateLineageTimestamp(
  DateTime entityUpdatedAt,
  CurriculumEntityLineage lineage,
  String entityType,
) {
  if (entityUpdatedAt.toUtc() != lineage.updatedAt.toUtc()) {
    throw CurriculumMergeException(
      'Curriculum $entityType lineage timestamp does not match its entity.',
    );
  }
}

DateTime _latest(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

String _fingerprintClass(PlannerClass item) => _fingerprint(<Object?>[
  item.name,
  item.academicYear,
  item.sortOrder,
  item.archivedAt?.toUtc().toIso8601String(),
]);

String _fingerprintSubject(
  PlannerSubject item, {
  required String classOrigin,
}) => _fingerprint(<Object?>[
  classOrigin,
  item.name,
  item.code,
  item.sortOrder,
  item.archivedAt?.toUtc().toIso8601String(),
]);

String _fingerprintUnit(PlannerUnit item, {required String subjectOrigin}) =>
    _fingerprint(<Object?>[
      subjectOrigin,
      item.title,
      item.sortOrder,
      item.plannedPeriods,
      item.priority.name,
      item.archivedAt?.toUtc().toIso8601String(),
    ]);

String _fingerprintChapter(
  PlannerChapter item, {
  required String subjectOrigin,
  required String? unitOrigin,
}) => _fingerprint(<Object?>[
  subjectOrigin,
  unitOrigin,
  item.title,
  item.sortOrder,
  item.plannedPeriods,
  item.priority.name,
  item.archivedAt?.toUtc().toIso8601String(),
]);

String _fingerprintTopic(PlannerTopic item, {required String chapterOrigin}) =>
    _fingerprint(<Object?>[
      chapterOrigin,
      item.title,
      item.sortOrder,
      item.plannedPeriods,
      item.priority.name,
      item.archivedAt?.toUtc().toIso8601String(),
    ]);

String _fingerprintLesson(
  LessonPlan item, {
  required String classOrigin,
  required String subjectOrigin,
  required String chapterOrigin,
  required List<String> topicOrigins,
}) => _fingerprint(<Object?>[
  classOrigin,
  subjectOrigin,
  chapterOrigin,
  topicOrigins,
  item.title,
  item.plannedPeriods,
  item.objective,
  item.materials,
  item.activities,
  item.homework,
  item.archivedAt?.toUtc().toIso8601String(),
]);

String _fingerprintResource(
  TeachingResource item, {
  required String ownerOrigin,
  required String? linkedPaperOrigin,
}) => _fingerprint(<Object?>[
  ownerOrigin,
  item.kind.name,
  item.role.name,
  item.title,
  item.body,
  item.url,
  item.originalFileName,
  item.mimeType,
  item.sizeBytes,
  linkedPaperOrigin,
  item.geometryJson,
  item.archivedAt?.toUtc().toIso8601String(),
]);

String _fingerprint(Object value) {
  final bytes = utf8.encode(jsonEncode(_canonicalFingerprintValue(value)));
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

Object? _canonicalFingerprintValue(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _canonicalFingerprintValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalFingerprintValue).toList(growable: false);
  }
  return value;
}

void _validateWithoutPendingFiles(TeachingPlannerWorkspace workspace) {
  final sanitized = workspace.copyWith(
    resources: workspace.resources
        .map((item) {
          if (item.kind != TeachingResourceKind.file ||
              item.localRelativePath != null &&
                  !item.localRelativePath!.startsWith('__pending__/')) {
            return item;
          }
          return item.copyWith(localRelativePath: 'pending.bin');
        })
        .toList(growable: false),
  );
  TeachingPlannerIntegrity.validateOrThrow(sanitized);
}
