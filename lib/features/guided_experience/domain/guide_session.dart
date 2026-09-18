import 'package:flutter/foundation.dart';

import 'guide_ids.dart';

enum GuideSessionMode { onboarding, liveGuide, demo, replay }

@immutable
class GuideSession {
  GuideSession({
    required this.guideId,
    required this.definitionVersion,
    required List<GuideStepId> stepIds,
    required this.currentStepIndex,
    required this.mode,
  }) : stepIds = List<GuideStepId>.unmodifiable(stepIds) {
    if (stepIds.isEmpty) {
      throw ArgumentError.value(stepIds, 'stepIds', 'Session needs steps.');
    }
    if (currentStepIndex < 0 || currentStepIndex >= stepIds.length) {
      throw RangeError.range(
        currentStepIndex,
        0,
        stepIds.length - 1,
        'currentStepIndex',
      );
    }
  }

  final GuideId guideId;
  final int definitionVersion;
  final List<GuideStepId> stepIds;
  final int currentStepIndex;
  final GuideSessionMode mode;

  GuideStepId get currentStepId => stepIds[currentStepIndex];
  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep => currentStepIndex == stepIds.length - 1;
  bool get persistsProgress =>
      mode != GuideSessionMode.replay && mode != GuideSessionMode.demo;

  GuideSession moveTo(int index) {
    return GuideSession(
      guideId: guideId,
      definitionVersion: definitionVersion,
      stepIds: stepIds,
      currentStepIndex: index,
      mode: mode,
    );
  }
}
