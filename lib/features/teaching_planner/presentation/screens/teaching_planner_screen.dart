import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../guided_experience/application/guided_experience_providers.dart';
import '../../../guided_experience/domain/contextual_help.dart';
import '../../../guided_experience/domain/guide_ids.dart';
import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/contextual_help_prompt.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../models/teaching_planner_setup_model.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/create_planner_class_sheet.dart';
import '../widgets/teaching_planner_dashboard.dart';
import '../widgets/teaching_planner_first_run_setup.dart';
import '../widgets/teaching_planner_page_shell.dart';
import 'lesson_detail_screen.dart';

class TeachingPlannerScreen extends ConsumerStatefulWidget {
  const TeachingPlannerScreen({super.key});

  @override
  ConsumerState<TeachingPlannerScreen> createState() =>
      _TeachingPlannerScreenState();
}

class _TeachingPlannerScreenState extends ConsumerState<TeachingPlannerScreen> {
  bool _skipSetupForSession = false;
  bool _guideReconcileScheduled = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final setup = TeachingPlannerSetupModel.fromWorkspace(state.workspace);
    final guidedExperience = ref.watch(guidedExperienceControllerProvider);
    final activeSyllabusGuide =
        guidedExperience.activeSession?.guideId == GuideId.createSyllabus;
    final activeSyllabusStep = activeSyllabusGuide
        ? guidedExperience.activeStep?.id
        : null;

    _scheduleCreateSyllabusGuideReconciliation(activeStep: activeSyllabusStep);

    final showSetup = !setup.isComplete && !_skipSetupForSession;

    void openDestination(TeachingPlannerDestination destination) {
      TeachingPlannerNavigation.open(context, destination);
    }

    final dashboard = TeachingPlannerDashboard(
      state: state,
      capabilities: capabilities,
      onOpenDestination: openDestination,
      onOpenLesson: _openLessonDetail,
      onCreateClass: _createClass,
      onRetry: () => ref.read(teachingPlannerProvider.notifier).load(),
      onRefresh: () => ref.read(teachingPlannerProvider.notifier).load(),
    );

    final content = showSetup
        ? TeachingPlannerFirstRunSetup(
            model: setup,
            isLoading: state.isLoading,
            onCreateClass: _createClass,
            onOpenSyllabus: () => _openGuidedSyllabus(setup),
            onPlanFirstLesson: () => _openGuidedFirstLesson(setup),
            onSkip: () => setState(() => _skipSetupForSession = true),
            errorMessage: state.errorMessage,
            onRetry: () => ref.read(teachingPlannerProvider.notifier).load(),
          )
        : setup.isComplete
        ? dashboard
        : ContextualHelpOffer(
            suggestion: _suggestionFor(setup, state.workspace),
            signals: const ContextualHelpSignals(
              currentScreen: GuidedScreenContext.teachingPlanner,
              hasIncompleteAction: true,
            ),
            onShowMe: () => _runSmartSetupAction(setup),
            child: dashboard,
          );

