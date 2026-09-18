import 'package:edusheet/core/navigation/dismiss_layer_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration handle is both disposable and safely callable', () {
    final coordinator = DismissLayerCoordinator();
    final handle = coordinator.register(
      id: 'guide',
      onEscape: () => DismissLayerResult.dismissed,
    );

    expect(coordinator.topLayerId, 'guide');
    expect(coordinator.handleEscape(), DismissLayerResult.dismissed);

    handle();
    expect(coordinator.handleEscape(), DismissLayerResult.ignored);
    handle.dispose();
  });

  test('blocked top layer preserves the underlying route', () {
    final coordinator = DismissLayerCoordinator();
    coordinator.register(
      id: 'required-guide-step',
      onEscape: () => DismissLayerResult.blocked,
    );

    expect(coordinator.handleEscape(), DismissLayerResult.blocked);
  });
}
