import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';

/// Traditional syllabus coverage: the teacher completes chapters, while
/// subject/unit/class progress rolls up automatically from those chapters.
/// Topic progress remains available as detail, but does not drive the main
/// syllabus coverage percentage.
class SyllabusChapterProgress {
  const SyllabusChapterProgress({
    required this.totalChapters,
    required this.completedChapters,
    required this.inProgressChapters,
  });

  final int totalChapters;
  final int completedChapters;
  final int inProgressChapters;

  double get completion =>
      totalChapters == 0 ? 0 : completedChapters / totalChapters;

  int get completionPercent => (completion * 100).round();

  bool get hasChapters => totalChapters > 0;

  bool get isComplete =>
      totalChapters > 0 && completedChapters == totalChapters;

  TeachingProgressStatus get rollupStatus {
    if (isComplete) return TeachingProgressStatus.completed;
    if (completedChapters > 0 || inProgressChapters > 0) {
      return TeachingProgressStatus.inProgress;
    }
    return TeachingProgressStatus.planned;
  }

  String get compactLabel => '$completedChapters/$totalChapters chapters';

  static SyllabusChapterProgress forClass(
    TeachingPlannerWorkspace workspace,
    String classId,
  ) {
    final subjectIds = workspace
        .activeSubjectsForClass(classId)
        .map((subject) => subject.id)
        .toSet();
    return fromChapters(
      workspace.chapters.where(
        (chapter) =>
            !chapter.isArchived && subjectIds.contains(chapter.subjectId),
      ),
    );
  }

  static SyllabusChapterProgress forSubject(
    TeachingPlannerWorkspace workspace,
    String subjectId,
  ) {
    return fromChapters(
      workspace.chapters.where(
        (chapter) => !chapter.isArchived && chapter.subjectId == subjectId,
      ),
    );
  }

  static SyllabusChapterProgress forUnit(
    TeachingPlannerWorkspace workspace,
    String unitId,
  ) {
    return fromChapters(
      workspace.chapters.where(
        (chapter) => !chapter.isArchived && chapter.unitId == unitId,
      ),
    );
  }

  static SyllabusChapterProgress fromChapters(
    Iterable<PlannerChapter> chapters,
  ) {
    var total = 0;
    var completed = 0;
    var inProgress = 0;
    for (final chapter in chapters) {
      total += 1;
      switch (chapter.status) {
        case TeachingProgressStatus.completed:
          completed += 1;
          break;
        case TeachingProgressStatus.inProgress:
          inProgress += 1;
          break;
        case TeachingProgressStatus.planned:
        case TeachingProgressStatus.skipped:
        case TeachingProgressStatus.rescheduled:
          break;
      }
    }
    return SyllabusChapterProgress(
      totalChapters: total,
      completedChapters: completed,
      inProgressChapters: inProgress,
    );
  }
}
