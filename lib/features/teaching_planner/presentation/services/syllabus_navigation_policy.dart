import '../../domain/models/teaching_planner_workspace.dart';
import '../models/syllabus_node_ref.dart';

/// Pure hierarchy rules shared by compact navigation and selection validation.
class SyllabusNavigationPolicy {
  const SyllabusNavigationPolicy._();

  static SyllabusNodeRef? validatedSelection(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef? selected,
  ) {
    if (selected == null) {
      return null;
    }
    switch (selected.kind) {
      case SyllabusNodeKind.classValue:
        final value = workspace.classById(selected.id);
        return value == null || value.isArchived ? null : selected;
      case SyllabusNodeKind.subject:
        final value = workspace.subjectById(selected.id);
        return value == null || value.isArchived ? null : selected;
      case SyllabusNodeKind.unit:
        final value = workspace.unitById(selected.id);
        return value == null || value.isArchived ? null : selected;
      case SyllabusNodeKind.chapter:
        final value = workspace.chapterById(selected.id);
        return value == null || value.isArchived ? null : selected;
      case SyllabusNodeKind.topic:
        final value = workspace.topicById(selected.id);
        return value == null || value.isArchived ? null : selected;
    }
  }

  static SyllabusNodeRef? parentOf(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef selected,
  ) {
    switch (selected.kind) {
      case SyllabusNodeKind.classValue:
        return null;
      case SyllabusNodeKind.subject:
        return SyllabusNodeRef.classValue(selected.classId);
      case SyllabusNodeKind.unit:
        return SyllabusNodeRef.subject(
          classId: selected.classId,
          subjectId: selected.subjectId!,
        );
      case SyllabusNodeKind.chapter:
        final chapter = workspace.chapterById(selected.id);
        if (chapter?.unitId != null) {
          return SyllabusNodeRef.unit(
            classId: selected.classId,
            subjectId: selected.subjectId!,
            unitId: chapter!.unitId!,
          );
        }
        return SyllabusNodeRef.subject(
          classId: selected.classId,
          subjectId: selected.subjectId!,
        );
      case SyllabusNodeKind.topic:
        return SyllabusNodeRef.chapter(
          classId: selected.classId,
          subjectId: selected.subjectId!,
          unitId: selected.unitId,
          chapterId: selected.chapterId!,
        );
    }
  }
}
