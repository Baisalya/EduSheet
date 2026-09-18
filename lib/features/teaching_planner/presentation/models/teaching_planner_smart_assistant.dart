import '../../../guided_experience/domain/contextual_help.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import 'syllabus_node_ref.dart';

enum TeachingPlannerSmartAssistantAction {
  createSyllabus,
  createSubject,
  createChapter,
  planChapterLesson,
  addChapterMaterial,
}

class TeachingPlannerSmartAssistantRecommendation {
  const TeachingPlannerSmartAssistantRecommendation({
    required this.suggestion,
    required this.action,
    this.classId,
    this.subjectId,
    this.unitId,
    this.chapterId,
  });

  final ContextualHelpSuggestion suggestion;
  final TeachingPlannerSmartAssistantAction action;
  final String? classId;
  final String? subjectId;
  final String? unitId;
  final String? chapterId;
}

/// Produces small, deterministic next-step suggestions from the real syllabus.
///
/// The service intentionally prefers required structure over optional detail:
/// class -> subject -> chapter -> lesson -> optional teaching material. Topics
/// are never treated as required because EduSheet's usable syllabus contract is
/// satisfied by a subject plus a chapter.
class TeachingPlannerSmartAssistantService {
  const TeachingPlannerSmartAssistantService();

  static const Duration idleDelay = Duration(minutes: 1);

  TeachingPlannerSmartAssistantRecommendation? recommendForSyllabus({
    required TeachingPlannerWorkspace workspace,
    SyllabusNodeRef? selected,
  }) {
    if (workspace.activeClasses.isEmpty) {
      return _createSyllabusRecommendation();
    }

    if (selected != null) {
      return _recommendForSelection(workspace, selected);
    }

    return _firstRequiredGap(workspace) ?? _firstUsefulChapterStep(workspace);
  }

  TeachingPlannerSmartAssistantRecommendation? _recommendForSelection(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef selected,
  ) {
    switch (selected.kind) {
      case SyllabusNodeKind.classValue:
        final classValue = workspace.classById(selected.classId);
        if (classValue == null || classValue.isArchived) return null;
        final subjects = workspace.activeSubjectsForClass(classValue.id);
        if (subjects.isEmpty) {
          return _createSubjectRecommendation(
            classId: classValue.id,
            className: classValue.name,
          );
        }
        for (final subject in subjects) {
          if (_chaptersForSubject(workspace, subject.id).isEmpty) {
            return _createChapterRecommendation(
              classId: classValue.id,
              className: classValue.name,
              subjectId: subject.id,
              subjectName: subject.name,
            );
          }
        }
        for (final subject in subjects) {
          for (final chapter in _chaptersForSubject(workspace, subject.id)) {
            final recommendation = _chapterRecommendation(
              workspace,
              classId: classValue.id,
              className: classValue.name,
              subjectId: subject.id,
              subjectName: subject.name,
              chapterId: chapter.id,
              chapterTitle: chapter.title,
              unitId: chapter.unitId,
            );
            if (recommendation != null) return recommendation;
          }
        }
        return null;
      case SyllabusNodeKind.subject:
        final subjectId = selected.subjectId;
        if (subjectId == null) return null;
        final subject = workspace.subjectById(subjectId);
        final classValue = workspace.classById(selected.classId);
        if (subject == null || subject.isArchived || classValue == null) {
          return null;
        }
        final chapters = _chaptersForSubject(workspace, subject.id);
        if (chapters.isEmpty) {
          return _createChapterRecommendation(
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
          );
        }
        for (final chapter in chapters) {
          final recommendation = _chapterRecommendation(
            workspace,
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            unitId: chapter.unitId,
          );
          if (recommendation != null) return recommendation;
        }
        return null;
      case SyllabusNodeKind.unit:
        final subjectId = selected.subjectId;
        final unitId = selected.unitId;
        if (subjectId == null || unitId == null) return null;
        final subject = workspace.subjectById(subjectId);
        final classValue = workspace.classById(selected.classId);
        final unit = workspace.unitById(unitId);
        if (subject == null || classValue == null || unit == null) return null;
        final chapters = workspace.activeChaptersForSubject(
          subject.id,
          unitId: unit.id,
        );
        if (chapters.isEmpty) {
          return _createChapterRecommendation(
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
            unitId: unit.id,
          );
        }
        for (final chapter in chapters) {
          final recommendation = _chapterRecommendation(
            workspace,
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            unitId: unit.id,
          );
          if (recommendation != null) return recommendation;
        }
        return null;
      case SyllabusNodeKind.chapter:
      case SyllabusNodeKind.topic:
        final chapterId = selected.chapterId;
        final subjectId = selected.subjectId;
        if (chapterId == null || subjectId == null) return null;
        final chapter = workspace.chapterById(chapterId);
        final subject = workspace.subjectById(subjectId);
        final classValue = workspace.classById(selected.classId);
        if (chapter == null || subject == null || classValue == null) {
          return null;
        }
        return _chapterRecommendation(
          workspace,
          classId: classValue.id,
          className: classValue.name,
          subjectId: subject.id,
          subjectName: subject.name,
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          unitId: chapter.unitId,
        );
    }
  }

  TeachingPlannerSmartAssistantRecommendation? _firstRequiredGap(
    TeachingPlannerWorkspace workspace,
  ) {
    for (final classValue in workspace.activeClasses) {
      final subjects = workspace.activeSubjectsForClass(classValue.id);
      if (subjects.isEmpty) {
        return _createSubjectRecommendation(
          classId: classValue.id,
          className: classValue.name,
        );
      }
      for (final subject in subjects) {
        if (_chaptersForSubject(workspace, subject.id).isEmpty) {
          return _createChapterRecommendation(
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
          );
        }
      }
    }
    return null;
  }