    return TeachingPlannerPageShell(
      title: '',
      body: content,
      showGlobalNavigation: !showSetup,
      automaticallyImplyLeading: false,
      navigationBarKey: const ValueKey('planner-home-navigation-bar'),
      navigationRailKey: const ValueKey('planner-home-navigation-rail'),
      showAppBar: false,
    );
  }

  void _scheduleCreateSyllabusGuideReconciliation({
    required GuideStepId? activeStep,
  }) {
    if (_guideReconcileScheduled || activeStep == null) return;
    _guideReconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guideReconcileScheduled = false;
      if (!mounted) return;

      final guide = ref.read(guidedExperienceControllerProvider);
      if (guide.activeSession?.guideId != GuideId.createSyllabus) return;
      final currentStep = guide.activeStep?.id;
      final currentSetup = TeachingPlannerSetupModel.fromWorkspace(
        ref.read(teachingPlannerProvider).workspace,
      );
      final controller = ref.read(guidedExperienceControllerProvider.notifier);

      if (currentStep == CreateSyllabusGuideSteps.openClassSetup &&
          currentSetup.stage != TeachingPlannerSetupStage.classSetup) {
        unawaited(controller.advance());
        return;
      }
      if (currentStep == CreateSyllabusGuideSteps.saveClass &&
          currentSetup.stage != TeachingPlannerSetupStage.classSetup) {
        unawaited(
          controller.notifyConditionSatisfied(
            CreateSyllabusGuideSteps.saveClass,
          ),
        );
        return;
      }
      if (currentStep == CreateSyllabusGuideSteps.openSyllabus &&
          currentSetup.stage == TeachingPlannerSetupStage.firstLesson &&
          !_skipSetupForSession) {
        setState(() => _skipSetupForSession = true);
      }
    });
  }

  ContextualHelpSuggestion _suggestionFor(
    TeachingPlannerSetupModel setup,
    TeachingPlannerWorkspace workspace,
  ) {
    final focusClass = setup.focusClassId == null
        ? null
        : workspace.classById(setup.focusClassId!);
    final className = focusClass?.name;

    return switch (setup.stage) {
      TeachingPlannerSetupStage.classSetup => const ContextualHelpSuggestion(
        id: 'teaching_planner.finish_class_setup',
        screen: GuidedScreenContext.teachingPlanner,
        title: 'Add your first class?',
        message: 'I can open the class form. A class name is enough to begin.',
        primaryLabel: 'Add class',
        minimumInactivity: Duration(minutes: 1),
        requiresIncompleteAction: true,
      ),
      TeachingPlannerSetupStage.syllabus => ContextualHelpSuggestion(
        id: 'teaching_planner.finish_syllabus.${setup.focusClassId ?? 'class'}',
        screen: GuidedScreenContext.teachingPlanner,
        title: className == null
            ? 'Continue your syllabus?'
            : 'Continue $className syllabus?',
        message: className == null
            ? 'This syllabus still needs a subject and chapter. I can open it for you.'
            : '$className still needs a subject and chapter before lesson planning. I can open the syllabus at this class.',
        primaryLabel: 'Open syllabus',
        minimumInactivity: const Duration(minutes: 1),
        requiresIncompleteAction: true,
      ),
      TeachingPlannerSetupStage.firstLesson => ContextualHelpSuggestion(
        id: 'teaching_planner.finish_first_lesson.${setup.focusClassId ?? 'class'}',
        screen: GuidedScreenContext.teachingPlanner,
        title: className == null
            ? 'Ready to plan your first lesson?'
            : 'Plan the first $className lesson?',
        message:
            'The syllabus is ready. I can open a lesson form with the class already selected.',
        primaryLabel: 'Plan lesson',
        minimumInactivity: const Duration(minutes: 1),
        requiresIncompleteAction: true,
      ),
      TeachingPlannerSetupStage.complete => const ContextualHelpSuggestion(
        id: 'teaching_planner.complete',
        screen: GuidedScreenContext.teachingPlanner,
        title: 'Teaching Planner is ready',
        message: 'Your setup is already complete.',
        requiresIncompleteAction: true,
      ),
    };
  }

  void _runSmartSetupAction(TeachingPlannerSetupModel setup) {
    switch (setup.stage) {
      case TeachingPlannerSetupStage.classSetup:
        unawaited(_createClass());
        return;
      case TeachingPlannerSetupStage.syllabus:
        unawaited(_openGuidedSyllabus(setup));
        return;
      case TeachingPlannerSetupStage.firstLesson:
        unawaited(_openGuidedFirstLesson(setup));
        return;
      case TeachingPlannerSetupStage.complete:
        return;
    }
  }

  void _openLessonDetail(String lessonId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonDetailScreen(lessonId: lessonId),
      ),
    );
  }

  Future<void> _createClass() async {
    final result = await showCreatePlannerClassSheet(context);
    if (result == null || !mounted) return;

    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .createClass(name: result.name, academicYear: result.academicYear);
    if (!mounted) return;
    if (saved) {
      await ref
          .read(guidedExperienceControllerProvider.notifier)
          .notifyConditionSatisfied(CreateSyllabusGuideSteps.saveClass);
      return;
    }

    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openGuidedSyllabus(TeachingPlannerSetupModel setup) async {
    await TeachingPlannerNavigation.openSyllabus(
      context,
      initialClassId: setup.focusClassId,
    );
  }

  Future<void> _openGuidedFirstLesson(TeachingPlannerSetupModel setup) async {
    await TeachingPlannerNavigation.openLessons(
      context,
      createImmediately: true,
      returnAfterCreate: true,
      initialClassId: setup.focusClassId,
    );
  }
}
