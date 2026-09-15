import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_class.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../models/syllabus_filter.dart';

bool syllabusClassVisible(
  TeachingPlannerWorkspace workspace,
  PlannerClass value,
  String query,
  SyllabusFilter filter,
) {
  if (!syllabusMatchesClassFilter(workspace, value.id, filter)) {
    return false;
  }
  if (syllabusMatches(query, value.name) ||
      (value.academicYear != null &&
          syllabusMatches(query, value.academicYear!))) {
    return true;
  }
  if (query.trim().isEmpty) {
    return true;
  }
  return workspace
      .activeSubjectsForClass(value.id)
      .any(
        (subject) => syllabusSubjectVisible(workspace, subject, query, filter),
      );
}

bool syllabusSubjectVisible(
  TeachingPlannerWorkspace workspace,
  PlannerSubject value,
  String query,
  SyllabusFilter filter,
) {
  if (!syllabusMatchesSubjectFilter(workspace, value.id, filter)) {
    return false;
  }
  if (query.trim().isEmpty) {
    return true;
  }
  if (syllabusMatches(query, value.name) ||
      (value.code != null && syllabusMatches(query, value.code!))) {
    return true;
  }
  return workspace
          .activeUnitsForSubject(value.id)
          .any((unit) => syllabusMatchesUnit(workspace, unit, query, filter)) ||
      workspace
          .activeChaptersForSubject(value.id)
          .any(
            (chapter) =>
                syllabusMatchesChapter(workspace, chapter, query, filter),
          );
}

bool syllabusMatchesUnit(
  TeachingPlannerWorkspace workspace,
  PlannerUnit value,
  String query,
  SyllabusFilter filter,
) {
  if (!syllabusUnitFilter(workspace, value, filter)) {
    return false;
  }
  if (query.trim().isEmpty) {
    return true;
  }
  return syllabusMatches(query, value.title) ||
      workspace.chapters
          .where((chapter) => chapter.unitId == value.id && !chapter.isArchived)
          .any(
            (chapter) =>
                syllabusMatchesChapter(workspace, chapter, query, filter),
          );
}

bool syllabusMatchesChapter(
  TeachingPlannerWorkspace workspace,
  PlannerChapter value,
  String query,
  SyllabusFilter filter,
) {
  if (!syllabusChapterFilter(workspace, value, filter)) {
    return false;
  }
  if (query.trim().isEmpty) {
    return true;
  }
  return syllabusMatches(query, value.title) ||
      workspace
          .activeTopicsForChapter(value.id)
          .any(
            (topic) =>
                syllabusTopicFilter(topic, filter) &&
                syllabusMatches(query, topic.title),
          );
}

bool syllabusUnitFilter(
  TeachingPlannerWorkspace workspace,
  PlannerUnit value,
  SyllabusFilter filter,
) {
  switch (filter) {
    case SyllabusFilter.all:
      return true;
    case SyllabusFilter.highPriority:
      return value.priority == PlannerPriority.high ||
          workspace.chapters
              .where(
                (chapter) => chapter.unitId == value.id && !chapter.isArchived,
              )
              .any(
                (chapter) => syllabusChapterFilter(workspace, chapter, filter),
              );
    case SyllabusFilter.unplanned:
      return value.plannedPeriods == 0 ||
          workspace.chapters
              .where(
                (chapter) => chapter.unitId == value.id && !chapter.isArchived,
              )
              .any(
                (chapter) => syllabusChapterFilter(workspace, chapter, filter),
              );
    case SyllabusFilter.incomplete:
    case SyllabusFilter.completed:
      return workspace.chapters
          .where((chapter) => chapter.unitId == value.id && !chapter.isArchived)
          .any((chapter) => syllabusChapterFilter(workspace, chapter, filter));
  }
}

