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
  T Function()? _pendingFactory;
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
    _pendingFactory = null;
    _hasPendingValue = true;
    _timer?.cancel();
    _emit(const AutosaveStatus(AutosavePhase.waiting));
    _timer = Timer(delay, _queuePendingWrite);
  }

  /// Schedules a value that is only materialized when the debounce expires.
  ///
  /// This is useful for editors where building a persistence snapshot (for
  /// example serializing a large rich-text document) is itself expensive. The
  /// latest factory wins, exactly like [schedule], but typing does not pay the
  /// serialization cost on every keystroke.
  void scheduleLazy(T Function() valueFactory) {
    if (_disposed) return;
    _pendingValue = null;
    _pendingFactory = valueFactory;
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

  /// Drops a debounced value that has not started writing yet.
  ///
  /// Editor workflows use this when switching documents or resetting a blank
  /// draft so an old pending autosave cannot appear later as a ghost paper.
  void discardPending({bool resetStatus = true}) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
    _pendingFactory = null;
    _hasPendingValue = false;
    if (resetStatus) {
      _emit(const AutosaveStatus(AutosavePhase.idle));
    }
  }

  Future<void> _queuePendingWrite() async {
    if (_disposed || !_hasPendingValue) return;
    final factory = _pendingFactory;
    final pendingValue = _pendingValue;
    _pendingValue = null;
    _pendingFactory = null;
    _hasPendingValue = false;
    _emit(const AutosaveStatus(AutosavePhase.saving));

    late final T value;
    try {
      value = factory != null ? factory() : pendingValue as T;
    } catch (error) {
      _emit(AutosaveStatus(AutosavePhase.failed, error: error));
      return;
    }

    final operation = _writeTail.then((_) => save(value));
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
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
    _pendingFactory = null;
    _hasPendingValue = false;
  }
}
