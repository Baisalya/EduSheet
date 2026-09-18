import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SmartWorkActivityState {
  const SmartWorkActivityState({
    required this.lastActivityAt,
    this.isForeground = true,
    this.revision = 0,
  });

  final DateTime lastActivityAt;
  final bool isForeground;
  final int revision;

  Duration inactivityAt(DateTime now) {
    if (!isForeground || now.isBefore(lastActivityAt)) return Duration.zero;
    return now.difference(lastActivityAt);
  }

  SmartWorkActivityState copyWith({
    DateTime? lastActivityAt,
    bool? isForeground,
    int? revision,
  }) {
    return SmartWorkActivityState(
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isForeground: isForeground ?? this.isForeground,
      revision: revision ?? this.revision,
    );
  }
}

class SmartWorkActivityController extends StateNotifier<SmartWorkActivityState> {
  SmartWorkActivityController({DateTime? now})
      : super(SmartWorkActivityState(lastActivityAt: now ?? DateTime.now()));

  void recordActivity({DateTime? now}) {
    state = state.copyWith(
      lastActivityAt: now ?? DateTime.now(),
      revision: state.revision + 1,
    );
  }

  void setForeground(bool foreground, {DateTime? now}) {
    if (foreground == state.isForeground) return;
    final timestamp = now ?? DateTime.now();
    state = state.copyWith(
      isForeground: foreground,
      lastActivityAt: foreground ? timestamp : state.lastActivityAt,
      revision: state.revision + 1,
    );
  }
}

final smartWorkActivityControllerProvider = StateNotifierProvider<
    SmartWorkActivityController, SmartWorkActivityState>((ref) {
  return SmartWorkActivityController();
});
