import '../../domain/models/planner_priority.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../models/syllabus_node_ref.dart';
import '../providers/teaching_planner_provider.dart';
import 'syllabus_navigation_policy.dart';

class SyllabusMutationOutcome {
  final bool success;
  final SyllabusNodeRef? selection;

  const SyllabusMutationOutcome({required this.success, this.selection});

  const SyllabusMutationOutcome.failure() : success = false, selection = null;
}

class SyllabusArchivePrompt {
  final String title;
  final String message;

  const SyllabusArchivePrompt({required this.title, required this.message});
}


class SyllabusTrashPrompt {
  final String title;
  final String message;

  const SyllabusTrashPrompt({required this.title, required this.message});
}

class SyllabusTrashEntry {
  final SyllabusNodeRef node;
  final String title;
  final String typeLabel;
  final DateTime trashedAt;
  final String impactLabel;

  const SyllabusTrashEntry({
    required this.node,
    required this.title,
    required this.typeLabel,
    required this.trashedAt,
    required this.impactLabel,
  });
}


class SyllabusRestorePrompt {
  final String title;
  final String message;
  final List<SyllabusNodeRef> trashedAncestors;

  const SyllabusRestorePrompt({
    required this.title,
    required this.message,
    required this.trashedAncestors,
  });

  bool get requiresParentRecovery => trashedAncestors.isNotEmpty;
}

class SyllabusRestoreDestination {
  final String id;
  final String title;
  final String subtitle;
  final String? subjectId;
  final String? unitId;
  final String? chapterId;

  const SyllabusRestoreDestination({
    required this.id,
    required this.title,
    required this.subtitle,
    this.subjectId,
    this.unitId,
    this.chapterId,
  });
}

/// Owns syllabus mutations and the selection transitions caused by them.
///
/// Widgets remain responsible for sheets/dialogs/snackbars. This controller
/// keeps repository mutations, newly-created entity detection, archive parent
/// selection and reorder behavior out of the Syllabus Manager widget.
class SyllabusManagerController {
  SyllabusManagerController({
    required TeachingPlannerNotifier notifier,
    required TeachingPlannerWorkspace Function() readWorkspace,
  }) : _notifier = notifier,
       _readWorkspace = readWorkspace;

  final TeachingPlannerNotifier _notifier;
  final TeachingPlannerWorkspace Function() _readWorkspace;

  Future<SyllabusMutationOutcome> createClass({
    required String name,
    String? academicYear,
  }) async {
    final before = _readWorkspace().classes.map((item) => item.id).toSet();
    final ok = await _notifier.createClass(
      name: name,
      academicYear: academicYear,
    );
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }

