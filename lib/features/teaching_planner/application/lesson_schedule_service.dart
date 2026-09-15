import '../domain/models/lesson_plan.dart';
import '../domain/models/teaching_planner_workspace.dart';

class LessonScheduleConflict {
  final String classId;
  final DateTime date;
  final String firstLessonId;
  final String secondLessonId;

  const LessonScheduleConflict({
    required this.classId,
    required this.date,
    required this.firstLessonId,
    required this.secondLessonId,
  });
}

class LessonScheduleService {
  const LessonScheduleService();

  List<LessonPlan> lessonsOn(
    TeachingPlannerWorkspace workspace,
    DateTime date,
  ) {
    final day = _day(date);
    return workspace.activeLessonPlans
        .where((lesson) => _day(lesson.plannedDate) == day)
        .toList();
  }

  List<LessonScheduleConflict> conflicts(TeachingPlannerWorkspace workspace) {
    final lessons = workspace.activeLessonPlans
        .where((lesson) => lesson.startPeriod != null)
        .toList();
    final result = <LessonScheduleConflict>[];
    for (var i = 0; i < lessons.length; i++) {
      for (var j = i + 1; j < lessons.length; j++) {
        final a = lessons[i];
        final b = lessons[j];
        if (a.classId != b.classId ||
            _day(a.plannedDate) != _day(b.plannedDate))
          continue;
        final aStart = a.startPeriod!;
        final bStart = b.startPeriod!;
        final aEnd = aStart + (a.plannedPeriods > 0 ? a.plannedPeriods : 1) - 1;
        final bEnd = bStart + (b.plannedPeriods > 0 ? b.plannedPeriods : 1) - 1;
        if (aStart <= bEnd && bStart <= aEnd) {
          result.add(
            LessonScheduleConflict(
              classId: a.classId,
              date: _day(a.plannedDate),
              firstLessonId: a.id,
              secondLessonId: b.id,
            ),
          );
        }
      }
    }
    return result;
  }

  bool hasConflict(TeachingPlannerWorkspace workspace, String lessonId) =>
      conflicts(
        workspace,
      ).any((c) => c.firstLessonId == lessonId || c.secondLessonId == lessonId);

  static DateTime _day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
