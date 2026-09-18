import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guided_experience_providers.dart';
import '../../application/smart_work_activity_controller.dart';
import '../../domain/contextual_help.dart';
import 'smart_work_robot.dart';

/// Context-aware Smart Work Assistant offer.
///
/// The offer never blocks the working surface. In production it is driven by
/// [SmartWorkActivityHost]'s app-wide inactivity clock, while tests can still
/// use a zero-duration suggestion for immediate deterministic rendering.
class ContextualHelpOffer extends ConsumerStatefulWidget {
  const ContextualHelpOffer({
    super.key,
    required this.child,
    required this.suggestion,
    required this.signals,
    required this.onShowMe,
  });

  final Widget child;
  final ContextualHelpSuggestion suggestion;
  final ContextualHelpSignals signals;
  final VoidCallback onShowMe;

  @override
  ConsumerState<ContextualHelpOffer> createState() =>
      _ContextualHelpOfferState();
}

class _ContextualHelpOfferState extends ConsumerState<ContextualHelpOffer> {
  Timer? _inactivityTimer;
  bool _visible = false;
  bool? _lastRouteCurrent;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleEvaluation();
    });
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    if (_visible && _hasActiveTextInput()) {
      setState(() => _visible = false);
    }
    _scheduleEvaluation();
  }

  @override
  void didUpdateWidget(covariant ContextualHelpOffer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestion.id != widget.suggestion.id ||
        oldWidget.suggestion.minimumInactivity !=
            widget.suggestion.minimumInactivity ||
        oldWidget.signals != widget.signals) {
      _visible = false;
      _scheduleEvaluation();
    }
  }

  void _scheduleEvaluation() {
    _inactivityTimer?.cancel();
    if (!mounted) return;

    final activity = ref.read(smartWorkActivityControllerProvider);
    if (!activity.isForeground) return;

    final inactivity = activity.inactivityAt(DateTime.now());
    final minimum = widget.suggestion.minimumInactivity;
    final remaining = minimum - inactivity;
    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
      return;
    }
    _inactivityTimer = Timer(remaining, _evaluate);
  }

  void _evaluate() {
    if (!mounted || _visible) return;
    final helpState = ref.read(contextualHelpControllerProvider);
    final helpController = ref.read(contextualHelpControllerProvider.notifier);
    final guideState = ref.read(guidedExperienceControllerProvider);
    final policy = ref.read(contextualHelpPolicyProvider);
    final activity = ref.read(smartWorkActivityControllerProvider);
    final trackedInactivity = activity.inactivityAt(DateTime.now());
    final effectiveInactivity = trackedInactivity > widget.signals.inactivity
        ? trackedInactivity
        : widget.signals.inactivity;
    final signals = ContextualHelpSignals(
      currentScreen: widget.signals.currentScreen,
      hasIncompleteAction: widget.signals.hasIncompleteAction,
      isFirstTimeUse: widget.signals.isFirstTimeUse,
      inactivity: effectiveInactivity,
      hasActiveGuide:
          widget.signals.hasActiveGuide || guideState.activeSession != null,
      hasBlockingModal: widget.signals.hasBlockingModal ||
          !(ModalRoute.of(context)?.isCurrent ?? true),
      isTextInputActive:
          widget.signals.isTextInputActive || _hasActiveTextInput(),
      relatedGuideCompleted: widget.signals.relatedGuideCompleted,
      isAppForeground: activity.isForeground,
    );

    if (!policy.canOffer(
      suggestion: widget.suggestion,
      signals: signals,
      state: helpState,
      now: DateTime.now(),
      alreadyOfferedThisSession:
          helpController.wasOfferedThisSession(widget.suggestion.id),
    )) {
      return;
    }

    helpController.markOfferedThisSession(widget.suggestion.id);
    setState(() => _visible = true);
  }

  bool _hasActiveTextInput() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contextualHelpControllerProvider, (previous, next) {
      final becameReady = next.isInitialized &&
          !next.isLoading &&
          !(previous?.isInitialized ?? false);
      final reEnabled = next.helperEnabled && !(previous?.helperEnabled ?? true);
      if (!_visible && (becameReady || reEnabled)) {
        _scheduleEvaluation();
      }
    });
    ref.listen(guidedExperienceControllerProvider, (previous, next) {
      final guideEnded =
          previous?.activeSession != null && next.activeSession == null;
      if (!_visible && guideEnded) _scheduleEvaluation();
    });
    ref.listen(smartWorkActivityControllerProvider, (previous, next) {
      if (previous?.revision == next.revision) return;
      if (!next.isForeground && _visible && mounted) {
        setState(() => _visible = false);
      }
      if (!_visible) _scheduleEvaluation();
    });

    final helpState = ref.watch(contextualHelpControllerProvider);
    final guideState = ref.watch(guidedExperienceControllerProvider);
    final activity = ref.watch(smartWorkActivityControllerProvider);
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final routeBecameCurrent = _lastRouteCurrent == false && routeCurrent;
    _lastRouteCurrent = routeCurrent;
    if (!_visible && routeBecameCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleEvaluation();
      });
    }
    final remainsRelevant =
        (!widget.suggestion.requiresIncompleteAction ||
            widget.signals.hasIncompleteAction) &&
        (!widget.suggestion.requiresFirstTimeUse ||
            widget.signals.isFirstTimeUse) &&
        (!widget.suggestion.suppressWhenRelatedGuideCompleted ||
            !widget.signals.relatedGuideCompleted);
    final shouldRender = _visible &&
        helpState.helperEnabled &&
        guideState.activeSession == null &&
        activity.isForeground &&
        routeCurrent &&
        !_hasActiveTextInput() &&
        remainsRelevant;

    if (!shouldRender) return widget.child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _SmartWorkAssistantPrompt(
                  suggestion: widget.suggestion,
                  onShowMe: () {
                    setState(() => _visible = false);
                    widget.onShowMe();
                  },
                  onNotNow: () {
                    setState(() => _visible = false);
                    unawaited(
                      ref
                          .read(contextualHelpControllerProvider.notifier)
                          .snooze(widget.suggestion.id),
                    );
                  },
                  onTurnOff: () {
                    setState(() => _visible = false);
                    unawaited(
                      ref
                          .read(contextualHelpControllerProvider.notifier)
                          .setHelperEnabled(false),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmartWorkAssistantPrompt extends StatelessWidget {
  const _SmartWorkAssistantPrompt({
    required this.suggestion,
    required this.onShowMe,
    required this.onNotNow,
    required this.onTurnOff,
  });

  final ContextualHelpSuggestion suggestion;
  final VoidCallback onShowMe;
  final VoidCallback onNotNow;
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 10,
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final copy = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Work Assistant',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  suggestion.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartWorkRobot(size: 56),
                      const SizedBox(width: 8),
                      Expanded(child: copy),
                    ],
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SmartWorkRobot(size: 68),
                      const SizedBox(width: 10),
                      Expanded(child: copy),
                    ],
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        key: const ValueKey('smart-work-assistant-turn-off'),
                        onPressed: onTurnOff,
                        child: Text(suggestion.disableLabel),
                      ),
                      TextButton(
                        key: const ValueKey('smart-work-assistant-not-now'),
                        onPressed: onNotNow,
                        child: Text(suggestion.secondaryLabel),
                      ),
                      FilledButton.tonal(
                        key: const ValueKey('smart-work-assistant-show-me'),
                        onPressed: onShowMe,
                        child: Text(suggestion.primaryLabel),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
