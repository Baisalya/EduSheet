import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/dismiss_layer_coordinator.dart';
import '../../application/guide_target_registry.dart';
import '../../application/guided_experience_providers.dart';
import '../../domain/guide_definition.dart';
import '../../domain/guide_ids.dart';
import '../../domain/guide_session.dart';
import '../../domain/guided_experience_state.dart';
import 'guide_coach_card.dart';
import 'guide_placement_engine.dart';
import 'guided_helper.dart';
import 'spotlight_interaction_barrier.dart';
import 'spotlight_overlay.dart';

/// App-level host for guided-experience visuals.
///
/// Business screens remain unaware of overlay layout. They only expose real
/// controls through GuideAnchor. The host tracks those anchors through resize,
/// scrolling and route/layout changes, and places all guide chrome above the
/// existing application UI.
class GuideOverlayHost extends ConsumerStatefulWidget {
  const GuideOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GuideOverlayHost> createState() => _GuideOverlayHostState();
}

class _GuideOverlayHostState extends ConsumerState<GuideOverlayHost>
    with WidgetsBindingObserver {
  static const _dismissLayerId = 'guided-experience-overlay';
  static const double _screenMargin = 16;

  final GlobalKey _hostKey = GlobalKey();
  GuideTargetRegistry? _registry;
  StreamSubscription<GuideTargetId>? _activationSubscription;
  DismissLayerHandle? _dismissHandle;
  DismissLayerCoordinator? _dismissCoordinator;
  GuideStepId? _preparedStepId;
  GuideTargetId? _geometryTargetId;
  Rect? _targetRect;
  bool _geometryRefreshScheduled = false;
  bool _ensureVisibleInFlight = false;
  bool _dismissSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRegistry();
  }

  void _attachRegistry() {
    final nextRegistry = ref.read(guideTargetRegistryProvider);
    if (identical(_registry, nextRegistry)) return;

    _registry?.removeListener(_scheduleGeometryRefresh);
    unawaited(_activationSubscription?.cancel());
    _registry = nextRegistry;
    _registry!.addListener(_scheduleGeometryRefresh);
    _activationSubscription = _registry!.activations.listen(
      _handleTargetActivated,
    );
  }

  @override
  void didChangeMetrics() {
    _scheduleGeometryRefresh();
  }

  void _handleTargetActivated(GuideTargetId targetId) {
    final state = ref.read(guidedExperienceControllerProvider);
    final session = state.activeSession;
    final step = state.activeStep;
    if (session == null ||
        step == null ||
        step.advanceMode != GuideAdvanceMode.targetActivated ||
        step.targetId != targetId) {
      return;
    }

    final expectedStepId = session.currentStepId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(guidedExperienceControllerProvider);
      if (latest.activeSession?.currentStepId != expectedStepId ||
          latest.activeStep?.targetId != targetId) {
        return;
      }
      unawaited(
        ref.read(guidedExperienceControllerProvider.notifier).advance(),
      );
    });
  }

  void _scheduleDismissSync(bool active) {
    if (_dismissSyncScheduled) return;
    _dismissSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissSyncScheduled = false;
      if (!mounted) return;
      _syncDismissLayer(active);
    });
  }

  void _syncDismissLayer(bool active) {
    final coordinator = ref.read(dismissLayerCoordinatorProvider);
    if (!identical(_dismissCoordinator, coordinator)) {
      _dismissHandle?.dispose();
      _dismissHandle = null;
      _dismissCoordinator = coordinator;
    }

    if (!active) {
      _dismissHandle?.dispose();
      _dismissHandle = null;
      return;
    }

    _dismissHandle ??= coordinator.register(
      id: _dismissLayerId,
      onEscape: () {
        unawaited(ref.read(guidedExperienceControllerProvider.notifier).stop());
        return DismissLayerResult.dismissed;
      },
    );
  }

  void _scheduleGeometryRefresh() {
    if (_geometryRefreshScheduled) return;
    _geometryRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryRefreshScheduled = false;
      if (!mounted) return;
      _refreshGeometry();
      _ensureActiveTargetVisibleIfNeeded();
    });
  }

  void _prepareStep(GuideStep step) {
    if (!mounted || _preparedStepId == step.id) return;
    _preparedStepId = step.id;

    final targetId = step.targetId;
    if (targetId == null) {
      _updateTargetRect(null, null);
      return;
    }

    // Resolve geometry immediately. A target that is already visible should not
    // spend a frame in the waiting state while an unnecessary scroll animation
    // runs; the helper and interaction barrier need to be present as soon as
    // the real control is measurable.
    _updateTargetRect(targetId, null);
    _refreshGeometry();
    _ensureActiveTargetVisibleIfNeeded();
  }

  void _refreshGeometry() {
    final state = ref.read(guidedExperienceControllerProvider);
    final step = state.activeStep;
    final targetId = step?.targetId;
    if (step == null || targetId == null) {
      _updateTargetRect(targetId, null);
      return;
    }

    final globalRect = _registry?.rectFor(targetId);
    final hostRenderObject = _hostKey.currentContext?.findRenderObject();
    if (globalRect == null ||
        hostRenderObject is! RenderBox ||
        !hostRenderObject.attached ||
        !hostRenderObject.hasSize) {
      _updateTargetRect(targetId, null);
      return;
    }

    final topLeft = hostRenderObject.globalToLocal(globalRect.topLeft);
    final bottomRight = hostRenderObject.globalToLocal(globalRect.bottomRight);
    final localRect = Rect.fromPoints(topLeft, bottomRight);
    _updateTargetRect(targetId, localRect);
  }

  void _ensureActiveTargetVisibleIfNeeded() {
    if (_ensureVisibleInFlight || !mounted) return;

    final state = ref.read(guidedExperienceControllerProvider);
    final step = state.activeStep;
    final targetId = step?.targetId;
    if (targetId == null || _geometryTargetId != targetId) return;

    final targetRect = _targetRect;
    final hostRenderObject = _hostKey.currentContext?.findRenderObject();
    if (targetRect == null ||
        hostRenderObject is! RenderBox ||
        !hostRenderObject.attached ||
        !hostRenderObject.hasSize) {
      return;
    }

    final viewport = Offset.zero & hostRenderObject.size;
    if (viewport.contains(targetRect.topLeft) &&
        viewport.contains(targetRect.bottomRight)) {
      return;
    }

    _ensureVisibleInFlight = true;
    unawaited(
      _ensureTargetVisible(targetId).whenComplete(() {
        _ensureVisibleInFlight = false;
        if (mounted) _scheduleGeometryRefresh();
      }),
    );
  }

  Future<void> _ensureTargetVisible(GuideTargetId targetId) async {
    // Use an immediate reveal rather than a delayed animation. It avoids a
    // transient state where the spotlight is active for an off-screen control,
    // remains deterministic during Windows resizing, and naturally respects
    // reduced-motion users.
    await _registry?.ensureVisible(
      targetId,
      duration: Duration.zero,
      alignment: 0.5,
    );
  }

  void _updateTargetRect(GuideTargetId? targetId, Rect? rect) {
    if (_geometryTargetId == targetId && _rectNearlyEqual(_targetRect, rect)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _geometryTargetId = targetId;
      _targetRect = rect;
    });
  }

  bool _rectNearlyEqual(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    const tolerance = 0.5;
    return (a.left - b.left).abs() < tolerance &&
        (a.top - b.top).abs() < tolerance &&
        (a.right - b.right).abs() < tolerance &&
        (a.bottom - b.bottom).abs() < tolerance;
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _registry?.removeListener(_scheduleGeometryRefresh);
    unawaited(_activationSubscription?.cancel());
    _dismissHandle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _attachRegistry();
    final state = ref.watch(guidedExperienceControllerProvider);
    final session = state.activeSession;
    final step = state.activeStep;
    final active = session != null && step != null;
    _scheduleDismissSync(active);

    if (step?.id != _preparedStepId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestStep = ref.read(guidedExperienceControllerProvider).activeStep;
        if (latestStep != null) _prepareStep(latestStep);
      });
    } else if (active) {
      _scheduleGeometryRefresh();
    }

    final targetId = step?.targetId;
    final targetReady = targetId == null ||
        (_geometryTargetId == targetId && _targetRect != null);

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleGeometryRefresh();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hostSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            key: _hostKey,
            fit: StackFit.expand,
            children: [
              widget.child,
              if (active && !targetReady)
                _buildWaitingCoach(context, state, step, hostSize),
              if (active && targetReady)
                ..._buildOverlay(context, state, step, hostSize),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaitingCoach(
    BuildContext context,
    GuidedExperienceState state,
    GuideStep step,
    Size size,
  ) {
    final session = state.activeSession!;
    final media = MediaQuery.of(context);
    final maxWidth = math
        .min(380.0, math.max(0.0, size.width - (_screenMargin * 2)))
        .toDouble();
    final maxHeight = math
        .max(
          0.0,
          size.height -
              media.padding.top -
              media.padding.bottom -
              media.viewInsets.bottom -
              (_screenMargin * 2),
        )
        .toDouble();

    return Positioned.fill(
      child: SafeArea(
        minimum: const EdgeInsets.all(_screenMargin),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: _coachCard(step, session, targetAvailable: false),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverlay(
    BuildContext context,
    GuidedExperienceState state,
    GuideStep step,
    Size size,
  ) {
    final session = state.activeSession!;
    final media = MediaQuery.of(context);
    final targetRect = step.targetId == null ? null : _targetRect;
    final safeViewport = _safeViewport(size, media);

    return <Widget>[
      Positioned.fill(
        child: SpotlightOverlay(targetRect: targetRect),
      ),
      Positioned.fill(
        child: SpotlightInteractionBarrier(
          targetRect: targetRect,
          enabled: !step.allowOutsideInteraction,
        ),
      ),
      if (targetRect != null)
        _PrecisionCoachPositioner(
          safeViewport: safeViewport,
          targetRect: targetRect,
          child: _coachCard(step, session),
        )
      else
        Center(
          child: SafeArea(
            minimum: const EdgeInsets.all(_screenMargin),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(420, math.max(0, safeViewport.width - 24)),
                maxHeight: math.max(0, safeViewport.height - 24),
              ),
              child: _coachCard(step, session),
            ),
          ),
        ),
      if (targetRect != null)
        _HelperPositioner(
          safeViewport: safeViewport,
          targetRect: targetRect,
          child: GuidedHelper(reduceMotion: _reduceMotion),
        ),
    ];
  }

  Rect _safeViewport(Size size, MediaQueryData media) {
    final bottomInset = math.max(media.padding.bottom, media.viewInsets.bottom);
    final left = media.padding.left.clamp(0.0, size.width).toDouble();
    final right = (size.width - media.padding.right)
        .clamp(left, size.width)
        .toDouble();
    final top = media.padding.top.clamp(0.0, size.height).toDouble();
    final bottom = (size.height - bottomInset)
        .clamp(top, size.height)
        .toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Widget _coachCard(
    GuideStep step,
    GuideSession session, {
    bool targetAvailable = true,
  }) {
    final controller = ref.read(guidedExperienceControllerProvider.notifier);
    return GuideCoachCard(
      step: step,
      stepNumber: session.currentStepIndex + 1,
      totalSteps: session.stepIds.length,
      isFirstStep: session.isFirstStep,
      isLastStep: session.isLastStep,
      onBack: () => unawaited(controller.goBack()),
      onNext: () => unawaited(controller.advance()),
      onSkip: () => unawaited(controller.skip()),
      onStop: () => unawaited(controller.stop()),
      targetAvailable: targetAvailable,
    );
  }
}

class _PrecisionCoachPositioner extends StatelessWidget {
  const _PrecisionCoachPositioner({
    required this.safeViewport,
    required this.targetRect,
    required this.child,
  });

  final Rect safeViewport;
  final Rect targetRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final availableWidth = math.max(0.0, safeViewport.width - 24);
    final maxCardWidth = math.min(420.0, availableWidth);
    if (maxCardWidth <= 0 || safeViewport.height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _CoachLayoutDelegate(
          safeViewport: safeViewport,
          targetRect: targetRect,
          textDirection: Directionality.of(context),
          maxWidth: maxCardWidth,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          child: child,
        ),
      ),
    );
  }
}

