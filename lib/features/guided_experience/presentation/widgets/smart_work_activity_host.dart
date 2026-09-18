import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/smart_work_activity_controller.dart';

/// App-wide activity sensor for the Smart Work Assistant.
///
/// It records intentional interaction only: pointer presses/signals, scrolling,
/// keyboard input, focus changes and app resume. Mere mouse hover does not reset
/// the timer, so desktop users are not kept permanently "active" by cursor
/// movement.
class SmartWorkActivityHost extends ConsumerStatefulWidget {
  const SmartWorkActivityHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SmartWorkActivityHost> createState() =>
      _SmartWorkActivityHostState();
}

class _SmartWorkActivityHostState extends ConsumerState<SmartWorkActivityHost>
    with WidgetsBindingObserver {
  DateTime? _lastRecordedAt;
  DateTime? _queuedActivityAt;
  bool _activityPostFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _recordActivity(force: true);
    }
    return false;
  }

  void _handleFocusChange() => _recordActivity();

  void _recordActivity({bool force = false}) {
    if (!mounted) return;
    final now = DateTime.now();
    final previous = _lastRecordedAt;
    if (!force &&
        previous != null &&
        now.difference(previous) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastRecordedAt = now;

    // Pointer/key callbacks normally arrive while the scheduler is idle and
    // can update Riverpod immediately. Scroll notifications may be emitted
    // from RenderViewport.performLayout; mutating a provider there can rebuild
    // consumers inside layout and corrupt the render pass. Defer only those
    // in-frame notifications until the frame is complete.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      ref
          .read(smartWorkActivityControllerProvider.notifier)
          .recordActivity(now: now);
      return;
    }

    _queuedActivityAt = now;
    if (_activityPostFrameScheduled) return;

    _activityPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activityPostFrameScheduled = false;
      final recordedAt = _queuedActivityAt;
      _queuedActivityAt = null;
      if (!mounted || recordedAt == null) return;
      ref
          .read(smartWorkActivityControllerProvider.notifier)
          .recordActivity(now: recordedAt);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(smartWorkActivityControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        controller.setForeground(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        controller.setForeground(false);
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(force: true),
      onPointerSignal: (_) => _recordActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification) {
            _recordActivity();
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
