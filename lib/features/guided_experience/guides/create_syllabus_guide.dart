import '../domain/contextual_help.dart';
import '../domain/guide_definition.dart';
import '../domain/guide_ids.dart';

abstract final class CreateSyllabusGuideSteps {
  static const openTeachingPlanner = GuideStepId('create-syllabus-open-planner');
  static const openClassSetup = GuideStepId('create-syllabus-open-class');
  static const saveClass = GuideStepId('create-syllabus-save-class');
  static const openSyllabus = GuideStepId('create-syllabus-open-manager');
  static const openCreateSyllabus = GuideStepId('create-syllabus-open-root');
  static const saveCreateSyllabus = GuideStepId('create-syllabus-save-root');
  static const openSubject = GuideStepId('create-syllabus-open-subject');
  static const saveSubject = GuideStepId('create-syllabus-save-subject');
  static const openChapter = GuideStepId('create-syllabus-open-chapter');
  static const saveChapter = GuideStepId('create-syllabus-save-chapter');
  static const optionalStructure = GuideStepId('create-syllabus-optional-structure');
  static const manageSyllabus = GuideStepId('create-syllabus-manage');
  static const finishSetup = GuideStepId('create-syllabus-finish-setup');
}

abstract final class CreateSyllabusGuideTargets {
  static const homeTeachingPlanner = GuideTargetId('create-syllabus-home-teaching-planner');
  static const openClassSetup = GuideTargetId('create-syllabus-open-class');
  static const classForm = GuideTargetId('create-syllabus-class-form');
  static const openSyllabus = GuideTargetId('create-syllabus-open-manager');
  static const openCreateSyllabus = GuideTargetId('create-syllabus-open-root');
  static const syllabusForm = GuideTargetId('create-syllabus-root-form');
  static const openSubject = GuideTargetId('create-syllabus-open-subject');
  static const subjectForm = GuideTargetId('create-syllabus-subject-form');
  static const openChapter = GuideTargetId('create-syllabus-open-chapter');
  static const chapterForm = GuideTargetId('create-syllabus-chapter-form');
  static const optionalTopic = GuideTargetId('create-syllabus-optional-topic');
  static const manageSyllabus = GuideTargetId('create-syllabus-manage-panel');
  static const continueSetup = GuideTargetId('create-syllabus-continue-setup');
}

final createSyllabusGuideDefinition = GuideDefinition(
  id: GuideId.createSyllabus,
  version: 1,
  steps: const <GuideStep>[
    GuideStep(
      id: CreateSyllabusGuideSteps.openTeachingPlanner,
      title: 'Open Teaching Planner',
      message: 'Create and manage your syllabus from the real Teaching Planner workspace.',
      targetId: CreateSyllabusGuideTargets.homeTeachingPlanner,
      advanceMode: GuideAdvanceMode.targetActivated,
      allowBack: false,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.openClassSetup,
      title: 'Start with your class',
      message: 'A syllabus belongs to a class. Create one only when this workspace does not already have a class.',
      targetId: CreateSyllabusGuideTargets.openClassSetup,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.saveClass,
      title: 'Enter the class details',
      message: 'Enter the real class name. Academic year is optional. The guide continues only after the existing save succeeds.',
      targetId: CreateSyllabusGuideTargets.classForm,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.openSyllabus,
      title: 'Open Syllabus',
      message: 'Open the real Syllabus workspace for this class.',
      targetId: CreateSyllabusGuideTargets.openSyllabus,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.openCreateSyllabus,
      title: 'Create a syllabus when needed',
      message: 'If this Syllabus workspace has no class yet, start here. Existing classes are reused instead of duplicated.',
      targetId: CreateSyllabusGuideTargets.openCreateSyllabus,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.saveCreateSyllabus,
      title: 'Name the syllabus class',
      message: 'Use the class / syllabus name and optional academic year already supported by Teaching Planner, then create it.',
      targetId: CreateSyllabusGuideTargets.syllabusForm,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.openSubject,
      title: 'Add the subject',
      message: 'Open the real Add subject form inside this class.',
      targetId: CreateSyllabusGuideTargets.openSubject,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.saveSubject,
      title: 'Save the subject',
      message: 'Enter the real subject name. Subject code is optional. Failed or cancelled saves do not advance the guide.',
      targetId: CreateSyllabusGuideTargets.subjectForm,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.openChapter,
      title: 'Add a chapter',
      message: 'A usable syllabus needs at least one chapter. A chapter can live directly under the subject; a unit is optional.',
      targetId: CreateSyllabusGuideTargets.openChapter,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.saveChapter,
      title: 'Save the chapter',
      message: 'Name the chapter and optionally set periods, priority or a unit. Existing validation must succeed before the guide continues.',
      targetId: CreateSyllabusGuideTargets.chapterForm,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.optionalStructure,
      title: 'Topics and units are optional',
      message: 'Topics and units are optional. Break this chapter into topics when useful, or add units from the subject page to group chapters; neither is required to finish setup.',
      targetId: CreateSyllabusGuideTargets.optionalTopic,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.manageSyllabus,
      title: 'Manage the real syllabus',
      message: 'This detail area is where you select, edit, reorder and extend the real class → subject → chapter → topic structure.',
      targetId: CreateSyllabusGuideTargets.manageSyllabus,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreateSyllabusGuideSteps.finishSetup,
      title: 'Syllabus is ready',
      message: 'Subject + chapter is the existing minimum for a usable syllabus. During first-time setup, Continue setup moves to the next real Teaching Planner step.',
      targetId: CreateSyllabusGuideTargets.continueSetup,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
  ],
);

const createSyllabusContextualSuggestion = ContextualHelpSuggestion(
  id: 'create-syllabus-workflow-help',
  screen: GuidedScreenContext.syllabus,
  title: 'Need help setting up your syllabus?',
  message: 'I can point to where you add the subject and chapter. Topics are optional.',
  minimumInactivity: Duration(minutes: 1),
  requiresIncompleteAction: true,
  requiresFirstTimeUse: true,
);
