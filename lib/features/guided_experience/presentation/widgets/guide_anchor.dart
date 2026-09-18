import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guide_target_registry.dart';
import '../../domain/guide_ids.dart';

/// Lightweight wrapper that exposes a real application control to the guide
/// engine without adding tutorial behaviour to the control itself.
class GuideAnchor extends StatefulWidget {
  const GuideAnchor({
    super.key,
    required this.targetId,
    required this.child,
    this.reportPointerActivation = false,
  });

  final GuideTargetId targetId;
  final Widget child;

  /// Reports a pointer-up as target activation. Keep this false for controls
  /// whose success depends on validation or an asynchronous business write;
  /// those flows should notify guide progression only after the real action
  /// succeeds. It is suitable for simple navigation/open controls.
  final bool reportPointerActivation;

  @override
  State<GuideAnchor> createState() => _GuideAnchorState();
}

class _GuideAnchorState extends State<GuideAnchor> {
  final GlobalKey _targetKey = GlobalKey();
  GuideTargetRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachToRegistry();
  }

  @override
  void didUpdateWidget(covariant GuideAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId) {
      _registry?.unregister(oldWidget.targetId, _targetKey);
      _registry?.register(widget.targetId, _targetKey);
    }
    _announceLayout();
  }

  void _attachToRegistry() {
    GuideTargetRegistry? nextRegistry;
    try {
      nextRegistry = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(guideTargetRegistryProvider);
    } on StateError {
      // GuideAnchor is optional infrastructure. Reusable application widgets
      // and isolated widget tests may render without a ProviderScope; in that
      // case the real control must remain fully usable even though guide
      // geometry/activation reporting is unavailable.
      nextRegistry = null;
    }

    if (identical(_registry, nextRegistry)) return;

    _registry?.unregister(widget.targetId, _targetKey);
    _registry = nextRegistry;
    _registry?.register(widget.targetId, _targetKey);
    _announceLayout();
  }

  void _announceLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registry?.notifyLayoutChanged(widget.targetId);
    });
  }

  @override
  void dispose() {
    _registry?.unregister(widget.targetId, _targetKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchoredChild = KeyedSubtree(key: _targetKey, child: widget.child);
    if (!widget.reportPointerActivation) return anchoredChild;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => _registry?.notifyActivated(widget.targetId),
      child: anchoredChild,
    );
  }
}
