import '../../application/lesson_schedule_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

class WeeklyPlannerLessonItem {
  const WeeklyPlannerLessonItem({
    required this.lesson,
    required this.className,
    required this.subjectName,
    required this.chapterTitle,
    required this.hasConflict,
  });

  final LessonPlan lesson;
  final String className;
  final String subjectName;
  final String chapterTitle;
  final bool hasConflict;
}

class WeeklyPlannerDay {
  const WeeklyPlannerDay({
    required this.date,
    required this.lessons,
    required this.plannedPeriods,
    required this.completedLessons,
  });

  final DateTime date;
  final List<WeeklyPlannerLessonItem> lessons;
  final int plannedPeriods;
  final int completedLessons;

  int get lessonCount => lessons.length;
  bool get hasLessons => lessons.isNotEmpty;
}

class WeeklyPlannerModel {
  const WeeklyPlannerModel({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.totalLessons,
    required this.completedLessons,
    required this.plannedPeriods,
    required this.slottedLessons,
    required this.conflictLessonCount,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyPlannerDay> days;
  final int totalLessons;
  final int completedLessons;
  final int plannedPeriods;
  final int slottedLessons;
  final int conflictLessonCount;

  double get completionRatio =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  WeeklyPlannerDay dayFor(DateTime date) => days.firstWhere(
    (day) => _sameDay(day.date, date),
    orElse: () => days.first,
  );

  factory WeeklyPlannerModel.fromWorkspace(
    TeachingPlannerWorkspace workspace,
    DateTime anchor, {
    LessonScheduleService schedule = const LessonScheduleService(),
  }) {
    final local = anchor.toLocal();
    final anchorDay = DateTime(local.year, local.month, local.day);
    final weekStart = anchorDay.subtract(Duration(days: anchorDay.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final conflicts = schedule.conflicts(workspace);
    final conflictLessonIds = <String>{
      for (final conflict in conflicts) ...[
        conflict.firstLessonId,
        conflict.secondLessonId,
      ],
    };

    final days = List<WeeklyPlannerDay>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final lessons =
          schedule.lessonsOn(workspace, date).map((lesson) {
            return WeeklyPlannerLessonItem(
              lesson: lesson,
              className: workspace.classById(lesson.classId)?.name ?? 'Class',
              subjectName:
                  workspace.subjectById(lesson.subjectId)?.name ?? 'Subject',
              chapterTitle:
                  workspace.chapterById(lesson.chapterId)?.title ?? 'Chapter',
              hasConflict: conflictLessonIds.contains(lesson.id),
            );
          }).toList()..sort((a, b) {
            final aPeriod = a.lesson.startPeriod;
            final bPeriod = b.lesson.startPeriod;
            if (aPeriod != null && bPeriod != null && aPeriod != bPeriod) {
              return aPeriod.compareTo(bPeriod);
            }
            if (aPeriod != null && bPeriod == null) {
              return -1;
            }
            if (aPeriod == null && bPeriod != null) {
              return 1;
            }
            return a.lesson.title.compareTo(b.lesson.title);
          });

      return WeeklyPlannerDay(
        date: date,
        lessons: List.unmodifiable(lessons),
        plannedPeriods: lessons.fold(
          0,
          (total, item) => total + item.lesson.plannedPeriods,
        ),
        completedLessons: lessons
            .where(
              (item) => item.lesson.status == TeachingProgressStatus.completed,
            )
            .length,
      );
    });

    final weekLessons = days.expand((day) => day.lessons).toList();
    return WeeklyPlannerModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      days: List.unmodifiable(days),
      totalLessons: weekLessons.length,
      completedLessons: weekLessons
          .where(
            (item) => item.lesson.status == TeachingProgressStatus.completed,
          )
          .length,
      plannedPeriods: weekLessons.fold(
        0,
        (total, item) => total + item.lesson.plannedPeriods,
      ),
      slottedLessons: weekLessons
          .where((item) => item.lesson.startPeriod != null)
          .length,
      conflictLessonCount: weekLessons.where((item) => item.hasConflict).length,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