bool syllabusChapterFilter(
  TeachingPlannerWorkspace workspace,
  PlannerChapter value,
  SyllabusFilter filter,
) {
  final topics = workspace.activeTopicsForChapter(value.id);
  switch (filter) {
    case SyllabusFilter.all:
      return true;
    case SyllabusFilter.highPriority:
      return value.priority == PlannerPriority.high ||
          topics.any((topic) => topic.priority == PlannerPriority.high);
    case SyllabusFilter.unplanned:
      return value.plannedPeriods == 0 ||
          topics.any((topic) => topic.plannedPeriods == 0);
    case SyllabusFilter.completed:
      return topics.isNotEmpty &&
          topics.every(
            (topic) => topic.status == TeachingProgressStatus.completed,
          );
    case SyllabusFilter.incomplete:
      return topics.any(
        (topic) => topic.status != TeachingProgressStatus.completed,
      );
  }
}

bool syllabusTopicFilter(PlannerTopic value, SyllabusFilter filter) {
  switch (filter) {
    case SyllabusFilter.all:
      return true;
    case SyllabusFilter.highPriority:
      return value.priority == PlannerPriority.high;
    case SyllabusFilter.unplanned:
      return value.plannedPeriods == 0;
    case SyllabusFilter.completed:
      return value.status == TeachingProgressStatus.completed;
    case SyllabusFilter.incomplete:
      return value.status != TeachingProgressStatus.completed;
  }
}

bool syllabusMatchesClassFilter(
  TeachingPlannerWorkspace workspace,
  String classId,
  SyllabusFilter filter,
) {
  if (filter == SyllabusFilter.all) {
    return true;
  }
  return workspace
      .activeSubjectsForClass(classId)
      .any(
        (subject) =>
            syllabusMatchesSubjectFilter(workspace, subject.id, filter),
      );
}

bool syllabusMatchesSubjectFilter(
  TeachingPlannerWorkspace workspace,
  String subjectId,
  SyllabusFilter filter,
) {
  if (filter == SyllabusFilter.all) {
    return true;
  }
  return workspace
          .activeUnitsForSubject(subjectId)
          .any((unit) => syllabusUnitFilter(workspace, unit, filter)) ||
      workspace
          .activeChaptersForSubject(subjectId)
          .any((chapter) => syllabusChapterFilter(workspace, chapter, filter));
}

List<PlannerSubject> visibleSyllabusSubjects(
  TeachingPlannerWorkspace workspace,
  String classId,
  String query,
  SyllabusFilter filter,
) {
  return workspace
      .activeSubjectsForClass(classId)
      .where((value) => syllabusSubjectVisible(workspace, value, query, filter))
      .toList();
}

List<PlannerUnit> visibleSyllabusUnits(
  TeachingPlannerWorkspace workspace,
  String subjectId,
  String query,
  SyllabusFilter filter,
) {
  return workspace
      .activeUnitsForSubject(subjectId)
      .where((value) => syllabusMatchesUnit(workspace, value, query, filter))
      .toList();
}

List<PlannerChapter> visibleSyllabusChapters(
  TeachingPlannerWorkspace workspace,
  String subjectId,
  String? unitId,
  String query,
  SyllabusFilter filter,
) {
  return workspace
      .activeChaptersForSubject(subjectId, unitId: unitId)
      .where((value) => syllabusMatchesChapter(workspace, value, query, filter))
      .toList();
}

List<PlannerTopic> visibleSyllabusTopics(
  TeachingPlannerWorkspace workspace,
  String chapterId,
  String query,
  SyllabusFilter filter,
) {
  return workspace
      .activeTopicsForChapter(chapterId)
      .where(
        (value) =>
            syllabusTopicFilter(value, filter) &&
            (query.trim().isEmpty || syllabusMatches(query, value.title)),
      )
      .toList();
}

bool syllabusMatches(String query, String value) {
  return query.trim().isEmpty ||
      value.toLowerCase().contains(query.trim().toLowerCase());
}

String syllabusStatusLabel(TeachingProgressStatus status) {
  return switch (status) {
    TeachingProgressStatus.planned => 'Planned',
    TeachingProgressStatus.inProgress => 'In progress',
    TeachingProgressStatus.completed => 'Completed',
    TeachingProgressStatus.skipped => 'Skipped',
    TeachingProgressStatus.rescheduled => 'Rescheduled',
  };
}
