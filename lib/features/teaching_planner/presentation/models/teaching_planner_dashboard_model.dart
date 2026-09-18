import '../../application/planner_insights_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

class TeachingPlannerDashboardModel {
  const TeachingPlannerDashboardModel({
    required this.insights,
    required this.overallCompletion,
    required this.overallCompletionLabel,
    required this.accessLabel,
    required this.classCount,
    required this.subjectCount,
    required this.topicCount,
    required this.lessonCount,
    required this.pendingTopics,
    required this.todayLessons,
    required this.upcomingLessons,
    required this.classes,
  });

  final PlannerInsights insights;
  final double overallCompletion;
  final String overallCompletionLabel;
  final String accessLabel;
  final int classCount;
  final int subjectCount;
  final int topicCount;
  final int lessonCount;
  final int pendingTopics;
  final List<TeachingPlannerDashboardLesson> todayLessons;
  final List<TeachingPlannerDashboardLesson> upcomingLessons;
  final List<TeachingPlannerDashboardClass> classes;

  TeachingPlannerDashboardLesson? get nextLesson =>
      upcomingLessons.isEmpty ? null : upcomingLessons.first;

  factory TeachingPlannerDashboardModel.fromWorkspace(
    TeachingPlannerWorkspace workspace,
    TeachingPlannerCapabilities capabilities, {
    DateTime? now,
    PlannerInsightsService insightsService = const PlannerInsightsService(),
  }) {
    final resolvedNow = now ?? DateTime.now();
    final today = _dateOnly(resolvedNow);
    final insights = insightsService.calculate(workspace, now: resolvedNow);
    final useTopicProgress = insights.activeTopics > 0;
    final lessons = workspace.activeLessonPlans;

    final todayLessons = lessons
        .where((lesson) => _dateOnly(lesson.plannedDate) == today)
        .map(
          (lesson) =>
              TeachingPlannerDashboardLesson.fromWorkspace(lesson, workspace),
        )
        .toList(growable: false);

    final upcomingLessons = lessons
        .where((lesson) {
          if (_dateOnly(lesson.plannedDate).isBefore(today)) return false;
          return lesson.status != TeachingProgressStatus.completed &&
              lesson.status != TeachingProgressStatus.skipped;
        })
        .map(
          (lesson) =>
              TeachingPlannerDashboardLesson.fromWorkspace(lesson, workspace),
        )
        .take(5)
        .toList(growable: false);

    final classes = workspace.activeClasses
        .map(
          (plannerClass) => TeachingPlannerDashboardClass(
            id: plannerClass.id,
            name: plannerClass.name,
            academicYear: plannerClass.academicYear,
            subjectCount: workspace
                .activeSubjectsForClass(plannerClass.id)
                .length,
          ),
        )
        .toList(growable: false);

    return TeachingPlannerDashboardModel(
      insights: insights,
      overallCompletion: useTopicProgress
          ? insights.topicCompletionRate
          : insights.lessonCompletionRate,
      overallCompletionLabel: useTopicProgress
          ? 'Topics complete'
          : 'Lessons complete',
      accessLabel: switch (capabilities.accessLevel) {
        TeachingPlannerAccessLevel.free => 'Free',
        TeachingPlannerAccessLevel.pro => 'Pro',
        TeachingPlannerAccessLevel.complimentaryPro => 'Full access',
      },
      classCount: workspace.activeClassCount,
      subjectCount: workspace.activeSubjectCount,
      topicCount: workspace.activeTopicCount,
      lessonCount: lessons.length,
      pendingTopics: insights.activeTopics - insights.completedTopics,
      todayLessons: todayLessons,
      upcomingLessons: upcomingLessons,
      classes: classes,
    );
  }
}

class TeachingPlannerDashboardLesson {
  const TeachingPlannerDashboardLesson({
    required this.id,
    required this.title,
    required this.className,
    required this.subjectName,
    required this.plannedDate,
    required this.plannedPeriods,
    required this.startPeriod,
    required this.status,
  });

  final String id;
  final String title;
  final String className;
  final String subjectName;
  final DateTime plannedDate;
  final int plannedPeriods;
  final int? startPeriod;
  final TeachingProgressStatus status;

  String get periodLabel {
    if (startPeriod == null) {
      return '$plannedPeriods ${plannedPeriods == 1 ? 'period' : 'periods'}';
    }
    final endPeriod = startPeriod! + plannedPeriods - 1;
    if (endPeriod <= startPeriod!) return 'Period $startPeriod';
    return 'Periods $startPeriod–$endPeriod';
  }

  String get statusLabel => switch (status) {
    TeachingProgressStatus.planned => 'Planned',
    TeachingProgressStatus.inProgress => 'In progress',
    TeachingProgressStatus.completed => 'Completed',
    TeachingProgressStatus.skipped => 'Skipped',
    TeachingProgressStatus.rescheduled => 'Rescheduled',
  };

  factory TeachingPlannerDashboardLesson.fromWorkspace(
    LessonPlan lesson,
    TeachingPlannerWorkspace workspace,
  ) {
    return TeachingPlannerDashboardLesson(
      id: lesson.id,
      title: lesson.title,
      className: workspace.classById(lesson.classId)?.name ?? 'Unknown class',
      subjectName:
          workspace.subjectById(lesson.subjectId)?.name ?? 'Unknown subject',
      plannedDate: lesson.plannedDate,
      plannedPeriods: lesson.plannedPeriods,
      startPeriod: lesson.startPeriod,
      status: lesson.status,
    );
  }
}

class TeachingPlannerDashboardClass {
  const TeachingPlannerDashboardClass({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.subjectCount,
  });

  final String id;
  final String name;
  final String? academicYear;
  final int subjectCount;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
