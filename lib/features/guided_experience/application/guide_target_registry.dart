import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guide_ids.dart';

class GuideTargetRegistry extends ChangeNotifier {
  final Map<GuideTargetId, GlobalKey> _targets = <GuideTargetId, GlobalKey>{};
  final StreamController<GuideTargetId> _activations =
      StreamController<GuideTargetId>.broadcast(sync: true);

  Stream<GuideTargetId> get activations => _activations.stream;

  bool contains(GuideTargetId targetId) => _targets.containsKey(targetId);

  void register(GuideTargetId targetId, GlobalKey key) {
    if (identical(_targets[targetId], key)) return;
    _targets[targetId] = key;
    notifyListeners();
  }

  void unregister(GuideTargetId targetId, GlobalKey key) {
    if (!identical(_targets[targetId], key)) return;
    _targets.remove(targetId);
    notifyListeners();
  }

  void notifyActivated(GuideTargetId targetId) {
    if (!_targets.containsKey(targetId) || _activations.isClosed) return;
    _activations.add(targetId);
  }

  /// Notifies the overlay that a registered target moved or resized without
  /// changing identity (for example after a free-form window/layout change).
  void notifyLayoutChanged(GuideTargetId targetId) {
    if (!_targets.containsKey(targetId)) return;
    notifyListeners();
  }

  BuildContext? contextFor(GuideTargetId targetId) {
    return _targets[targetId]?.currentContext;
  }

  Rect? rectFor(GuideTargetId targetId) {
    final context = contextFor(targetId);
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  Future<bool> ensureVisible(
    GuideTargetId targetId, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
    double alignment = 0.5,
  }) async {
    final context = contextFor(targetId);
    if (context == null) return false;

    await Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: curve,
      alignment: alignment,
    );
    return rectFor(targetId) != null;
  }

  @override
  void dispose() {
    _targets.clear();
    _activations.close();
    super.dispose();
  }
}

final guideTargetRegistryProvider = Provider<GuideTargetRegistry>((ref) {
  final registry = GuideTargetRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});
