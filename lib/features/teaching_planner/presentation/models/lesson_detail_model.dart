import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

/// Presentation-only snapshot for the lesson detail UI.
///
/// It deliberately derives from the existing workspace instead of introducing
/// any new persistence or planner behaviour. The topic status metadata exists
/// only so the reference-style checklist can render real syllabus state.
class LessonDetailModel {
  const LessonDetailModel({
    required this.lesson,
    required this.className,
    required this.subjectName,
    required this.chapterName,
    required this.topics,
    required this.resourceCount,
  });

  final LessonPlan lesson;
  final String className;
  final String subjectName;
  final String chapterName;
  final List<LessonDetailTopic> topics;
  final int resourceCount;

  List<String> get topicNames =>
      topics.map((topic) => topic.title).toList(growable: false);

  factory LessonDetailModel.fromWorkspace(
    TeachingPlannerWorkspace workspace,
    LessonPlan lesson,
  ) {
    final topics = lesson.topicIds
        .map((id) => workspace.topicById(id))
        .whereType<PlannerTopic>()
        .map(
          (topic) =>
              LessonDetailTopic(title: topic.title, status: topic.status),
        )
        .toList(growable: false);
    return LessonDetailModel(
      lesson: lesson,
      className: workspace.classById(lesson.classId)?.name ?? 'Unknown class',
      subjectName:
          workspace.subjectById(lesson.subjectId)?.name ?? 'Unknown subject',
      chapterName:
          workspace.chapterById(lesson.chapterId)?.title ?? 'Unknown chapter',
      topics: List.unmodifiable(topics),
      resourceCount: workspace.activeResourcesForLesson(lesson.id).length,
    );
  }

  bool get hasTeachingRecord =>
      lesson.actualPeriods > 0 ||
      lesson.taughtAt != null ||
      lesson.reflection != null ||
      lesson.status == TeachingProgressStatus.inProgress ||
      lesson.status == TeachingProgressStatus.completed;

  bool get isCompleted => lesson.status == TeachingProgressStatus.completed;

  int get periodVariance => lesson.actualPeriods - lesson.plannedPeriods;

  double get periodProgress {
    if (lesson.plannedPeriods <= 0) {
      return lesson.actualPeriods > 0 ? 1 : 0;
    }
    return (lesson.actualPeriods / lesson.plannedPeriods)
        .clamp(0, 1)
        .toDouble();
  }

  String get statusLabel => switch (lesson.status) {
    TeachingProgressStatus.planned => 'Planned',
    TeachingProgressStatus.inProgress => 'In progress',
    TeachingProgressStatus.completed => 'Completed',
    TeachingProgressStatus.skipped => 'Skipped',
    TeachingProgressStatus.rescheduled => 'Rescheduled',
  };

  String get periodLabel {
    final count = lesson.plannedPeriods;
    if (lesson.startPeriod == null) {
      return '$count planned period${count == 1 ? '' : 's'}';
    }
    if (count <= 1) {
      return 'Period ${lesson.startPeriod}';
    }
    final end = lesson.startPeriod! + count - 1;
    return 'Periods ${lesson.startPeriod}–$end';
  }
}

class LessonDetailTopic {
  const LessonDetailTopic({required this.title, required this.status});

  final String title;
  final TeachingProgressStatus status;
}
