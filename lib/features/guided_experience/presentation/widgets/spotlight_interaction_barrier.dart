import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Absorbs pointer events outside the highlighted target while allowing events
/// inside [targetRect] to continue to the real application widget below.
class SpotlightInteractionBarrier extends LeafRenderObjectWidget {
  const SpotlightInteractionBarrier({
    super.key,
    required this.targetRect,
    this.enabled = true,
  });

  final Rect? targetRect;
  final bool enabled;

  @override
  RenderSpotlightInteractionBarrier createRenderObject(BuildContext context) {
    return RenderSpotlightInteractionBarrier(
      targetRect: targetRect,
      enabled: enabled,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSpotlightInteractionBarrier renderObject,
  ) {
    renderObject
      ..targetRect = targetRect
      ..enabled = enabled;
  }
}

class RenderSpotlightInteractionBarrier extends RenderBox {
  RenderSpotlightInteractionBarrier({
    required Rect? targetRect,
    required bool enabled,
  }) : _targetRect = targetRect,
       _enabled = enabled;

  Rect? _targetRect;
  bool _enabled;

  set targetRect(Rect? value) {
    if (_targetRect == value) return;
    _targetRect = value;
  }

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_enabled || !size.contains(position)) return false;
    final targetRect = _targetRect;
    if (targetRect != null && targetRect.contains(position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    // Deliberately absorb events outside the spotlight. Coach controls are
    // painted above this barrier and receive their own events normally.
  }
}
