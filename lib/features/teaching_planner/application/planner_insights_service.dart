import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_status.dart';

class PlannerInsights {
  final int activeLessons;
  final int completedLessons;
  final int plannedLessonPeriods;
  final int actualLessonPeriods;
  final int activeTopics;
  final int completedTopics;
  final int plannedTopicPeriods;
  final int actualTopicPeriods;
  final int overdueLessons;
  final int upcomingSevenDays;

  const PlannerInsights({
    required this.activeLessons,
    required this.completedLessons,
    required this.plannedLessonPeriods,
    required this.actualLessonPeriods,
    required this.activeTopics,
    required this.completedTopics,
    required this.plannedTopicPeriods,
    required this.actualTopicPeriods,
    required this.overdueLessons,
    required this.upcomingSevenDays,
  });

  double get lessonCompletionRate =>
      activeLessons == 0 ? 0 : completedLessons / activeLessons;
  double get topicCompletionRate =>
      activeTopics == 0 ? 0 : completedTopics / activeTopics;
  int get lessonPeriodVariance => actualLessonPeriods - plannedLessonPeriods;
  int get topicPeriodVariance => actualTopicPeriods - plannedTopicPeriods;
}

class PlannerInsightsService {
  const PlannerInsightsService();

  PlannerInsights calculate(
    TeachingPlannerWorkspace workspace, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final upcomingEnd = today.add(const Duration(days: 7));
    final lessons = workspace.activeLessonPlans;
    final topics = workspace.topics.where((item) => !item.isArchived).toList();

    return PlannerInsights(
      activeLessons: lessons.length,
      completedLessons: lessons
          .where((item) => item.status == TeachingProgressStatus.completed)
          .length,
      plannedLessonPeriods: lessons.fold(
        0,
        (sum, item) => sum + item.plannedPeriods,
      ),
      actualLessonPeriods: lessons.fold(
        0,
        (sum, item) => sum + item.actualPeriods,
      ),
      activeTopics: topics.length,
      completedTopics: topics
          .where((item) => item.status == TeachingProgressStatus.completed)
          .length,
      plannedTopicPeriods: topics.fold(
        0,
        (sum, item) => sum + item.plannedPeriods,
      ),
      actualTopicPeriods: topics.fold(
        0,
        (sum, item) => sum + item.actualPeriods,
      ),
      overdueLessons: lessons.where((item) {
        if (item.status == TeachingProgressStatus.completed ||
            item.status == TeachingProgressStatus.skipped) {
          return false;
        }
        return _dateOnly(item.plannedDate).isBefore(today);
      }).length,
      upcomingSevenDays: lessons.where((item) {
        final date = _dateOnly(item.plannedDate);
        return !date.isBefore(today) && date.isBefore(upcomingEnd);
      }).length,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
