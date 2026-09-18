import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guide_definition.dart';
import '../domain/guide_ids.dart';
import '../domain/guide_progress.dart';
import '../domain/guide_progress_repository.dart';
import '../domain/guide_session.dart';
import '../domain/guided_experience_state.dart';

class GuidedExperienceController extends StateNotifier<GuidedExperienceState> {
  GuidedExperienceController(this._repository) : super(GuidedExperienceState());

  final GuideProgressRepository _repository;
  Future<void>? _loadOperation;

  Future<void> load() {
    final existing = _loadOperation;
    if (existing != null) return existing;

    final operation = _load();
    _loadOperation = operation;
    return operation.whenComplete(() {
      if (identical(_loadOperation, operation)) {
        _loadOperation = null;
      }
    });
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final progress = await _repository.loadAll();
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        progressByGuide: progress,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> replayGuide(
    GuideDefinition definition, {
    GuideStepId? startAtStepId,
  }) {
    return startGuide(
      definition,
      mode: GuideSessionMode.replay,
      restart: true,
      startAtStepId: startAtStepId,
    );
  }

  Future<void> startGuide(
    GuideDefinition definition, {
    GuideSessionMode mode = GuideSessionMode.liveGuide,
    bool restart = false,
    GuideStepId? startAtStepId,
  }) async {
    await _ensureLoaded();

    final existing = state.progressFor(definition.id);
    var startIndex = 0;
    if (startAtStepId != null) {
      final requestedIndex = definition.stepIds.indexOf(startAtStepId);
      if (requestedIndex < 0) {
        throw ArgumentError.value(
          startAtStepId,
          'startAtStepId',
          'The requested step is not part of this guide definition.',
        );
      }
      startIndex = requestedIndex;
    } else if (!restart &&
        mode != GuideSessionMode.replay &&
        existing?.status == GuideProgressStatus.inProgress &&
        existing?.definitionVersion == definition.version &&
        existing?.currentStepId != null) {
      final index = definition.stepIds.indexOf(existing!.currentStepId!);
      if (index >= 0) startIndex = index;
    }

    final session = GuideSession(
      guideId: definition.id,
      definitionVersion: definition.version,
      stepIds: definition.stepIds,
      currentStepIndex: startIndex,
      mode: mode,
    );

    state = state.copyWith(
      activeSession: session,
      activeDefinition: definition,
      clearError: true,
    );

    if (session.persistsProgress) {
      final nextProgress = GuideProgress(
        guideId: definition.id,
        definitionVersion: definition.version,
        status: GuideProgressStatus.inProgress,
        currentStepId: session.currentStepId,
        completedStepIds: restart
            ? const <GuideStepId>{}
            : (existing?.completedStepIds ?? const <GuideStepId>{}),
      );
      await _persist(nextProgress);
    }
  }

  Future<void> advance() async {
    final session = state.activeSession;
    if (session == null) return;

    if (session.isLastStep) {
      await complete();
      return;
    }

    final nextSession = session.moveTo(session.currentStepIndex + 1);
    state = state.copyWith(activeSession: nextSession, clearError: true);

    if (!session.persistsProgress) return;

    final existing = _progressForSession(session);
    final completedSteps = <GuideStepId>{
      ...existing.completedStepIds,
      session.currentStepId,
    };
    await _persist(
      existing.copyWith(
        status: GuideProgressStatus.inProgress,
        currentStepId: nextSession.currentStepId,
        completedStepIds: completedSteps,
        clearCompletedAt: true,
      ),
    );
  }

  Future<void> notifyConditionSatisfied(GuideStepId stepId) async {
    final session = state.activeSession;
    final step = state.activeStep;
    if (session == null ||
        step == null ||
        step.id != stepId ||
        step.advanceMode != GuideAdvanceMode.conditionSatisfied) {
      return;
    }

    await advance();
  }

  Future<void> goBack() async {
    final session = state.activeSession;
    if (session == null || session.isFirstStep) return;

    final previousSession = session.moveTo(session.currentStepIndex - 1);
    state = state.copyWith(activeSession: previousSession, clearError: true);

    if (!session.persistsProgress) return;
    final existing = _progressForSession(session);
    await _persist(
      existing.copyWith(
        status: GuideProgressStatus.inProgress,
        currentStepId: previousSession.currentStepId,
        clearCompletedAt: true,
      ),
    );
  }

  Future<void> skip() async {
    final session = state.activeSession;
    if (session == null) return;

    state = state.copyWith(
      activeSession: null,
      activeDefinition: null,
      clearError: true,
    );
    if (!session.persistsProgress) return;

    final existing = _progressForSession(session);
    await _persist(
      existing.copyWith(
        status: GuideProgressStatus.skipped,
        currentStepId: session.currentStepId,
        clearCompletedAt: true,
      ),
    );
  }

  Future<void> stop() async {
    final session = state.activeSession;
    if (session == null) return;

    state = state.copyWith(
      activeSession: null,
      activeDefinition: null,
      clearError: true,
    );
    if (!session.persistsProgress) return;

    final existing = _progressForSession(session);
    await _persist(
      existing.copyWith(
        status: GuideProgressStatus.inProgress,
        currentStepId: session.currentStepId,
        clearCompletedAt: true,
      ),
    );
  }

  Future<void> complete() async {
    final session = state.activeSession;
    if (session == null) return;

    state = state.copyWith(
      activeSession: null,
      activeDefinition: null,
      clearError: true,
    );
    if (!session.persistsProgress) return;

    final existing = _progressForSession(session);
    final completedSteps = <GuideStepId>{
      ...existing.completedStepIds,
      ...session.stepIds,
    };
    await _persist(
      existing.copyWith(
        status: GuideProgressStatus.completed,
        clearCurrentStep: true,
        completedStepIds: completedSteps,
        completedAt: DateTime.now(),
      ),
    );
  }

  GuideProgress _progressForSession(GuideSession session) {
    return state.progressFor(session.guideId) ??
        GuideProgress(
          guideId: session.guideId,
          definitionVersion: session.definitionVersion,
          status: GuideProgressStatus.inProgress,
          currentStepId: session.currentStepId,
        );
  }

  Future<void> _persist(GuideProgress progress) async {
    final nextProgress = <GuideId, GuideProgress>{
      ...state.progressByGuide,
      progress.guideId: progress,
    };
    state = state.copyWith(progressByGuide: nextProgress, clearError: true);
    try {
      await _repository.save(progress);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> _ensureLoaded() async {
    if (state.isInitialized) return;
    await load();
  }
}
