import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';

import '../data/portable_paper_snapshot.dart';
import '../data/teaching_resource_file_store.dart';
import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/curriculum_package.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/models/teaching_resource_owner.dart';
import '../domain/services/teaching_planner_integrity.dart';
import 'teaching_resource_portability.dart';

class CurriculumPackageBuildException implements Exception {
  final String message;

  const CurriculumPackageBuildException(this.message);

  @override
  String toString() => 'CurriculumPackageBuildException: $message';
}

class CurriculumPackageBuildResult {
  final EdsContentType contentType;
  final TeachingPlannerWorkspace workspace;
  final Map<String, List<int>> resourceFiles;
  final Map<String, PortablePaperSnapshot> paperSnapshots;
  final List<CurriculumEntityLineage> lineage;
  final String title;
  final String entityId;
  final String originId;
  final int revision;

  const CurriculumPackageBuildResult({
    required this.contentType,
    required this.workspace,
    required this.resourceFiles,
    required this.paperSnapshots,
    required this.lineage,
    required this.title,
    required this.entityId,
    required this.originId,
    required this.revision,
  });
}

/// Creates a self-contained curriculum slice without mutating the planner.
///
/// Exports a canonical curriculum slice. When a workspace contains Phase 6
/// replica mappings, local ids remain valid entity ids while lineage keeps the
/// original canonical `originId`, so an imported curriculum can be re-exported
/// without creating a false new branch.
class CurriculumPackageBuilderService {
  CurriculumPackageBuilderService({
    required TeachingResourceFileStore resourceFileStore,
    required PaperRepository paperRepository,
  }) : _resourceFileStore = resourceFileStore,
       _paperRepository = paperRepository;

  final TeachingResourceFileStore _resourceFileStore;
  final PaperRepository _paperRepository;

  Future<CurriculumPackageBuildResult> build({
    required TeachingPlannerWorkspace source,
    required CurriculumPackageSelection selection,
    required CurriculumPackageInclusions inclusions,
    CurriculumAssignmentMetadata? assignment,
    String? sourceSchool,
    CurriculumMergeState? mergeState,
  }) async {
    TeachingPlannerIntegrity.validateOrThrow(source);
    _validateSelection(source, selection);

    final selected = _selectWorkspace(
      source,
      selection,
      includeLessonPlans: inclusions.includeLessonPlans,
    );
    final filteredResources = selected.resources
        .where((resource) => _includeResource(resource, inclusions))
        .toList(growable: false);
    final workspace = selected.copyWith(resources: filteredResources);
    TeachingPlannerIntegrity.validateOrThrow(workspace);

    final resourceFiles = await _captureResourceFiles(workspace);
    final paperSnapshots = await _capturePaperSnapshots(workspace);
    final portableWorkspace = portableTeachingResourceWorkspaceWithFiles(
      workspace,
      resourceFiles,
    );
    final lineage = _buildLineage(
      workspace,
      paperSnapshots.values,
      mergeState: mergeState,
    );
    final contentType = assignment == null
        ? _contentTypeFor(selection)
        : EdsContentType.teacherPack;
    final title = _titleFor(
      source,
      selection,
      assignment: assignment,
      sourceSchool: sourceSchool,
    );
    final identity = _packageIdentity(
      source,
      selection,
      assignment: assignment,
    );
    final revision = lineage.isEmpty
        ? DateTime.now()
              .toUtc()
              .millisecondsSinceEpoch
              .clamp(1, 1 << 62)
              .toInt()
        : lineage
              .map((item) => _revisionFor(item.updatedAt))
              .reduce((a, b) => a > b ? a : b);

    return CurriculumPackageBuildResult(
      contentType: contentType,
      workspace: portableWorkspace,
      resourceFiles: Map.unmodifiable(resourceFiles),
      paperSnapshots: Map.unmodifiable(paperSnapshots),
      lineage: List.unmodifiable(lineage),
      title: title,
      entityId: identity.$1,
      originId: identity.$2,
      revision: revision,
    );
  }

