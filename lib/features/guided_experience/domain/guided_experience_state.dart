import 'package:flutter/foundation.dart';

import 'guide_definition.dart';
import 'guide_ids.dart';
import 'guide_progress.dart';
import 'guide_session.dart';

const _activeSessionNotProvided = Object();
const _activeDefinitionNotProvided = Object();

@immutable
class GuidedExperienceState {
  GuidedExperienceState({
    this.isInitialized = false,
    this.isLoading = false,
    Map<GuideId, GuideProgress> progressByGuide =
        const <GuideId, GuideProgress>{},
    this.activeSession,
    this.activeDefinition,
    this.errorMessage,
  }) : progressByGuide = Map<GuideId, GuideProgress>.unmodifiable(
         progressByGuide,
       );

  final bool isInitialized;
  final bool isLoading;
  final Map<GuideId, GuideProgress> progressByGuide;
  final GuideSession? activeSession;
  final GuideDefinition? activeDefinition;
  final String? errorMessage;

  GuideProgress? progressFor(GuideId guideId) => progressByGuide[guideId];

  GuideStep? get activeStep {
    final session = activeSession;
    final definition = activeDefinition;
    if (session == null || definition == null) return null;
    if (session.guideId != definition.id ||
        session.definitionVersion != definition.version ||
        session.currentStepIndex >= definition.steps.length) {
      return null;
    }
    final step = definition.steps[session.currentStepIndex];
    if (step.id != session.currentStepId) return null;
    return step;
  }

  GuidedExperienceState copyWith({
    bool? isInitialized,
    bool? isLoading,
    Map<GuideId, GuideProgress>? progressByGuide,
    Object? activeSession = _activeSessionNotProvided,
    Object? activeDefinition = _activeDefinitionNotProvided,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GuidedExperienceState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      progressByGuide: progressByGuide ?? this.progressByGuide,
      activeSession: identical(activeSession, _activeSessionNotProvided)
          ? this.activeSession
          : activeSession as GuideSession?,
      activeDefinition: identical(activeDefinition, _activeDefinitionNotProvided)
          ? this.activeDefinition
          : activeDefinition as GuideDefinition?,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