class _CoachLayoutDelegate extends SingleChildLayoutDelegate {
  _CoachLayoutDelegate({
    required this.safeViewport,
    required this.targetRect,
    required this.textDirection,
    required this.maxWidth,
  });

  final Rect safeViewport;
  final Rect targetRect;
  final TextDirection textDirection;
  final double maxWidth;
  final GuidePlacementEngine engine = const GuidePlacementEngine();

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final topSpace = math.max(0.0, targetRect.top - safeViewport.top - 14);
    final bottomSpace = math.max(
      0.0,
      safeViewport.bottom - targetRect.bottom - 14,
    );
    final bestVerticalSpace = math.max(topSpace, bottomSpace);
    final viewportLimit = math.max(80.0, safeViewport.height - 24);
    final maxHeight = bestVerticalSpace >= 96
        ? math.min(viewportLimit, bestVerticalSpace)
        : viewportLimit;
    return BoxConstraints(
      minWidth: math.min(260.0, maxWidth),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return engine
        .place(
          viewport: safeViewport,
          target: targetRect,
          childSize: childSize,
          textDirection: textDirection,
        )
        .offset;
  }

  @override
  bool shouldRelayout(covariant _CoachLayoutDelegate oldDelegate) {
    return oldDelegate.safeViewport != safeViewport ||
        oldDelegate.targetRect != targetRect ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth;
  }
}

class _HelperPositioner extends StatelessWidget {
  const _HelperPositioner({
    required this.safeViewport,
    required this.targetRect,
    required this.child,
  });

  final Rect safeViewport;
  final Rect targetRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (safeViewport.width <= 0 || safeViewport.height <= 0) {
      return const SizedBox.shrink();
    }

    final helperSize = math.min(
      56.0,
      math.min(
        math.max(0.0, safeViewport.width - 16),
        math.max(0.0, safeViewport.height - 16),
      ),
    );
    if (helperSize <= 0) return const SizedBox.shrink();
    final placement = const GuidePlacementEngine(gap: 8, margin: 8).place(
      viewport: safeViewport,
      target: targetRect,
      childSize: Size.square(helperSize),
      textDirection: Directionality.of(context),
    );

    return Positioned(
      left: placement.offset.dx,
      top: placement.offset.dy,
      width: helperSize,
      height: helperSize,
      child: IgnorePointer(child: child),
    );
  }
}