  void _validateSelection(
    TeachingPlannerWorkspace source,
    CurriculumPackageSelection selection,
  ) {
    switch (selection.kind) {
      case CurriculumPackageScopeKind.schoolCurriculum:
        if (source.activeClasses.isEmpty) {
          throw const CurriculumPackageBuildException(
            'There is no active curriculum to export.',
          );
        }
        return;
      case CurriculumPackageScopeKind.classSyllabus:
        final classId = _required(selection.classId, 'class');
        if (source.classById(classId)?.isArchived != false) {
          throw const CurriculumPackageBuildException(
            'The selected class is not available.',
          );
        }
        return;
      case CurriculumPackageScopeKind.subject:
        final classId = _required(selection.classId, 'class');
        final subjectId = _required(selection.subjectId, 'subject');
        final subject = source.subjectById(subjectId);
        if (source.classById(classId)?.isArchived != false ||
            subject == null ||
            subject.isArchived ||
            subject.classId != classId) {
          throw const CurriculumPackageBuildException(
            'The selected subject does not belong to the selected class.',
          );
        }
        return;
      case CurriculumPackageScopeKind.selectedUnits:
        final classId = _required(selection.classId, 'class');
        final subjectId = _required(selection.subjectId, 'subject');
        if (selection.unitIds.isEmpty) {
          throw const CurriculumPackageBuildException(
            'Select at least one unit.',
          );
        }
        final subject = source.subjectById(subjectId);
        if (source.classById(classId)?.isArchived != false ||
            subject == null ||
            subject.isArchived ||
            subject.classId != classId) {
          throw const CurriculumPackageBuildException(
            'The selected subject does not belong to the selected class.',
          );
        }
        for (final unitId in selection.unitIds) {
          final unit = source.unitById(unitId);
          if (unit == null || unit.isArchived || unit.subjectId != subjectId) {
            throw const CurriculumPackageBuildException(
              'One or more selected units are no longer available.',
            );
          }
        }
        return;
      case CurriculumPackageScopeKind.selectedChapters:
        final classId = _required(selection.classId, 'class');
        final subjectId = _required(selection.subjectId, 'subject');
        if (selection.chapterIds.isEmpty) {
          throw const CurriculumPackageBuildException(
            'Select at least one chapter.',
          );
        }
        final subject = source.subjectById(subjectId);
        if (source.classById(classId)?.isArchived != false ||
            subject == null ||
            subject.isArchived ||
            subject.classId != classId) {
          throw const CurriculumPackageBuildException(
            'The selected subject does not belong to the selected class.',
          );
        }
        for (final chapterId in selection.chapterIds) {
          final chapter = source.chapterById(chapterId);
          if (chapter == null ||
              chapter.isArchived ||
              chapter.subjectId != subjectId) {
            throw const CurriculumPackageBuildException(
              'One or more selected chapters are no longer available.',
            );
          }
        }
        return;
      case CurriculumPackageScopeKind.selectedLessons:
        final classId = _required(selection.classId, 'class');
        final subjectId = _required(selection.subjectId, 'subject');
        if (selection.lessonPlanIds.isEmpty) {
          throw const CurriculumPackageBuildException(
            'Select at least one lesson.',
          );
        }
        final subject = source.subjectById(subjectId);
        if (source.classById(classId)?.isArchived != false ||
            subject == null ||
            subject.isArchived ||
            subject.classId != classId) {
          throw const CurriculumPackageBuildException(
            'The selected subject does not belong to the selected class.',
          );
        }
        for (final lessonId in selection.lessonPlanIds) {
          final lesson = source.lessonPlanById(lessonId);
          if (lesson == null ||
              lesson.isArchived ||
              lesson.classId != classId ||
              lesson.subjectId != subjectId) {
            throw const CurriculumPackageBuildException(
              'One or more selected lessons are no longer available.',
            );
          }
          final chapter = source.chapterById(lesson.chapterId);
          if (chapter == null ||
              chapter.isArchived ||
              chapter.subjectId != subjectId) {
            throw const CurriculumPackageBuildException(
              'A selected lesson belongs to an unavailable chapter.',
            );
          }
          for (final topicId in lesson.topicIds) {
            final topic = source.topicById(topicId);
            if (topic == null ||
                topic.isArchived ||
                topic.chapterId != lesson.chapterId) {
              throw const CurriculumPackageBuildException(
                'A selected lesson references an unavailable topic.',
              );
            }
          }
        }
        return;
    }
  }

