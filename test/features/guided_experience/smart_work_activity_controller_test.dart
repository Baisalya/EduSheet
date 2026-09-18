import 'package:edusheet/features/guided_experience/application/smart_work_activity_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity reset and app foreground state drive the idle clock', () {
    final start = DateTime(2026, 9, 16, 12);
    final controller = SmartWorkActivityController(now: start);
    addTearDown(controller.dispose);

    expect(
      controller.state.inactivityAt(start.add(const Duration(minutes: 1))),
      const Duration(minutes: 1),
    );

    final activityAt = start.add(const Duration(seconds: 45));
    controller.recordActivity(now: activityAt);
    expect(controller.state.lastActivityAt, activityAt);
    expect(
      controller.state.inactivityAt(start.add(const Duration(minutes: 1))),
      const Duration(seconds: 15),
    );

    controller.setForeground(false, now: start.add(const Duration(minutes: 2)));
    expect(controller.state.isForeground, isFalse);
    expect(
      controller.state.inactivityAt(start.add(const Duration(minutes: 5))),
      Duration.zero,
    );

    final resumedAt = start.add(const Duration(minutes: 6));
    controller.setForeground(true, now: resumedAt);
    expect(controller.state.isForeground, isTrue);
    expect(controller.state.lastActivityAt, resumedAt);
    expect(controller.state.inactivityAt(resumedAt), Duration.zero);
  });
}
