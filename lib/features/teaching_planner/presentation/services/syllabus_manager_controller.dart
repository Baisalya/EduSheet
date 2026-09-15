import '../../domain/models/planner_priority.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../models/syllabus_node_ref.dart';
import '../providers/teaching_planner_provider.dart';

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

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}
