import 'package:flutter/foundation.dart';

import 'guide_ids.dart';

enum GuideAdvanceMode {
  manual,
  targetActivated,
  conditionSatisfied,
}

@immutable
class GuideStep {
  const GuideStep({
    required this.id,
    required this.title,
    required this.message,
    this.targetId,
    this.advanceMode = GuideAdvanceMode.manual,
    this.allowBack = true,
    this.allowSkip = true,
    this.allowOutsideInteraction = false,
  });

  final GuideStepId id;
  final String title;
  final String message;
  final GuideTargetId? targetId;
  final GuideAdvanceMode advanceMode;
  final bool allowBack;
  final bool allowSkip;

  /// When true, the spotlight remains visible but the rest of the application
  /// stays interactive. Use this only for informational/optional steps where
  /// the user may need to inspect nearby real controls without advancing.
  final bool allowOutsideInteraction;
}

@immutable
class GuideDefinition {
  GuideDefinition({
    required this.id,
    required this.version,
    required List<GuideStep> steps,
  }) : steps = List<GuideStep>.unmodifiable(steps) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'Must be at least 1.');
    }
    if (steps.isEmpty) {
      throw ArgumentError.value(steps, 'steps', 'A guide needs at least one step.');
    }

    final uniqueIds = steps.map((step) => step.id).toSet();
    if (uniqueIds.length != steps.length) {
      throw ArgumentError('Guide step ids must be unique within a guide.');
    }
  }

  final GuideId id;
  final int version;
  final List<GuideStep> steps;

  List<GuideStepId> get stepIds =>
      List<GuideStepId>.unmodifiable(steps.map((step) => step.id));
}
