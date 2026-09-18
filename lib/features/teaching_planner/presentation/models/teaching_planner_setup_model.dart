import '../../domain/models/planner_class.dart';
import '../../domain/models/teaching_planner_workspace.dart';

enum TeachingPlannerSetupStage { classSetup, syllabus, firstLesson, complete }

class TeachingPlannerSetupModel {
  const TeachingPlannerSetupModel({
    required this.stage,
    required this.activeClassCount,
    required this.activeSubjectCount,
    required this.activeChapterCount,
    required this.activeLessonCount,
    this.focusClassId,
  });

  final TeachingPlannerSetupStage stage;
  final int activeClassCount;
  final int activeSubjectCount;
  final int activeChapterCount;
  final int activeLessonCount;
  final String? focusClassId;

  bool get isComplete => stage == TeachingPlannerSetupStage.complete;

  int get currentStep => switch (stage) {
    TeachingPlannerSetupStage.classSetup => 0,
    TeachingPlannerSetupStage.syllabus => 1,
    TeachingPlannerSetupStage.firstLesson => 2,
    TeachingPlannerSetupStage.complete => 2,
  };

  factory TeachingPlannerSetupModel.fromWorkspace(
    TeachingPlannerWorkspace workspace,
  ) {
    final classes = workspace.activeClasses;
    final activeClassIds = classes.map((item) => item.id).toSet();
    final subjects = workspace.subjects
        .where(
          (item) => !item.isArchived && activeClassIds.contains(item.classId),
        )
        .toList(growable: false);
    final activeSubjectIds = subjects.map((item) => item.id).toSet();
    final chapters = workspace.chapters
        .where(
          (item) =>
              !item.isArchived && activeSubjectIds.contains(item.subjectId),
        )
        .toList(growable: false);
    final activeChapterIds = chapters.map((item) => item.id).toSet();
    final lessons = workspace.activeLessonPlans
        .where(
          (item) =>
              activeClassIds.contains(item.classId) &&
              activeSubjectIds.contains(item.subjectId) &&
              activeChapterIds.contains(item.chapterId),
        )
        .toList(growable: false);

    // A historical lesson means first-run setup was completed before, even if
    // the teacher later archived that lesson or its syllabus. Do not force
    // onboarding to reappear after normal archive operations.
    if (workspace.lessonPlans.isNotEmpty) {
      return TeachingPlannerSetupModel(
        stage: TeachingPlannerSetupStage.complete,
        activeClassCount: classes.length,
        activeSubjectCount: subjects.length,
        activeChapterCount: chapters.length,
        activeLessonCount: lessons.length,
        focusClassId: classes.isEmpty ? null : classes.first.id,
      );
    }

    if (classes.isEmpty) {
      return TeachingPlannerSetupModel(
        stage: TeachingPlannerSetupStage.classSetup,
        activeClassCount: 0,
        activeSubjectCount: subjects.length,
        activeChapterCount: chapters.length,
        activeLessonCount: lessons.length,
      );
    }

    PlannerClass? classWithUsableSyllabus;
    for (final classValue in classes) {
      final subjectIds = subjects
          .where((subject) => subject.classId == classValue.id)
          .map((subject) => subject.id)
          .toSet();
      if (chapters.any((chapter) => subjectIds.contains(chapter.subjectId))) {
        classWithUsableSyllabus = classValue;
        break;
      }
    }

    if (classWithUsableSyllabus == null) {
      return TeachingPlannerSetupModel(
        stage: TeachingPlannerSetupStage.syllabus,
        activeClassCount: classes.length,
        activeSubjectCount: subjects.length,
        activeChapterCount: chapters.length,
        activeLessonCount: lessons.length,
        focusClassId: classes.first.id,
      );
    }

    if (lessons.isEmpty) {
      return TeachingPlannerSetupModel(
        stage: TeachingPlannerSetupStage.firstLesson,
        activeClassCount: classes.length,
        activeSubjectCount: subjects.length,
        activeChapterCount: chapters.length,
        activeLessonCount: 0,
        focusClassId: classWithUsableSyllabus.id,
      );
    }

    return TeachingPlannerSetupModel(
      stage: TeachingPlannerSetupStage.complete,
      activeClassCount: classes.length,
      activeSubjectCount: subjects.length,
      activeChapterCount: chapters.length,
      activeLessonCount: lessons.length,
      focusClassId: classWithUsableSyllabus.id,
    );
  }
}
