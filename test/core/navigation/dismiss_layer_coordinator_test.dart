import 'package:edusheet/core/navigation/dismiss_layer_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last registered dismiss layer receives Escape first', () {
    final coordinator = DismissLayerCoordinator();
    final calls = <String>[];

    final first = coordinator.register(
      id: 'first',
      onEscape: () {
        calls.add('first');
        return DismissLayerResult.dismissed;
      },
    );
    final second = coordinator.register(
      id: 'second',
      onEscape: () {
        calls.add('second');
        return DismissLayerResult.dismissed;
      },
    );

    expect(coordinator.topLayerId, 'second');
    expect(coordinator.handleEscape(), DismissLayerResult.dismissed);
    expect(calls, <String>['second']);

    second.dispose();
    expect(coordinator.handleEscape(), DismissLayerResult.dismissed);
    expect(calls, <String>['second', 'first']);

    first.dispose();
    expect(coordinator.handleEscape(), DismissLayerResult.ignored);
  });

  test('blocked top layer prevents fallback dismissal', () {
    final coordinator = DismissLayerCoordinator();
    final handle = coordinator.register(
      id: 'required-step',
      onEscape: () => DismissLayerResult.blocked,
    );

    expect(coordinator.handleEscape(), DismissLayerResult.blocked);
    handle.dispose();
  });
}
