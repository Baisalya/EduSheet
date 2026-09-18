import 'package:flutter/foundation.dart';

import 'guide_ids.dart';

enum GuideProgressStatus { notStarted, inProgress, completed, skipped }

@immutable
class GuideProgress {
  GuideProgress({
    required this.guideId,
    this.definitionVersion = 1,
    this.status = GuideProgressStatus.notStarted,
    this.currentStepId,
    Set<GuideStepId> completedStepIds = const <GuideStepId>{},
    this.completedAt,
  }) : completedStepIds = Set<GuideStepId>.unmodifiable(completedStepIds);

  final GuideId guideId;
  final int definitionVersion;
  final GuideProgressStatus status;
  final GuideStepId? currentStepId;
  final Set<GuideStepId> completedStepIds;
  final DateTime? completedAt;

  GuideProgress copyWith({
    int? definitionVersion,
    GuideProgressStatus? status,
    GuideStepId? currentStepId,
    bool clearCurrentStep = false,
    Set<GuideStepId>? completedStepIds,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return GuideProgress(
      guideId: guideId,
      definitionVersion: definitionVersion ?? this.definitionVersion,
      status: status ?? this.status,
      currentStepId: clearCurrentStep
          ? null
          : (currentStepId ?? this.currentStepId),
      completedStepIds: completedStepIds ?? this.completedStepIds,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'guideId': guideId.value,
      'definitionVersion': definitionVersion,
      'status': status.name,
      'currentStepId': currentStepId?.value,
      'completedStepIds': completedStepIds.map((id) => id.value).toList(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory GuideProgress.fromJson(Map<String, Object?> json) {
    final guideIdValue = json['guideId'];
    if (guideIdValue is! String || guideIdValue.isEmpty) {
      throw const FormatException('Missing guideId.');
    }

    final rawVersion = json['definitionVersion'];
    final version = rawVersion is int && rawVersion > 0 ? rawVersion : 1;

    final rawStatus = json['status'];
    final status = GuideProgressStatus.values.firstWhere(
      (candidate) => candidate.name == rawStatus,
      orElse: () => GuideProgressStatus.notStarted,
    );

    final rawCurrentStep = json['currentStepId'];
    final currentStep = rawCurrentStep is String && rawCurrentStep.isNotEmpty
        ? GuideStepId(rawCurrentStep)
        : null;

    final rawCompletedSteps = json['completedStepIds'];
    final completedSteps = <GuideStepId>{};
    if (rawCompletedSteps is List) {
      for (final value in rawCompletedSteps) {
        if (value is String && value.isNotEmpty) {
          completedSteps.add(GuideStepId(value));
        }
      }
    }

    DateTime? completedAt;
    final rawCompletedAt = json['completedAt'];
    if (rawCompletedAt is String) {
      completedAt = DateTime.tryParse(rawCompletedAt)?.toLocal();
    }

    return GuideProgress(
      guideId: GuideId(guideIdValue),
      definitionVersion: version,
      status: status,
      currentStepId: currentStep,
      completedStepIds: completedSteps,
      completedAt: completedAt,
    );
  }
}
