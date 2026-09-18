import 'dart:math' as math;

import 'presentation_model.dart';

class ScheduledPresentationAnimation {
  final PresentationAnimationStep step;
  final Duration start;
  final Duration end;

  const ScheduledPresentationAnimation({
    required this.step,
    required this.start,
    required this.end,
  });
}

class PresentationAnimationGroup {
  final int index;
  final bool requiresClick;
  final List<ScheduledPresentationAnimation> animations;
  final Duration duration;

  const PresentationAnimationGroup({
    required this.index,
    required this.requiresClick,
    required this.animations,
    required this.duration,
  });
}

class PresentationAnimationTimeline {
  final List<PresentationAnimationGroup> groups;
  final int unsupportedStepCount;

  const PresentationAnimationTimeline(
    this.groups, {
    this.unsupportedStepCount = 0,
  });

  factory PresentationAnimationTimeline.compile(
    List<PresentationAnimationStep> steps,
  ) {
    final unsupportedCount = steps.where((step) => !step.supported).length;
    final playableSteps = steps.where((step) => step.supported).toList();
    if (playableSteps.isEmpty) {
      return PresentationAnimationTimeline(
        const [],
        unsupportedStepCount: unsupportedCount,
      );
    }

    final groups = <PresentationAnimationGroup>[];
    var current = <ScheduledPresentationAnimation>[];
    var currentRequiresClick = false;
    ScheduledPresentationAnimation? previous;

    void commit() {
      if (current.isEmpty) return;
      var durationMs = 0;
      for (final animation in current) {
        durationMs = math.max(durationMs, animation.end.inMilliseconds).toInt();
      }
      groups.add(
        PresentationAnimationGroup(
          index: groups.length,
          requiresClick: currentRequiresClick,
          animations: List.unmodifiable(current),
          duration: Duration(milliseconds: math.max(1, durationMs).toInt()),
        ),
      );
      current = <ScheduledPresentationAnimation>[];
      previous = null;
    }

    for (final step in playableSteps) {
      final startsNewClickGroup =
          step.trigger == PresentationAnimationTrigger.onClick;
      if (startsNewClickGroup && current.isNotEmpty) commit();

      if (current.isEmpty) {
        currentRequiresClick = startsNewClickGroup;
      }

      final delayMs = math.max(0, step.delay.inMilliseconds).toInt();
      final durationMs = math.max(1, step.duration.inMilliseconds).toInt();
      final startMs = switch (step.trigger) {
        PresentationAnimationTrigger.onClick => delayMs,
        PresentationAnimationTrigger.withPrevious =>
          (previous?.start.inMilliseconds ?? 0) + delayMs,
        PresentationAnimationTrigger.afterPrevious =>
          (previous?.end.inMilliseconds ?? 0) + delayMs,
      };
      final scheduled = ScheduledPresentationAnimation(
        step: step,
        start: Duration(milliseconds: startMs),
        end: Duration(milliseconds: startMs + durationMs),
      );
      current.add(scheduled);
      previous = scheduled;
    }
    commit();
    return PresentationAnimationTimeline(
      List.unmodifiable(groups),
      unsupportedStepCount: unsupportedCount,
    );
  }

  int get playableStepCount => groups.fold<int>(
    0,
    (count, group) => count + group.animations.length,
  );
}