    final created = _firstWhereOrNull(
      _readWorkspace().activeClasses,
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.classValue(created.id),
    );
  }

  Future<SyllabusMutationOutcome> createSubject({
    required String classId,
    required String name,
    String? code,
  }) async {
    final before = _readWorkspace().subjects.map((item) => item.id).toSet();
    final ok = await _notifier.createSubject(
      classId: classId,
      name: name,
      code: code,
    );
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }

    final created = _firstWhereOrNull(
      _readWorkspace().activeSubjectsForClass(classId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.subject(classId: classId, subjectId: created.id),
    );
  }

  Future<SyllabusMutationOutcome> createUnit({
    required String subjectId,
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) async {
    final workspace = _readWorkspace();
    final subject = workspace.subjectById(subjectId);
    if (subject == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final before = workspace.units.map((item) => item.id).toSet();
    final ok = await _notifier.createUnit(
      subjectId: subjectId,
      title: title,
      plannedPeriods: plannedPeriods,
      priority: priority,
    );
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }

    final created = _firstWhereOrNull(
      _readWorkspace().activeUnitsForSubject(subjectId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.unit(
              classId: subject.classId,
              subjectId: subjectId,
              unitId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> createChapter({
    required String subjectId,
    required String? unitId,
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) async {
    final workspace = _readWorkspace();
    final subject = workspace.subjectById(subjectId);
    if (subject == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final before = workspace.chapters.map((item) => item.id).toSet();
    final ok = await _notifier.createChapter(
      subjectId: subjectId,
      unitId: unitId,
      title: title,
      plannedPeriods: plannedPeriods,
      priority: priority,
    );
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }

    final created = _firstWhereOrNull(
      _readWorkspace().chapters,
      (item) => !item.isArchived && !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.chapter(
              classId: subject.classId,
              subjectId: subjectId,
              unitId: created.unitId,
              chapterId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> createTopic({
    required String chapterId,
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) async {
    final workspace = _readWorkspace();
    final chapter = workspace.chapterById(chapterId);
    if (chapter == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final subject = workspace.subjectById(chapter.subjectId);
    if (subject == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final before = workspace.topics.map((item) => item.id).toSet();
    final ok = await _notifier.createTopic(
      chapterId: chapterId,
      title: title,
      plannedPeriods: plannedPeriods,
      priority: priority,
    );
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }

    final created = _firstWhereOrNull(
      _readWorkspace().activeTopicsForChapter(chapterId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.topic(
              classId: subject.classId,
              subjectId: subject.id,
              unitId: chapter.unitId,
              chapterId: chapter.id,
              topicId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> moveSubject({
    required String subjectId,
    required String destinationClassId,
  }) async {
    final ok = await _notifier.moveSubject(
      subjectId: subjectId,
      destinationClassId: destinationClassId,
    );
    return SyllabusMutationOutcome(
      success: ok,
      selection: ok
          ? SyllabusNodeRef.subject(
              classId: destinationClassId,
              subjectId: subjectId,
            )
          : null,
    );
  }

  Future<SyllabusMutationOutcome> moveUnit({
    required String unitId,
    required String destinationSubjectId,
  }) async {
    final destination = _readWorkspace().subjectById(destinationSubjectId);
    if (destination == null) return const SyllabusMutationOutcome.failure();
    final ok = await _notifier.moveUnit(
      unitId: unitId,
      destinationSubjectId: destinationSubjectId,
    );
    return SyllabusMutationOutcome(
      success: ok,
      selection: ok
          ? SyllabusNodeRef.unit(
              classId: destination.classId,
              subjectId: destinationSubjectId,
              unitId: unitId,
            )
          : null,
    );
  }

  Future<SyllabusMutationOutcome> moveChapter({
    required String chapterId,
    required String destinationSubjectId,
    required String? destinationUnitId,
  }) async {
    final destination = _readWorkspace().subjectById(destinationSubjectId);
    if (destination == null) return const SyllabusMutationOutcome.failure();
    final ok = await _notifier.moveChapter(
      chapterId: chapterId,
      destinationSubjectId: destinationSubjectId,
      destinationUnitId: destinationUnitId,
    );
    return SyllabusMutationOutcome(
      success: ok,
      selection: ok
          ? SyllabusNodeRef.chapter(
              classId: destination.classId,
              subjectId: destinationSubjectId,
              unitId: destinationUnitId,
              chapterId: chapterId,
            )
          : null,
    );
  }

  Future<SyllabusMutationOutcome> moveTopic({
    required String topicId,
    required String destinationChapterId,
  }) async {
    final workspace = _readWorkspace();
    final chapter = workspace.chapterById(destinationChapterId);
    final subject = chapter == null ? null : workspace.subjectById(chapter.subjectId);
    if (chapter == null || subject == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final ok = await _notifier.moveTopic(
      topicId: topicId,
      destinationChapterId: destinationChapterId,
    );
    return SyllabusMutationOutcome(
      success: ok,
      selection: ok
          ? SyllabusNodeRef.topic(
              classId: subject.classId,
              subjectId: subject.id,
              unitId: chapter.unitId,
              chapterId: chapter.id,
              topicId: topicId,
            )
          : null,
    );
  }

  Future<SyllabusMutationOutcome> duplicateSubject({
    required String subjectId,
    required String destinationClassId,
  }) async {
    final before = _readWorkspace().subjects.map((item) => item.id).toSet();
    final ok = await _notifier.duplicateSubjectStructure(
      subjectId: subjectId,
      destinationClassId: destinationClassId,
    );
    if (!ok) return const SyllabusMutationOutcome.failure();
    final created = _firstWhereOrNull(
      _readWorkspace().activeSubjectsForClass(destinationClassId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.subject(
              classId: destinationClassId,
              subjectId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> duplicateUnit({
    required String unitId,
    required String destinationSubjectId,
  }) async {
    final workspace = _readWorkspace();
    final destination = workspace.subjectById(destinationSubjectId);
    if (destination == null) return const SyllabusMutationOutcome.failure();
    final before = workspace.units.map((item) => item.id).toSet();
    final ok = await _notifier.duplicateUnitStructure(
      unitId: unitId,
      destinationSubjectId: destinationSubjectId,
    );
    if (!ok) return const SyllabusMutationOutcome.failure();
    final created = _firstWhereOrNull(
      _readWorkspace().activeUnitsForSubject(destinationSubjectId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.unit(
              classId: destination.classId,
              subjectId: destinationSubjectId,
              unitId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> duplicateChapter({
    required String chapterId,
    required String destinationSubjectId,
    required String? destinationUnitId,
  }) async {
    final workspace = _readWorkspace();
    final destination = workspace.subjectById(destinationSubjectId);
    if (destination == null) return const SyllabusMutationOutcome.failure();
    final before = workspace.chapters.map((item) => item.id).toSet();
    final ok = await _notifier.duplicateChapterStructure(
      chapterId: chapterId,
      destinationSubjectId: destinationSubjectId,
      destinationUnitId: destinationUnitId,
    );
    if (!ok) return const SyllabusMutationOutcome.failure();
    final created = _firstWhereOrNull(
      _readWorkspace().activeChaptersForSubject(
        destinationSubjectId,
        unitId: destinationUnitId,
      ),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.chapter(
              classId: destination.classId,
              subjectId: destinationSubjectId,
              unitId: destinationUnitId,
              chapterId: created.id,
            ),
    );
  }

  Future<SyllabusMutationOutcome> duplicateTopic({
    required String topicId,
    required String destinationChapterId,
  }) async {
    final workspace = _readWorkspace();
    final chapter = workspace.chapterById(destinationChapterId);
    final subject = chapter == null ? null : workspace.subjectById(chapter.subjectId);
    if (chapter == null || subject == null) {
      return const SyllabusMutationOutcome.failure();
    }
    final before = workspace.topics.map((item) => item.id).toSet();
    final ok = await _notifier.duplicateTopicStructure(
      topicId: topicId,
      destinationChapterId: destinationChapterId,
    );
    if (!ok) return const SyllabusMutationOutcome.failure();
    final created = _firstWhereOrNull(
      _readWorkspace().activeTopicsForChapter(destinationChapterId),
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.topic(
              classId: subject.classId,
              subjectId: subject.id,
              unitId: chapter.unitId,
              chapterId: chapter.id,
              topicId: created.id,
            ),
    );
  }

  SyllabusArchivePrompt? archivePrompt(SyllabusNodeRef node) {
    final workspace = _readWorkspace();
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        final value = workspace.classById(node.id);
        if (value == null) {
          return null;
        }
        final subjects = workspace.activeSubjectsForClass(value.id).length;
        return SyllabusArchivePrompt(
          title: 'Archive ${value.name}?',
          message:
              'This keeps the syllabus recoverable, but removes it from active planning. It will archive $subjects subject(s) and their descendants.',
        );
      case SyllabusNodeKind.subject:
        final value = workspace.subjectById(node.id);
        if (value == null) {
          return null;
        }
        final units = workspace.activeUnitsForSubject(value.id).length;
        final chapters = workspace.chapters
            .where((item) => item.subjectId == value.id && !item.isArchived)
            .length;
        return SyllabusArchivePrompt(
          title: 'Archive ${value.name}?',
          message:
              'The subject stays recoverable and will archive $units unit(s) and $chapters chapter(s) with their topics.',
        );
      case SyllabusNodeKind.unit:
        final value = workspace.unitById(node.id);
        if (value == null) {
          return null;
        }
        final chapters = workspace.chapters
            .where((item) => item.unitId == value.id && !item.isArchived)
            .length;
        return SyllabusArchivePrompt(
          title: 'Archive ${value.title}?',
          message:
              'This keeps the unit and archives its $chapters chapter(s) and topics.',
        );
      case SyllabusNodeKind.chapter:
        final value = workspace.chapterById(node.id);
        if (value == null) {
          return null;
        }
        final topics = workspace.activeTopicsForChapter(value.id).length;
        return SyllabusArchivePrompt(
          title: 'Archive ${value.title}?',
          message: 'This keeps the chapter and archives its $topics topic(s).',
        );
      case SyllabusNodeKind.topic:
        final value = workspace.topicById(node.id);
        if (value == null) {
          return null;
        }
        return SyllabusArchivePrompt(
          title: 'Archive ${value.title}?',
          message:
              'The topic will leave the active syllabus but remain stored for recovery.',
        );
    }
  }

  Future<SyllabusMutationOutcome> archive(SyllabusNodeRef node) async {
    final workspace = _readWorkspace();
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        final ok = await _notifier.archiveClass(node.id);
        return SyllabusMutationOutcome(success: ok);
      case SyllabusNodeKind.subject:
        final ok = await _notifier.archiveSubject(node.id);
        return SyllabusMutationOutcome(
          success: ok,
          selection: ok ? SyllabusNodeRef.classValue(node.classId) : null,
        );
      case SyllabusNodeKind.unit:
        final value = workspace.unitById(node.id);
        if (value == null) {
          return const SyllabusMutationOutcome.failure();
        }
        final ok = await _notifier.archiveUnit(node.id);
        return SyllabusMutationOutcome(
          success: ok,
          selection: ok
              ? SyllabusNodeRef.subject(
                  classId: node.classId,
                  subjectId: value.subjectId,
                )
              : null,
        );
      case SyllabusNodeKind.chapter:
        final value = workspace.chapterById(node.id);
        if (value == null) {
          return const SyllabusMutationOutcome.failure();
        }
        final ok = await _notifier.archiveChapter(node.id);
        return SyllabusMutationOutcome(
          success: ok,
          selection: !ok
              ? null
              : value.unitId == null
              ? SyllabusNodeRef.subject(
                  classId: node.classId,
                  subjectId: value.subjectId,
                )
              : SyllabusNodeRef.unit(
                  classId: node.classId,
                  subjectId: value.subjectId,
                  unitId: value.unitId!,
                ),
        );
      case SyllabusNodeKind.topic:
        final ok = await _notifier.archiveTopic(node.id);
        return SyllabusMutationOutcome(
          success: ok,
          selection: ok
              ? SyllabusNodeRef.chapter(
                  classId: node.classId,
                  subjectId: node.subjectId!,
                  unitId: node.unitId,
                  chapterId: node.chapterId!,
                )
              : null,
        );
    }
  }


  SyllabusTrashPrompt? trashPrompt(SyllabusNodeRef node) {
    final workspace = _readWorkspace();
    final title = _nodeTitle(workspace, node);
    final impact = _trashImpact(workspace, node);
    if (title == null || impact == null) return null;
    final bits = <String>[
      if (impact.subjects > 0) '${impact.subjects} subject(s)',
      if (impact.units > 0) '${impact.units} unit(s)',
      if (impact.chapters > 0) '${impact.chapters} chapter(s)',
      if (impact.topics > 0) '${impact.topics} topic(s)',
      if (impact.lessons > 0) '${impact.lessons} lesson plan(s)',
      if (impact.resources > 0) '${impact.resources} resource link(s)',
    ];
    final detail = bits.isEmpty ? 'this item' : bits.join(', ');
    return SyllabusTrashPrompt(
      title: 'Move $title to Trash?',
      message:
          'This will move $detail to Trash. Nothing is permanently deleted. You can undo or restore it later. Saved Papers themselves are not deleted.',
    );
  }

  Future<SyllabusMutationOutcome> moveToTrash(SyllabusNodeRef node) async {
    final workspace = _readWorkspace();
    final parent = SyllabusNavigationPolicy.parentOf(workspace, node);
    final ok = switch (node.kind) {
      SyllabusNodeKind.classValue => await _notifier.trashClass(node.id),
      SyllabusNodeKind.subject => await _notifier.trashSubject(node.id),
      SyllabusNodeKind.unit => await _notifier.trashUnit(node.id),
      SyllabusNodeKind.chapter => await _notifier.trashChapter(node.id),
      SyllabusNodeKind.topic => await _notifier.trashTopic(node.id),
    };
    return SyllabusMutationOutcome(success: ok, selection: ok ? parent : null);
  }

  SyllabusRestorePrompt restorePrompt(SyllabusNodeRef node) {
    final workspace = _readWorkspace();
    final title = _nodeTitle(workspace, node) ?? 'this item';
    final ancestors = _trashedAncestors(workspace, node);
    final message = ancestors.isEmpty
        ? 'Restore $title to its previous syllabus location?'
        : 'The parent syllabus hierarchy is also in Trash. Restore the required parent hierarchy, or restore $title to another active location.';
    return SyllabusRestorePrompt(
      title: 'Restore $title?',
      message: message,
      trashedAncestors: ancestors,
    );
  }

  Future<bool> restoreFromTrash(SyllabusNodeRef node) {
    return switch (node.kind) {
      SyllabusNodeKind.classValue => _notifier.restoreTrashedClass(node.id),
      SyllabusNodeKind.subject => _notifier.restoreTrashedSubject(node.id),
      SyllabusNodeKind.unit => _notifier.restoreTrashedUnit(node.id),
      SyllabusNodeKind.chapter => _notifier.restoreTrashedChapter(node.id),
      SyllabusNodeKind.topic => _notifier.restoreTrashedTopic(node.id),
    };
  }

  Future<bool> restoreHierarchyAndNode(SyllabusNodeRef node) async {
    final initial = _readWorkspace();
    final ancestors = _trashedAncestors(initial, node);
    for (final ancestor in ancestors) {
      if (!_isNodeTrashed(_readWorkspace(), ancestor)) continue;
      if (!await restoreFromTrash(ancestor)) return false;
    }
    if (!_isNodeTrashed(_readWorkspace(), node)) return true;
    return restoreFromTrash(node);
  }

  List<SyllabusRestoreDestination> restoreDestinations(SyllabusNodeRef node) {
    final workspace = _readWorkspace();
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        return const [];
      case SyllabusNodeKind.subject:
        return [
          for (final value in workspace.activeClasses)
            SyllabusRestoreDestination(
              id: value.id,
              title: value.name,
              subtitle: value.academicYear ?? 'Academic year not set',
            ),
        ];
      case SyllabusNodeKind.unit:
        return [
          for (final value in workspace.subjects.where((item) => !item.isArchived))
            SyllabusRestoreDestination(
              id: value.id,
              title: value.name,
              subtitle: workspace.classById(value.classId)?.name ?? 'Subject',
              subjectId: value.id,
            ),
        ];
      case SyllabusNodeKind.chapter:
        final result = <SyllabusRestoreDestination>[];
        for (final subject in workspace.subjects.where((item) => !item.isArchived)) {
          final className = workspace.classById(subject.classId)?.name ?? 'Class';
          result.add(
            SyllabusRestoreDestination(
              id: '${subject.id}:root',
              title: '${subject.name} · No unit',
              subtitle: className,
              subjectId: subject.id,
            ),
          );
          for (final unit in workspace.units.where(
            (item) => item.subjectId == subject.id && !item.isArchived,
          )) {
            result.add(
              SyllabusRestoreDestination(
                id: '${subject.id}:${unit.id}',
                title: '${subject.name} · ${unit.title}',
                subtitle: className,
                subjectId: subject.id,
                unitId: unit.id,
              ),
            );
          }
        }
        return result;
      case SyllabusNodeKind.topic:
        return [
          for (final chapter in workspace.chapters.where((item) => !item.isArchived))
            SyllabusRestoreDestination(
              id: chapter.id,
              title: chapter.title,
              subtitle: workspace.subjectById(chapter.subjectId)?.name ?? 'Chapter',
              chapterId: chapter.id,
            ),
        ];
    }
  }

  Future<bool> restoreToDestination(
    SyllabusNodeRef node,
    SyllabusRestoreDestination destination,
  ) {
    return switch (node.kind) {
      SyllabusNodeKind.classValue => Future<bool>.value(false),
      SyllabusNodeKind.subject => _notifier.restoreTrashedSubjectToClass(
          subjectId: node.id,
          destinationClassId: destination.id,
        ),
      SyllabusNodeKind.unit => _notifier.restoreTrashedUnitToSubject(
          unitId: node.id,
          destinationSubjectId: destination.subjectId ?? destination.id,
        ),
      SyllabusNodeKind.chapter => _notifier.restoreTrashedChapterToLocation(
          chapterId: node.id,
          destinationSubjectId: destination.subjectId!,
          destinationUnitId: destination.unitId,
        ),
      SyllabusNodeKind.topic => _notifier.restoreTrashedTopicToChapter(
          topicId: node.id,
          destinationChapterId: destination.chapterId ?? destination.id,
        ),
    };
  }

  Future<bool> deletePermanently(SyllabusNodeRef node) {
    return switch (node.kind) {
      SyllabusNodeKind.classValue => _notifier.deleteClassPermanently(node.id),
      SyllabusNodeKind.subject => _notifier.deleteSubjectPermanently(node.id),
      SyllabusNodeKind.unit => _notifier.deleteUnitPermanently(node.id),
      SyllabusNodeKind.chapter => _notifier.deleteChapterPermanently(node.id),
      SyllabusNodeKind.topic => _notifier.deleteTopicPermanently(node.id),
    };
  }

  List<SyllabusTrashEntry> trashEntries() {
    final workspace = _readWorkspace();
    final result = <SyllabusTrashEntry>[];
    bool same(DateTime? a, DateTime? b) => a != null && b != null && a == b;

    for (final value in workspace.classes.where((item) => item.isTrashed)) {
      result.add(_trashEntry(
        workspace,
        SyllabusNodeRef.classValue(value.id),
        value.name,
        'Syllabus',
        value.trashedAt!,
      ));
    }
    for (final value in workspace.subjects.where((item) => item.isTrashed)) {
      final parent = workspace.classById(value.classId);
      if (parent != null && same(parent.trashedAt, value.trashedAt)) continue;
      result.add(_trashEntry(
        workspace,
        SyllabusNodeRef.subject(classId: value.classId, subjectId: value.id),
        value.name,
        'Subject',
        value.trashedAt!,
      ));
    }
    for (final value in workspace.units.where((item) => item.isTrashed)) {
      final subject = workspace.subjectById(value.subjectId);
      if (subject != null && same(subject.trashedAt, value.trashedAt)) continue;
      result.add(_trashEntry(
        workspace,
        SyllabusNodeRef.unit(
          classId: subject?.classId ?? '',
          subjectId: value.subjectId,
          unitId: value.id,
        ),
        value.title,
        'Unit',
        value.trashedAt!,
      ));
    }
    for (final value in workspace.chapters.where((item) => item.isTrashed)) {
      final subject = workspace.subjectById(value.subjectId);
      final unit = value.unitId == null ? null : workspace.unitById(value.unitId!);
      final parentAt = unit?.trashedAt ?? subject?.trashedAt;
      if (same(parentAt, value.trashedAt)) continue;
      result.add(_trashEntry(
        workspace,
        SyllabusNodeRef.chapter(
          classId: subject?.classId ?? '',
          subjectId: value.subjectId,
          unitId: value.unitId,
          chapterId: value.id,
        ),
        value.title,
        'Chapter',
        value.trashedAt!,
      ));
    }
    for (final value in workspace.topics.where((item) => item.isTrashed)) {
      final chapter = workspace.chapterById(value.chapterId);
      if (chapter != null && same(chapter.trashedAt, value.trashedAt)) continue;
      final subject = chapter == null ? null : workspace.subjectById(chapter.subjectId);
      result.add(_trashEntry(
        workspace,
        SyllabusNodeRef.topic(
          classId: subject?.classId ?? '',
          subjectId: chapter?.subjectId ?? '',
          unitId: chapter?.unitId,
          chapterId: value.chapterId,
          topicId: value.id,
        ),
        value.title,
        'Topic',
        value.trashedAt!,
      ));
    }
    result.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return result;
  }

  SyllabusTrashEntry _trashEntry(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef node,
    String title,
    String typeLabel,
    DateTime trashedAt,
  ) {
    final impact = _trashImpact(workspace, node);
    final parts = <String>[
      if ((impact?.chapters ?? 0) > 0) '${impact!.chapters} chapters',
      if ((impact?.lessons ?? 0) > 0) '${impact!.lessons} lessons',
      if ((impact?.resources ?? 0) > 0) '${impact!.resources} resources',
    ];
    return SyllabusTrashEntry(
      node: node,
      title: title,
      typeLabel: typeLabel,
      trashedAt: trashedAt,
      impactLabel: parts.isEmpty ? 'No linked teaching items' : parts.join(' • '),
    );
  }

  Future<SyllabusMutationOutcome> importSyllabus(
    SyllabusImportPackage package,
  ) async {
    final before = _readWorkspace().classes.map((item) => item.id).toSet();
    final ok = await _notifier.importSyllabus(package);
    if (!ok) {
      return const SyllabusMutationOutcome.failure();
    }
    final created = _firstWhereOrNull(
      _readWorkspace().activeClasses,
      (item) => !before.contains(item.id),
    );
    return SyllabusMutationOutcome(
      success: true,
      selection: created == null
          ? null
          : SyllabusNodeRef.classValue(created.id),
    );
  }

  Future<bool> reorderSubjects(String classId, List<String> ids) {
    return _notifier.reorderSubjects(classId: classId, orderedSubjectIds: ids);
  }

  Future<bool> reorderUnits(String subjectId, List<String> ids) {
    return _notifier.reorderUnits(subjectId: subjectId, orderedUnitIds: ids);
  }

  Future<bool> reorderChapters(
    String subjectId,
    String? unitId,
    List<String> ids,
  ) {
    return _notifier.reorderChapters(
      subjectId: subjectId,
      unitId: unitId,
      orderedChapterIds: ids,
    );
  }

  Future<bool> reorderTopics(String chapterId, List<String> ids) {
    return _notifier.reorderTopics(chapterId: chapterId, orderedTopicIds: ids);
  }
}


List<SyllabusNodeRef> _trashedAncestors(
  TeachingPlannerWorkspace workspace,
  SyllabusNodeRef node,
) {
  final chain = <SyllabusNodeRef>[];
  void addIfTrashed(SyllabusNodeRef? value) {
    if (value != null && _isNodeTrashed(workspace, value)) chain.add(value);
  }

  switch (node.kind) {
    case SyllabusNodeKind.classValue:
      break;
    case SyllabusNodeKind.subject:
      final subject = workspace.subjectById(node.id);
      if (subject != null) {
        addIfTrashed(SyllabusNodeRef.classValue(subject.classId));
      }
      break;
    case SyllabusNodeKind.unit:
      final unit = workspace.unitById(node.id);
      final subject = unit == null ? null : workspace.subjectById(unit.subjectId);
      if (subject != null) {
        addIfTrashed(SyllabusNodeRef.classValue(subject.classId));
        addIfTrashed(SyllabusNodeRef.subject(classId: subject.classId, subjectId: subject.id));
      }
      break;
    case SyllabusNodeKind.chapter:
      final chapter = workspace.chapterById(node.id);
      final subject = chapter == null ? null : workspace.subjectById(chapter.subjectId);
      if (subject != null) {
        addIfTrashed(SyllabusNodeRef.classValue(subject.classId));
        addIfTrashed(SyllabusNodeRef.subject(classId: subject.classId, subjectId: subject.id));
        if (chapter!.unitId != null) {
          addIfTrashed(SyllabusNodeRef.unit(
            classId: subject.classId,
            subjectId: subject.id,
            unitId: chapter.unitId!,
          ));
        }
      }
      break;
    case SyllabusNodeKind.topic:
      final topic = workspace.topicById(node.id);
      final chapter = topic == null ? null : workspace.chapterById(topic.chapterId);
      final subject = chapter == null ? null : workspace.subjectById(chapter.subjectId);
      if (subject != null && chapter != null) {
        addIfTrashed(SyllabusNodeRef.classValue(subject.classId));
        addIfTrashed(SyllabusNodeRef.subject(classId: subject.classId, subjectId: subject.id));
        if (chapter.unitId != null) {
          addIfTrashed(SyllabusNodeRef.unit(
            classId: subject.classId,
            subjectId: subject.id,
            unitId: chapter.unitId!,
          ));
        }
        addIfTrashed(SyllabusNodeRef.chapter(
          classId: subject.classId,
          subjectId: subject.id,
          unitId: chapter.unitId,
          chapterId: chapter.id,
        ));
      }
      break;
  }
  return chain;
}

bool _isNodeTrashed(TeachingPlannerWorkspace workspace, SyllabusNodeRef node) {
  return switch (node.kind) {
    SyllabusNodeKind.classValue => workspace.classById(node.id)?.isTrashed ?? false,
    SyllabusNodeKind.subject => workspace.subjectById(node.id)?.isTrashed ?? false,
    SyllabusNodeKind.unit => workspace.unitById(node.id)?.isTrashed ?? false,
    SyllabusNodeKind.chapter => workspace.chapterById(node.id)?.isTrashed ?? false,
    SyllabusNodeKind.topic => workspace.topicById(node.id)?.isTrashed ?? false,
  };
}


class _SyllabusTrashImpact {
  const _SyllabusTrashImpact({
    this.subjects = 0,
    this.units = 0,
    this.chapters = 0,
    this.topics = 0,
    this.lessons = 0,
    this.resources = 0,
  });

  final int subjects;
  final int units;
  final int chapters;
  final int topics;
  final int lessons;
  final int resources;
}

String? _nodeTitle(TeachingPlannerWorkspace workspace, SyllabusNodeRef node) {
  return switch (node.kind) {
    SyllabusNodeKind.classValue => workspace.classById(node.id)?.name,
    SyllabusNodeKind.subject => workspace.subjectById(node.id)?.name,
    SyllabusNodeKind.unit => workspace.unitById(node.id)?.title,
    SyllabusNodeKind.chapter => workspace.chapterById(node.id)?.title,
    SyllabusNodeKind.topic => workspace.topicById(node.id)?.title,
  };
}

_SyllabusTrashImpact? _trashImpact(
  TeachingPlannerWorkspace workspace,
  SyllabusNodeRef node,
) {
  final classIds = <String>{};
  final subjectIds = <String>{};
  final unitIds = <String>{};
  final chapterIds = <String>{};
  final topicIds = <String>{};
  final lessonIds = <String>{};

  switch (node.kind) {
    case SyllabusNodeKind.classValue:
      if (workspace.classById(node.id) == null) return null;
      classIds.add(node.id);
      subjectIds.addAll(
        workspace.subjects.where((item) => item.classId == node.id).map((item) => item.id),
      );
      break;
    case SyllabusNodeKind.subject:
      if (workspace.subjectById(node.id) == null) return null;
      subjectIds.add(node.id);
      break;
    case SyllabusNodeKind.unit:
      if (workspace.unitById(node.id) == null) return null;
      unitIds.add(node.id);
      break;
    case SyllabusNodeKind.chapter:
      if (workspace.chapterById(node.id) == null) return null;
      chapterIds.add(node.id);
      break;
    case SyllabusNodeKind.topic:
      if (workspace.topicById(node.id) == null) return null;
      topicIds.add(node.id);
      break;
  }

  if (subjectIds.isNotEmpty) {
    unitIds.addAll(
      workspace.units.where((item) => subjectIds.contains(item.subjectId)).map((item) => item.id),
    );
    chapterIds.addAll(
      workspace.chapters.where((item) => subjectIds.contains(item.subjectId)).map((item) => item.id),
    );
  }
  if (unitIds.isNotEmpty) {
    chapterIds.addAll(
      workspace.chapters.where((item) => item.unitId != null && unitIds.contains(item.unitId)).map((item) => item.id),
    );
  }
  if (chapterIds.isNotEmpty) {
    topicIds.addAll(
      workspace.topics.where((item) => chapterIds.contains(item.chapterId)).map((item) => item.id),
    );
    lessonIds.addAll(
      workspace.lessonPlans.where((item) => chapterIds.contains(item.chapterId)).map((item) => item.id),
    );
  } else if (classIds.isNotEmpty) {
    lessonIds.addAll(
      workspace.lessonPlans.where((item) => classIds.contains(item.classId)).map((item) => item.id),
    );
  }

  bool resourceAffected(TeachingResourceOwner owner) => switch (owner.type) {
    TeachingResourceOwnerType.plannerClass => classIds.contains(owner.id),
    TeachingResourceOwnerType.subject => subjectIds.contains(owner.id),
    TeachingResourceOwnerType.unit => unitIds.contains(owner.id),
    TeachingResourceOwnerType.chapter => chapterIds.contains(owner.id),
    TeachingResourceOwnerType.topic => topicIds.contains(owner.id),
    TeachingResourceOwnerType.lessonPlan => lessonIds.contains(owner.id),
  };

  final resources = workspace.resources.where((item) => resourceAffected(item.owner)).length;
  return _SyllabusTrashImpact(
    subjects: subjectIds.length,
    units: unitIds.length,
    chapters: chapterIds.length,
    topics: topicIds.length,
    lessons: lessonIds.length,
    resources: resources,
  );
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}
