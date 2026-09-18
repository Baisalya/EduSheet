import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DismissLayerResult { dismissed, blocked, ignored }

typedef DismissLayerCallback = DismissLayerResult Function();

class DismissLayerHandle {
  DismissLayerHandle._(this._coordinator, this._token);

  final DismissLayerCoordinator _coordinator;
  final int _token;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _coordinator._unregister(_token);
  }

  /// Compatibility with the temporary Phase 8 callback-style handle.
  void call() => dispose();
}

class _DismissLayerRegistration {
  const _DismissLayerRegistration({
    required this.token,
    required this.id,
    required this.onEscape,
  });

  final int token;
  final Object id;
  final DismissLayerCallback onEscape;
}

/// Coordinates transient UI that does not live on the root [Navigator].
///
/// Navigator-backed dialogs, sheets and popup routes should continue to use
/// normal Navigator/PopScope semantics. Register only custom overlay layers
/// that need to receive Escape before route navigation.
class DismissLayerCoordinator {
  final List<_DismissLayerRegistration> _layers = <_DismissLayerRegistration>[];
  int _nextToken = 0;

  bool get hasRegisteredLayer => _layers.isNotEmpty;

  Object? get topLayerId => _layers.isEmpty ? null : _layers.last.id;

  DismissLayerHandle register({
    required Object id,
    required DismissLayerCallback onEscape,
  }) {
    final registration = _DismissLayerRegistration(
      token: _nextToken++,
      id: id,
      onEscape: onEscape,
    );
    _layers.add(registration);
    return DismissLayerHandle._(this, registration.token);
  }

  DismissLayerResult handleEscape() {
    if (_layers.isEmpty) return DismissLayerResult.ignored;
    return _layers.last.onEscape();
  }

  void _unregister(int token) {
    _layers.removeWhere((registration) => registration.token == token);
  }

  void clear() {
    _layers.clear();
  }
}

final dismissLayerCoordinatorProvider = Provider<DismissLayerCoordinator>((ref) {
  final coordinator = DismissLayerCoordinator();
  ref.onDispose(coordinator.clear);
  return coordinator;
});
