import '../domain/contextual_help.dart';
import '../domain/guide_definition.dart';
import '../domain/guide_ids.dart';

abstract final class CreatePaperGuideSteps {
  static const openCreatePaper = GuideStepId('create-paper-open');
  static const openPaperSetup = GuideStepId('create-paper-open-setup');
  static const reviewPaperSetup = GuideStepId('create-paper-review-setup');
  static const savePaperSetup = GuideStepId('create-paper-save-setup');
  static const writeFirstQuestion = GuideStepId('create-paper-first-question');
  static const typeQuestion = GuideStepId('create-paper-type-question');
  static const authoringTools = GuideStepId('create-paper-authoring-tools');
  static const saveQuestion = GuideStepId('create-paper-save-question');
  static const questionBank = GuideStepId('create-paper-question-bank');
  static const openPreview = GuideStepId('create-paper-open-preview');
  static const reviewPreview = GuideStepId('create-paper-review-preview');
  static const returnFromPreview = GuideStepId('create-paper-return-preview');
  static const outputPaper = GuideStepId('create-paper-output');
}

abstract final class CreatePaperGuideTargets {
  static const homeCreatePaper = GuideTargetId('create-paper-home-card');
  static const paperSetupEntry = GuideTargetId('create-paper-setup-entry');
  static const paperSetupEssentials = GuideTargetId('create-paper-setup-essentials');
  static const paperSetupSave = GuideTargetId('create-paper-setup-save');
  static const writeFirstQuestion = GuideTargetId('create-paper-write-first-question');
  static const questionEditor = GuideTargetId('create-paper-question-editor');
  static const questionTools = GuideTargetId('create-paper-question-tools');
  static const questionSave = GuideTargetId('create-paper-question-save');
  static const questionBank = GuideTargetId('create-paper-question-bank');
  static const preview = GuideTargetId('create-paper-preview');
  static const previewDocument = GuideTargetId('create-paper-preview-document');
  static const previewBack = GuideTargetId('create-paper-preview-back');
  static const outputOptions = GuideTargetId('create-paper-output-options');
}

final createPaperGuideDefinition = GuideDefinition(
  id: GuideId.createPaper,
  version: 1,
  steps: const <GuideStep>[
    GuideStep(
      id: CreatePaperGuideSteps.openCreatePaper,
      title: 'Start Create Paper',
      message: 'Open the real Create Paper workspace from here.',
      targetId: CreatePaperGuideTargets.homeCreatePaper,
      advanceMode: GuideAdvanceMode.targetActivated,
      allowBack: false,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.openPaperSetup,
      title: 'Set up the paper',
      message: 'Open Paper Setup before writing questions so the paper heading is ready.',
      targetId: CreatePaperGuideTargets.paperSetupEntry,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.reviewPaperSetup,
      title: 'Name the paper',
      message: 'Set the school/institution and paper title here if you need them, then choose Next. Subject, class, duration and marks stay available on the save step.',
      targetId: CreatePaperGuideTargets.paperSetupEssentials,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.savePaperSetup,
      title: 'Review and save Paper Setup',
      message: 'Add any school, subject, class, duration or marks details you need, then use the highlighted Save button. Existing validation must accept the setup before the guide continues.',
      targetId: CreatePaperGuideTargets.paperSetupSave,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.writeFirstQuestion,
      title: 'Write the first question',
      message: 'Open the real question editor. EduSheet creates the first section automatically when needed.',
      targetId: CreatePaperGuideTargets.writeFirstQuestion,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.typeQuestion,
      title: 'Type the question',
      message: 'Type the question exactly as students should read it. This step advances when real question text is entered.',
      targetId: CreatePaperGuideTargets.questionEditor,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.authoringTools,
      title: 'Math, Geometry and more',
      message: 'Use Add for extra content, Math for equations, or Geometry for diagrams. These tools insert at the current question cursor.',
      targetId: CreatePaperGuideTargets.questionTools,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.saveQuestion,
      title: 'Save the question',
      message: 'Save the real question. Invalid or failed saves do not advance the guide.',
      targetId: CreatePaperGuideTargets.questionSave,
      advanceMode: GuideAdvanceMode.conditionSatisfied,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.questionBank,
      title: 'Reuse Question Bank content',
      message: 'Question Bank can add reusable questions to this section. On compact screens, open Add question first and choose Question Bank.',
      targetId: CreatePaperGuideTargets.questionBank,
      allowOutsideInteraction: true,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.openPreview,
      title: 'Preview the paper',
      message: 'Open the real paper preview to check layout and question flow before export.',
      targetId: CreatePaperGuideTargets.preview,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.reviewPreview,
      title: 'Review the final layout',
      message: 'This preview uses the same resolved paper structure used for export. Scroll through it and check the result.',
      targetId: CreatePaperGuideTargets.previewDocument,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.returnFromPreview,
      title: 'Return to the editor',
      message: 'Go back to Create Paper for the final output actions.',
      targetId: CreatePaperGuideTargets.previewBack,
      advanceMode: GuideAdvanceMode.targetActivated,
    ),
    GuideStep(
      id: CreatePaperGuideSteps.outputPaper,
      title: 'Export or save',
      message: 'Use PDF or Word to generate the final paper. Save keeps the editable paper in EduSheet. Export only happens when you explicitly choose it.',
      targetId: CreatePaperGuideTargets.outputOptions,
      allowOutsideInteraction: true,
    ),
  ],
);

const createPaperContextualSuggestion = ContextualHelpSuggestion(
  id: 'create-paper-first-workflow-help',
  screen: GuidedScreenContext.createPaper,
  title: 'Need help creating a paper?',
  message: 'I can point to the next button and help you make your first question, preview the paper, and save or export it.',
  minimumInactivity: Duration(minutes: 1),
  requiresIncompleteAction: true,
  requiresFirstTimeUse: true,
);