  TeachingPlannerSmartAssistantRecommendation? _firstUsefulChapterStep(
    TeachingPlannerWorkspace workspace,
  ) {
    for (final classValue in workspace.activeClasses) {
      for (final subject in workspace.activeSubjectsForClass(classValue.id)) {
        for (final chapter in _chaptersForSubject(workspace, subject.id)) {
          final recommendation = _chapterRecommendation(
            workspace,
            classId: classValue.id,
            className: classValue.name,
            subjectId: subject.id,
            subjectName: subject.name,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            unitId: chapter.unitId,
          );
          if (recommendation != null) return recommendation;
        }
      }
    }
    return null;
  }

  TeachingPlannerSmartAssistantRecommendation? _chapterRecommendation(
    TeachingPlannerWorkspace workspace, {
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String chapterId,
    required String chapterTitle,
    String? unitId,
  }) {
    final hasLesson = workspace.activeLessonPlans.any(
      (lesson) => lesson.chapterId == chapterId,
    );
    if (!hasLesson) {
      return TeachingPlannerSmartAssistantRecommendation(
        action: TeachingPlannerSmartAssistantAction.planChapterLesson,
        classId: classId,
        subjectId: subjectId,
        unitId: unitId,
        chapterId: chapterId,
        suggestion: ContextualHelpSuggestion(
          id: 'planner.chapter.$chapterId.plan_lesson',
          screen: GuidedScreenContext.syllabus,
          title: 'Plan a lesson for $chapterTitle?',
          message:
              '$chapterTitle is ready in $className · $subjectName. I can open a lesson form with this chapter already selected.',
          primaryLabel: 'Plan lesson',
          minimumInactivity: idleDelay,
          suppressWhenRelatedGuideCompleted: false,
        ),
      );
    }

    if (workspace.activeResourcesForChapter(chapterId).isEmpty) {
      return TeachingPlannerSmartAssistantRecommendation(
        action: TeachingPlannerSmartAssistantAction.addChapterMaterial,
        classId: classId,
        subjectId: subjectId,
        unitId: unitId,
        chapterId: chapterId,
        suggestion: ContextualHelpSuggestion(
          id: 'planner.chapter.$chapterId.add_material',
          screen: GuidedScreenContext.syllabus,
          title: 'Keep teaching material with $chapterTitle?',
          message:
              'If useful, I can open the file picker for Word, PDF, images or other teaching files. This is optional.',
          primaryLabel: 'Add material',
          minimumInactivity: idleDelay,
          suppressWhenRelatedGuideCompleted: false,
        ),
      );
    }

    return null;
  }

  TeachingPlannerSmartAssistantRecommendation _createSyllabusRecommendation() {
    return const TeachingPlannerSmartAssistantRecommendation(
      action: TeachingPlannerSmartAssistantAction.createSyllabus,
      suggestion: ContextualHelpSuggestion(
        id: 'planner.syllabus.create_first',
        screen: GuidedScreenContext.syllabus,
        title: 'Start your first syllabus?',
        message:
            'I can open the simple class setup. You only need a class name to begin.',
        primaryLabel: 'Start syllabus',
        minimumInactivity: idleDelay,
        requiresIncompleteAction: true,
        suppressWhenRelatedGuideCompleted: false,
      ),
    );
  }

  TeachingPlannerSmartAssistantRecommendation _createSubjectRecommendation({
    required String classId,
    required String className,
  }) {
    return TeachingPlannerSmartAssistantRecommendation(
      action: TeachingPlannerSmartAssistantAction.createSubject,
      classId: classId,
      suggestion: ContextualHelpSuggestion(
        id: 'planner.class.$classId.add_subject',
        screen: GuidedScreenContext.syllabus,
        title: 'Add a subject to $className?',
        message:
            '$className does not have a subject yet. I can open the subject form for you.',
        primaryLabel: 'Add subject',
        minimumInactivity: idleDelay,
        requiresIncompleteAction: true,
        suppressWhenRelatedGuideCompleted: false,
      ),
    );
  }

  TeachingPlannerSmartAssistantRecommendation _createChapterRecommendation({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? unitId,
  }) {
    return TeachingPlannerSmartAssistantRecommendation(
      action: TeachingPlannerSmartAssistantAction.createChapter,
      classId: classId,
      subjectId: subjectId,
      unitId: unitId,
      suggestion: ContextualHelpSuggestion(
        id: unitId == null
            ? 'planner.subject.$subjectId.add_chapter'
            : 'planner.unit.$unitId.add_chapter',
        screen: GuidedScreenContext.syllabus,
        title: 'Add a chapter to $subjectName?',
        message:
            '$subjectName in $className has no chapter here yet. I can open the chapter form. Units and topics are optional.',
        primaryLabel: 'Add chapter',
        minimumInactivity: idleDelay,
        requiresIncompleteAction: true,
        suppressWhenRelatedGuideCompleted: false,
      ),
    );
  }

  List<PlannerChapter> _chaptersForSubject(
    TeachingPlannerWorkspace workspace,
    String subjectId,
  ) {
    final chapters = workspace.chapters
        .where((chapter) => chapter.subjectId == subjectId && !chapter.isArchived)
        .toList();
    chapters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return chapters;
  }
}