  TeachingPlannerWorkspace _selectWorkspace(
    TeachingPlannerWorkspace source,
    CurriculumPackageSelection selection, {
    required bool includeLessonPlans,
  }) {
    final classIds = <String>{};
    final subjectIds = <String>{};
    final unitIds = <String>{};
    final chapterIds = <String>{};
    final topicIds = <String>{};
    final lessonIds = <String>{};

    void addSubjectTree(String subjectId) {
      final subject = source.subjectById(subjectId);
      if (subject == null || subject.isArchived) return;
      subjectIds.add(subject.id);
      classIds.add(subject.classId);
      for (final unit in source.units) {
        if (!unit.isArchived && unit.subjectId == subjectId) {
          unitIds.add(unit.id);
        }
      }
      for (final chapter in source.chapters) {
        if (!chapter.isArchived && chapter.subjectId == subjectId) {
          chapterIds.add(chapter.id);
        }
      }
      for (final topic in source.topics) {
        if (!topic.isArchived && chapterIds.contains(topic.chapterId)) {
          topicIds.add(topic.id);
        }
      }
      if (includeLessonPlans) {
        for (final lesson in source.lessonPlans) {
          if (!lesson.isArchived && lesson.subjectId == subjectId) {
            lessonIds.add(lesson.id);
          }
        }
      }
    }

    void addUnitTree(String unitId) {
      final unit = source.unitById(unitId);
      if (unit == null || unit.isArchived) return;
      unitIds.add(unit.id);
      subjectIds.add(unit.subjectId);
      final subject = source.subjectById(unit.subjectId);
      if (subject != null) classIds.add(subject.classId);
      for (final chapter in source.chapters) {
        if (!chapter.isArchived && chapter.unitId == unitId) {
          chapterIds.add(chapter.id);
        }
      }
      for (final topic in source.topics) {
        if (!topic.isArchived && chapterIds.contains(topic.chapterId)) {
          topicIds.add(topic.id);
        }
      }
      if (includeLessonPlans) {
        for (final lesson in source.lessonPlans) {
          if (!lesson.isArchived && chapterIds.contains(lesson.chapterId)) {
            lessonIds.add(lesson.id);
          }
        }
      }
    }

    void addChapterTree(String chapterId) {
      final chapter = source.chapterById(chapterId);
      if (chapter == null || chapter.isArchived) return;
      chapterIds.add(chapter.id);
      subjectIds.add(chapter.subjectId);
      final subject = source.subjectById(chapter.subjectId);
      if (subject != null) classIds.add(subject.classId);
      final unitId = chapter.unitId;
      if (unitId != null) unitIds.add(unitId);
      for (final topic in source.topics) {
        if (!topic.isArchived && topic.chapterId == chapterId) {
          topicIds.add(topic.id);
        }
      }
      if (includeLessonPlans) {
        for (final lesson in source.lessonPlans) {
          if (!lesson.isArchived && lesson.chapterId == chapterId) {
            lessonIds.add(lesson.id);
          }
        }
      }
    }

    switch (selection.kind) {
      case CurriculumPackageScopeKind.schoolCurriculum:
        for (final plannerClass in source.activeClasses) {
          classIds.add(plannerClass.id);
          for (final subject in source.activeSubjectsForClass(
            plannerClass.id,
          )) {
            addSubjectTree(subject.id);
          }
        }
        break;
      case CurriculumPackageScopeKind.classSyllabus:
        final classId = selection.classId!;
        classIds.add(classId);
        for (final subject in source.activeSubjectsForClass(classId)) {
          addSubjectTree(subject.id);
        }
        break;
      case CurriculumPackageScopeKind.subject:
        addSubjectTree(selection.subjectId!);
        break;
      case CurriculumPackageScopeKind.selectedUnits:
        for (final unitId in selection.unitIds) {
          addUnitTree(unitId);
        }
        break;
      case CurriculumPackageScopeKind.selectedChapters:
        for (final chapterId in selection.chapterIds) {
          addChapterTree(chapterId);
        }
        break;
      case CurriculumPackageScopeKind.selectedLessons:
        for (final lessonId in selection.lessonPlanIds) {
          final lesson = source.lessonPlanById(lessonId)!;
          lessonIds.add(lesson.id);
          classIds.add(lesson.classId);
          subjectIds.add(lesson.subjectId);
          chapterIds.add(lesson.chapterId);
          final chapter = source.chapterById(lesson.chapterId);
          final unitId = chapter?.unitId;
          if (unitId != null) unitIds.add(unitId);
          topicIds.addAll(lesson.topicIds);
        }
        break;
    }

    if (!includeLessonPlans &&
        selection.kind != CurriculumPackageScopeKind.selectedLessons) {
      lessonIds.clear();
    }

    final includedOwnerIds = _resourceOwnerScope(
      selection,
      classIds: classIds,
      subjectIds: subjectIds,
      unitIds: unitIds,
      chapterIds: chapterIds,
      topicIds: topicIds,
      lessonIds: lessonIds,
    );

    return TeachingPlannerWorkspace(
      classes: source.classes
          .where((item) => classIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      subjects: source.subjects
          .where((item) => subjectIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      units: source.units
          .where((item) => unitIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      chapters: source.chapters
          .where((item) => chapterIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      topics: source.topics
          .where((item) => topicIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      lessonPlans: source.lessonPlans
          .where((item) => lessonIds.contains(item.id) && !item.isArchived)
          .toList(growable: false),
      resources: source.resources
          .where((item) {
            if (item.isArchived) return false;
            return includedOwnerIds[item.owner.type]?.contains(item.owner.id) ==
                true;
          })
          .toList(growable: false),
    );
  }

  Map<TeachingResourceOwnerType, Set<String>> _resourceOwnerScope(
    CurriculumPackageSelection selection, {
    required Set<String> classIds,
    required Set<String> subjectIds,
    required Set<String> unitIds,
    required Set<String> chapterIds,
    required Set<String> topicIds,
    required Set<String> lessonIds,
  }) {
    Set<String> none() => const <String>{};
    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: classIds,
          TeachingResourceOwnerType.subject: subjectIds,
          TeachingResourceOwnerType.unit: unitIds,
          TeachingResourceOwnerType.chapter: chapterIds,
          TeachingResourceOwnerType.topic: topicIds,
          TeachingResourceOwnerType.lessonPlan: lessonIds,
        },
      CurriculumPackageScopeKind.classSyllabus =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: classIds,
          TeachingResourceOwnerType.subject: subjectIds,
          TeachingResourceOwnerType.unit: unitIds,
          TeachingResourceOwnerType.chapter: chapterIds,
          TeachingResourceOwnerType.topic: topicIds,
          TeachingResourceOwnerType.lessonPlan: lessonIds,
        },
      CurriculumPackageScopeKind.subject =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: none(),
          TeachingResourceOwnerType.subject: subjectIds,
          TeachingResourceOwnerType.unit: unitIds,
          TeachingResourceOwnerType.chapter: chapterIds,
          TeachingResourceOwnerType.topic: topicIds,
          TeachingResourceOwnerType.lessonPlan: lessonIds,
        },
      CurriculumPackageScopeKind.selectedUnits =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: none(),
          TeachingResourceOwnerType.subject: none(),
          TeachingResourceOwnerType.unit: selection.unitIds,
          TeachingResourceOwnerType.chapter: chapterIds,
          TeachingResourceOwnerType.topic: topicIds,
          TeachingResourceOwnerType.lessonPlan: lessonIds,
        },
      CurriculumPackageScopeKind.selectedChapters =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: none(),
          TeachingResourceOwnerType.subject: none(),
          TeachingResourceOwnerType.unit: none(),
          TeachingResourceOwnerType.chapter: selection.chapterIds,
          TeachingResourceOwnerType.topic: topicIds,
          TeachingResourceOwnerType.lessonPlan: lessonIds,
        },
      CurriculumPackageScopeKind.selectedLessons =>
        <TeachingResourceOwnerType, Set<String>>{
          TeachingResourceOwnerType.plannerClass: none(),
          TeachingResourceOwnerType.subject: none(),
          TeachingResourceOwnerType.unit: none(),
          TeachingResourceOwnerType.chapter: none(),
          TeachingResourceOwnerType.topic: none(),
          TeachingResourceOwnerType.lessonPlan: selection.lessonPlanIds,
        },
    };
  }

  bool _includeResource(
    TeachingResource resource,
    CurriculumPackageInclusions inclusions,
  ) {
    return switch (resource.kind) {
      TeachingResourceKind.note => inclusions.includeNotes,
      TeachingResourceKind.file => inclusions.includeFiles,
      TeachingResourceKind.link => inclusions.includeLinks,
      TeachingResourceKind.geometry => inclusions.includeGeometry,
      TeachingResourceKind.paper => inclusions.includePapers,
      // Smart Editor documents are planner links in TP-S1/S2. Their portable
      // document payload is added in the dedicated portability phase.
      TeachingResourceKind.smartDocument => false,
    };
  }

  Future<Map<String, List<int>>> _captureResourceFiles(
    TeachingPlannerWorkspace workspace,
  ) async {
    final result = <String, List<int>>{};
    for (final resource in workspace.resources) {
      if (resource.kind != TeachingResourceKind.file) continue;
      if (!await _resourceFileStore.resourceExists(resource)) {
        throw CurriculumPackageBuildException(
          'Attached teaching file is missing: '
          '${resource.originalFileName ?? resource.title}',
        );
      }
      result[resource.id] = await _resourceFileStore.readResourceBytes(resource);
    }
    return result;
  }

  Future<Map<String, PortablePaperSnapshot>> _capturePaperSnapshots(
    TeachingPlannerWorkspace workspace,
  ) async {
    final paperIds = workspace.resources
        .where((resource) => resource.kind == TeachingResourceKind.paper)
        .map((resource) => resource.linkedPaperId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (paperIds.isEmpty) return const {};

    final papers = await _paperRepository.getAllPapers();
    final byId = <String, Paper>{for (final paper in papers) paper.id: paper};
    final result = <String, PortablePaperSnapshot>{};
    for (final paperId in paperIds) {
      final paper = byId[paperId];
      if (paper == null) {
        throw CurriculumPackageBuildException(
          'Linked EduSheet paper is missing on this device: $paperId',
        );
      }
      result[paperId] = await PortablePaperSnapshot.capture(paper);
    }
    return result;
  }

  List<CurriculumEntityLineage> _buildLineage(
    TeachingPlannerWorkspace workspace,
    Iterable<PortablePaperSnapshot> papers, {
    CurriculumMergeState? mergeState,
  }) {
    final result = <CurriculumEntityLineage>[];
    final trackedByLocalKey = <String, CurriculumReplicaRecord>{
      for (final record
          in mergeState?.replicas ?? const <CurriculumReplicaRecord>[])
        '${record.entityType}:${record.localId}': record,
    };

    void add(String type, String id, DateTime updatedAt) {
      final tracked = trackedByLocalKey['$type:$id'];
      result.add(
        CurriculumEntityLineage(
          entityType: type,
          entityId: id,
          originId: tracked?.originId ?? id,
          revision: tracked?.sourceRevision ?? _revisionFor(updatedAt),
          updatedAt: updatedAt,
        ),
      );
    }

    for (final item in workspace.classes) {
      add('class', item.id, item.updatedAt);
    }
    for (final item in workspace.subjects) {
      add('subject', item.id, item.updatedAt);
    }
    for (final item in workspace.units) {
      add('unit', item.id, item.updatedAt);
    }
    for (final item in workspace.chapters) {
      add('chapter', item.id, item.updatedAt);
    }
    for (final item in workspace.topics) {
      add('topic', item.id, item.updatedAt);
    }
    for (final item in workspace.lessonPlans) {
      add('lessonPlan', item.id, item.updatedAt);
    }
    for (final item in workspace.resources) {
      add('resource', item.id, item.updatedAt);
    }
    for (final snapshot in papers) {
      final paper = snapshot.paper;
      final tracked = trackedByLocalKey['paper:${paper.id}'];
      result.add(
        CurriculumEntityLineage(
          entityType: 'paper',
          entityId: paper.id,
          originId: tracked?.originId ?? paper.originId,
          revision: tracked?.sourceRevision ?? paper.revision,
          updatedAt: paper.updatedAt,
        ),
      );
    }
    result.sort((a, b) {
      final type = a.entityType.compareTo(b.entityType);
      return type != 0 ? type : a.entityId.compareTo(b.entityId);
    });
    return result;
  }

  EdsContentType _contentTypeFor(CurriculumPackageSelection selection) {
    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        EdsContentType.schoolCurriculum,
      CurriculumPackageScopeKind.classSyllabus => EdsContentType.syllabus,
      CurriculumPackageScopeKind.subject => EdsContentType.subjectPack,
      CurriculumPackageScopeKind.selectedUnits => EdsContentType.subjectPack,
      CurriculumPackageScopeKind.selectedChapters => EdsContentType.chapterPack,
      CurriculumPackageScopeKind.selectedLessons => EdsContentType.chapterPack,
    };
  }

  String _titleFor(
    TeachingPlannerWorkspace source,
    CurriculumPackageSelection selection, {
    required CurriculumAssignmentMetadata? assignment,
    required String? sourceSchool,
  }) {
    final assignedTo = assignment?.assignedTo;
    final suffix = assignedTo == null ? '' : ' · $assignedTo';
    final school =
        _cleanLabel(sourceSchool) ?? _cleanLabel(assignment?.sourceSchool);

    String classLabel(String classId) {
      final plannerClass = source.classById(classId)!;
      final year = _cleanLabel(plannerClass.academicYear);
      return year == null ? plannerClass.name : '${plannerClass.name} · $year';
    }

    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        '${school ?? 'School'} Curriculum$suffix',
      CurriculumPackageScopeKind.classSyllabus =>
        '${classLabel(selection.classId!)} Syllabus$suffix',
      CurriculumPackageScopeKind.subject =>
        '${classLabel(selection.classId!)} · '
            '${source.subjectById(selection.subjectId!)!.name}$suffix',
      CurriculumPackageScopeKind.selectedUnits =>
        '${classLabel(selection.classId!)} · '
            '${source.subjectById(selection.subjectId!)!.name} · '
            '${selection.unitIds.length} unit(s)$suffix',
      CurriculumPackageScopeKind.selectedChapters =>
        '${classLabel(selection.classId!)} · '
            '${source.subjectById(selection.subjectId!)!.name} · '
            '${selection.chapterIds.length} chapter(s)$suffix',
      CurriculumPackageScopeKind.selectedLessons =>
        '${classLabel(selection.classId!)} · '
            '${source.subjectById(selection.subjectId!)!.name} · '
            '${selection.lessonPlanIds.length} lesson(s)$suffix',
    };
  }

  (String, String) _packageIdentity(
    TeachingPlannerWorkspace source,
    CurriculumPackageSelection selection, {
    required CurriculumAssignmentMetadata? assignment,
  }) {
    if (assignment != null) {
      return (assignment.assignmentId, assignment.assignmentId);
    }
    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum => (
        _selectionIdentity(
          'school-curriculum',
          source.activeClasses.map((item) => item.id).toSet(),
        ),
        _selectionIdentity(
          'school-curriculum',
          source.activeClasses.map((item) => item.id).toSet(),
        ),
      ),
      CurriculumPackageScopeKind.classSyllabus => (
        selection.classId!,
        selection.classId!,
      ),
      CurriculumPackageScopeKind.subject => (
        selection.subjectId!,
        selection.subjectId!,
      ),
      CurriculumPackageScopeKind.selectedUnits => (
        _selectionIdentity('units', selection.unitIds),
        _selectionIdentity('units', selection.unitIds),
      ),
      CurriculumPackageScopeKind.selectedChapters => (
        _selectionIdentity('chapters', selection.chapterIds),
        _selectionIdentity('chapters', selection.chapterIds),
      ),
      CurriculumPackageScopeKind.selectedLessons => (
        _selectionIdentity('lessons', selection.lessonPlanIds),
        _selectionIdentity('lessons', selection.lessonPlanIds),
      ),
    };
  }
}

String? _cleanLabel(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

String _required(String? value, String label) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    throw CurriculumPackageBuildException('Select a $label first.');
  }
  return text;
}

int _revisionFor(DateTime updatedAt) =>
    updatedAt.toUtc().millisecondsSinceEpoch.clamp(1, 1 << 62).toInt();

String _selectionIdentity(String prefix, Set<String> ids) {
  final sorted = ids.toList()..sort();
  return '$prefix:${sorted.join(',')}';
}
