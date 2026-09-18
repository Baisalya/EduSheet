import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

class SyllabusOverviewMetrics {
  const SyllabusOverviewMetrics({
    required this.subjects,
    required this.units,
    required this.chapters,
    required this.topics,
    required this.completedTopics,
    required this.plannedPeriods,
  });

  final int subjects;
  final int units;
  final int chapters;
  final int topics;
  final int completedTopics;
  final int plannedPeriods;

  double get completion => topics == 0 ? 0 : completedTopics / topics;

  int get completionPercent => (completion * 100).round();
}

class SyllabusOverviewModel {
  const SyllabusOverviewModel._();

  static SyllabusOverviewMetrics forClass(
    TeachingPlannerWorkspace workspace,
    String classId,
  ) {
    final subjects = workspace.activeSubjectsForClass(classId);
    final subjectIds = subjects.map((item) => item.id).toSet();
    final units = workspace.units
        .where(
          (item) => subjectIds.contains(item.subjectId) && !item.isArchived,
        )
        .toList(growable: false);
    final chapters = workspace.chapters
        .where(
          (item) => subjectIds.contains(item.subjectId) && !item.isArchived,
        )
        .toList(growable: false);
    final chapterIds = chapters.map((item) => item.id).toSet();
    final topics = workspace.topics
        .where(
          (item) => chapterIds.contains(item.chapterId) && !item.isArchived,
        )
        .toList(growable: false);

    return _metrics(
      subjects: subjects.length,
      units: units.length,
      chapters: chapters.length,
      topics: topics,
    );
  }

  static SyllabusOverviewMetrics forSubject(
    TeachingPlannerWorkspace workspace,
    String subjectId,
  ) {
    final units = workspace.activeUnitsForSubject(subjectId);
    final chapters = workspace.chapters
        .where((item) => item.subjectId == subjectId && !item.isArchived)
        .toList(growable: false);
    final chapterIds = chapters.map((item) => item.id).toSet();
    final topics = workspace.topics
        .where(
          (item) => chapterIds.contains(item.chapterId) && !item.isArchived,
        )
        .toList(growable: false);

    return _metrics(
      units: units.length,
      chapters: chapters.length,
      topics: topics,
    );
  }

  static SyllabusOverviewMetrics forUnit(
    TeachingPlannerWorkspace workspace,
    String unitId,
  ) {
    final unit = workspace.unitById(unitId);
    if (unit == null || unit.isArchived) {
      return const SyllabusOverviewMetrics(
        subjects: 0,
        units: 0,
        chapters: 0,
        topics: 0,
        completedTopics: 0,
        plannedPeriods: 0,
      );
    }
    final chapters = workspace.activeChaptersForSubject(
      unit.subjectId,
      unitId: unit.id,
    );
    final chapterIds = chapters.map((item) => item.id).toSet();
    final topics = workspace.topics
        .where(
          (item) => chapterIds.contains(item.chapterId) && !item.isArchived,
        )
        .toList(growable: false);

    return _metrics(
      units: 1,
      chapters: chapters.length,
      topics: topics,
      extraPlannedPeriods: unit.plannedPeriods,
      includeTopicPeriods: false,
    );
  }

  static SyllabusOverviewMetrics forChapter(
    TeachingPlannerWorkspace workspace,
    String chapterId,
  ) {
    final chapter = workspace.chapterById(chapterId);
    if (chapter == null || chapter.isArchived) {
      return const SyllabusOverviewMetrics(
        subjects: 0,
        units: 0,
        chapters: 0,
        topics: 0,
        completedTopics: 0,
        plannedPeriods: 0,
      );
    }
    final topics = workspace.activeTopicsForChapter(chapter.id);
    return _metrics(
      chapters: 1,
      topics: topics,
      extraPlannedPeriods: chapter.plannedPeriods,
      includeTopicPeriods: false,
    );
  }

  static SyllabusOverviewMetrics _metrics({
    int subjects = 0,
    int units = 0,
    int chapters = 0,
    required List<PlannerTopic> topics,
    int extraPlannedPeriods = 0,
    bool includeTopicPeriods = true,
  }) {
    var completedTopics = 0;
    var topicPeriods = 0;
    for (final topic in topics) {
      if (topic.status == TeachingProgressStatus.completed) {
        completedTopics += 1;
      }
      topicPeriods += topic.plannedPeriods;
    }
    return SyllabusOverviewMetrics(
      subjects: subjects,
      units: units,
      chapters: chapters,
      topics: topics.length,
      completedTopics: completedTopics,
      plannedPeriods:
          extraPlannedPeriods + (includeTopicPeriods ? topicPeriods : 0),
    );
  }
}

String syllabusCountLabel(int count, String singular, {String? plural}) {
  return '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
}
