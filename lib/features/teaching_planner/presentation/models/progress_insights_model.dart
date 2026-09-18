import '../../application/planner_insights_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

class ProgressInsightsModel {
  const ProgressInsightsModel({
    required this.insights,
    required this.overallProgress,
    required this.overallProgressLabel,
    required this.subjects,
    required this.upcomingLessons,
    required this.overdueLessons,
    required this.highPriorityPendingTopics,
    required this.completedTopicCount,
    required this.inProgressTopicCount,
    required this.remainingTopicCount,
    required this.selectedClassId,
    required this.topics,
    required this.lessons,
    required this.now,
  });

  final PlannerInsights insights;
  final double overallProgress;
  final String overallProgressLabel;
  final List<SubjectProgressInsight> subjects;
  final List<ProgressLessonInsight> upcomingLessons;
  final List<ProgressLessonInsight> overdueLessons;
  final List<ProgressTopicInsight> highPriorityPendingTopics;
  final int completedTopicCount;
  final int inProgressTopicCount;
  final int remainingTopicCount;
  final String? selectedClassId;
  final List<PlannerTopic> topics;
  final List<LessonPlan> lessons;
  final DateTime now;

  int get pendingTopics => inProgressTopicCount + remainingTopicCount;
  int get periodVariance => insights.lessonPeriodVariance;

