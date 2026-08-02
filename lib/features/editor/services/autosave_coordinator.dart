import 'dart:async';

enum AutosavePhase { idle, waiting, saving, saved, failed }

class AutosaveStatus {
  final AutosavePhase phase;
  final DateTime? savedAt;
  final Object? error;

  const AutosaveStatus(this.phase, {this.savedAt, this.error});

  String get accessibleLabel {
    switch (phase) {
      case AutosavePhase.idle:
        return 'Not saved yet';
      case AutosavePhase.waiting:
        return 'Changes waiting to save';
      case AutosavePhase.saving:
        return 'Saving changes';
      case AutosavePhase.saved:
        return 'All changes saved';
      case AutosavePhase.failed:
        return 'Could not save changes';
    }
  }
}

/// Debounces typing and guarantees that file writes execute one at a time.
class AutosaveCoordinator<T> {
  final Duration delay;
  final Future<void> Function(T value) save;
  final void Function(AutosaveStatus status)? onStatus;

  Timer? _timer;
  T? _pendingValue;
  bool _hasPendingValue = false;
  bool _disposed = false;
  Future<void> _writeTail = Future<void>.value();
  AutosaveStatus _status = const AutosaveStatus(AutosavePhase.idle);

  AutosaveCoordinator({
    required this.save,
    this.delay = const Duration(milliseconds: 650),
    this.onStatus,
  });

  AutosaveStatus get status => _status;

  void schedule(T value) {
    if (_disposed) return;
    _pendingValue = value;
    _hasPendingValue = true;
    _timer?.cancel();
    _emit(const AutosaveStatus(AutosavePhase.waiting));
    _timer = Timer(delay, _queuePendingWrite);
  }

  Future<void> flush() async {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    await _queuePendingWrite();
    await _writeTail;
    if (_hasPendingValue) await flush();
  }

  Future<void> _queuePendingWrite() async {
    if (_disposed || !_hasPendingValue) return;
    final value = _pendingValue as T;
    _pendingValue = null;
    _hasPendingValue = false;
    _emit(const AutosaveStatus(AutosavePhase.saving));

    final operation = _writeTail.then((_) => save(value));
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );

    try {
      await operation;
      if (_hasPendingValue) {
        _emit(const AutosaveStatus(AutosavePhase.waiting));
      } else {
        _emit(AutosaveStatus(AutosavePhase.saved, savedAt: DateTime.now()));
      }
    } catch (error) {
      _emit(AutosaveStatus(AutosavePhase.failed, error: error));
    }
  }

  void _emit(AutosaveStatus status) {
    _status = status;
    onStatus?.call(status);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
    _hasPendingValue = false;
  }
}