  factory ProgressInsightsModel.fromWorkspace(
    TeachingPlannerWorkspace workspace, {
    String? classId,
    DateTime? now,
    PlannerInsightsService insightsService = const PlannerInsightsService(),
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final activeClassIds = classId == null
        ? workspace.activeClasses.map((item) => item.id).toSet()
        : <String>{classId};

    final subjects =
        workspace.subjects
            .where(
              (item) =>
                  !item.isArchived && activeClassIds.contains(item.classId),
            )
            .toList()
          ..sort((a, b) {
            final classCompare = a.classId.compareTo(b.classId);
            if (classCompare != 0) {
              return classCompare;
            }
            return a.sortOrder.compareTo(b.sortOrder);
          });
    final subjectIds = subjects.map((item) => item.id).toSet();

    final chapters = workspace.chapters
        .where(
          (item) => !item.isArchived && subjectIds.contains(item.subjectId),
        )
        .toList();
    final chapterIds = chapters.map((item) => item.id).toSet();

    final topics = workspace.topics
        .where(
          (item) => !item.isArchived && chapterIds.contains(item.chapterId),
        )
        .toList();
    final lessons = workspace.activeLessonPlans
        .where((item) => activeClassIds.contains(item.classId))
        .toList();

    final filteredWorkspace = TeachingPlannerWorkspace(
      classes: workspace.classes
          .where((item) => activeClassIds.contains(item.id))
          .toList(),
      subjects: subjects,
      chapters: chapters,
      topics: topics,
      lessonPlans: lessons,
    );
    final insights = insightsService.calculate(filteredWorkspace, now: today);

    final completedTopics = topics
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final inProgressTopics = topics
        .where((item) => item.status == TeachingProgressStatus.inProgress)
        .length;
    final remainingTopics = topics.length - completedTopics - inProgressTopics;

    final subjectProgress =
        subjects.map((subject) {
          final subjectChapterIds = chapters
              .where((item) => item.subjectId == subject.id)
              .map((item) => item.id)
              .toSet();
          final subjectTopics = topics
              .where((item) => subjectChapterIds.contains(item.chapterId))
              .toList();
          final subjectLessons = lessons
              .where((item) => item.subjectId == subject.id)
              .toList();
          final topicCompleted = subjectTopics
              .where((item) => item.status == TeachingProgressStatus.completed)
              .length;
          final lessonCompleted = subjectLessons
              .where((item) => item.status == TeachingProgressStatus.completed)
              .length;
          final usesTopics = subjectTopics.isNotEmpty;
          final progress = usesTopics
              ? topicCompleted / subjectTopics.length
              : subjectLessons.isEmpty
              ? 0.0
              : lessonCompleted / subjectLessons.length;
          final plannedPeriods = usesTopics
              ? subjectTopics.fold<int>(
                  0,
                  (sum, item) => sum + item.plannedPeriods,
                )
              : subjectLessons.fold<int>(
                  0,
                  (sum, item) => sum + item.plannedPeriods,
                );
          final actualPeriods = usesTopics
              ? subjectTopics.fold<int>(
                  0,
                  (sum, item) => sum + item.actualPeriods,
                )
              : subjectLessons.fold<int>(
                  0,
                  (sum, item) => sum + item.actualPeriods,
                );
          return SubjectProgressInsight(
            subjectId: subject.id,
            subjectName: subject.name,
            className: workspace.classById(subject.classId)?.name ?? 'Class',
            progress: progress,
            completedTopics: topicCompleted,
            totalTopics: subjectTopics.length,
            completedLessons: lessonCompleted,
            totalLessons: subjectLessons.length,
            plannedPeriods: plannedPeriods,
            actualPeriods: actualPeriods,
            usesTopicProgress: usesTopics,
          );
        }).toList()..sort((a, b) {
          final classCompare = a.className.compareTo(b.className);
          if (classCompare != 0) {
            return classCompare;
          }
          return a.subjectName.compareTo(b.subjectName);
        });

    ProgressLessonInsight lessonInsight(LessonPlan lesson) {
      return ProgressLessonInsight(
        lesson: lesson,
        className: workspace.classById(lesson.classId)?.name ?? 'Class',
        subjectName: workspace.subjectById(lesson.subjectId)?.name ?? 'Subject',
        chapterTitle:
            workspace.chapterById(lesson.chapterId)?.title ?? 'Chapter',
      );
    }

    final upcoming =
        lessons
            .where((lesson) {
              if (lesson.status == TeachingProgressStatus.completed ||
                  lesson.status == TeachingProgressStatus.skipped) {
                return false;
              }
              final date = _dateOnly(lesson.plannedDate);
              return !date.isBefore(today) &&
                  date.isBefore(today.add(const Duration(days: 7)));
            })
            .map(lessonInsight)
            .toList()
          ..sort(
            (a, b) => a.lesson.plannedDate.compareTo(b.lesson.plannedDate),
          );

    final overdue =
        lessons
            .where((lesson) {
              if (lesson.status == TeachingProgressStatus.completed ||
                  lesson.status == TeachingProgressStatus.skipped) {
                return false;
              }
              return _dateOnly(lesson.plannedDate).isBefore(today);
            })
            .map(lessonInsight)
            .toList()
          ..sort(
            (a, b) => a.lesson.plannedDate.compareTo(b.lesson.plannedDate),
          );

    final highPriority =
        topics
            .where((topic) {
              return topic.priority == PlannerPriority.high &&
                  topic.status != TeachingProgressStatus.completed;
            })
            .map((topic) {
              final chapter = workspace.chapterById(topic.chapterId);
              final subject = chapter == null
                  ? null
                  : workspace.subjectById(chapter.subjectId);
              return ProgressTopicInsight(
                topic: topic,
                chapterTitle: chapter?.title ?? 'Chapter',
                subjectName: subject?.name ?? 'Subject',
                className: subject == null
                    ? 'Class'
                    : workspace.classById(subject.classId)?.name ?? 'Class',
              );
            })
            .toList()
          ..sort((a, b) {
            final statusCompare = a.topic.status.index.compareTo(
              b.topic.status.index,
            );
            if (statusCompare != 0) {
              return statusCompare;
            }
            return a.topic.sortOrder.compareTo(b.topic.sortOrder);
          });

    final usesTopics = topics.isNotEmpty;
    final overallProgress = usesTopics
        ? insights.topicCompletionRate
        : insights.lessonCompletionRate;

    return ProgressInsightsModel(
      insights: insights,
      overallProgress: overallProgress,
      overallProgressLabel: usesTopics ? 'Topics complete' : 'Lessons complete',
      subjects: subjectProgress,
      upcomingLessons: upcoming,
      overdueLessons: overdue,
      highPriorityPendingTopics: highPriority,
      completedTopicCount: completedTopics,
      inProgressTopicCount: inProgressTopics,
      remainingTopicCount: remainingTopics,
      selectedClassId: classId,
      topics: List.unmodifiable(topics),
      lessons: List.unmodifiable(lessons),
      now: today,
    );
  }
}

class SubjectProgressInsight {
  const SubjectProgressInsight({
    required this.subjectId,
    required this.subjectName,
    required this.className,
    required this.progress,
    required this.completedTopics,
    required this.totalTopics,
    required this.completedLessons,
    required this.totalLessons,
    required this.plannedPeriods,
    required this.actualPeriods,
    required this.usesTopicProgress,
  });

  final String subjectId;
  final String subjectName;
  final String className;
  final double progress;
  final int completedTopics;
  final int totalTopics;
  final int completedLessons;
  final int totalLessons;
  final int plannedPeriods;
  final int actualPeriods;
  final bool usesTopicProgress;

  String get progressDetail => usesTopicProgress
      ? '$completedTopics of $totalTopics topics'
      : '$completedLessons of $totalLessons lessons';
}

class ProgressLessonInsight {
  const ProgressLessonInsight({
    required this.lesson,
    required this.className,
    required this.subjectName,
    required this.chapterTitle,
  });

  final LessonPlan lesson;
  final String className;
  final String subjectName;
  final String chapterTitle;
}

class ProgressTopicInsight {
  const ProgressTopicInsight({
    required this.topic,
    required this.chapterTitle,
    required this.subjectName,
    required this.className,
  });

  final PlannerTopic topic;
  final String chapterTitle;
  final String subjectName;
  final String className;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
