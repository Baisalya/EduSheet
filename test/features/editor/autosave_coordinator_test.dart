import 'dart:async';

import 'package:edusheet/features/editor/services/autosave_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutosaveCoordinator', () {
    test('debounces rapid edits and saves only the latest snapshot', () async {
      final saved = <int>[];
      final coordinator = AutosaveCoordinator<int>(
        delay: const Duration(milliseconds: 5),
        save: (value) async => saved.add(value),
      );

      coordinator
        ..schedule(1)
        ..schedule(2)
        ..schedule(3);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await coordinator.flush();

      expect(saved, [3]);
      expect(coordinator.status.phase, AutosavePhase.saved);
      coordinator.dispose();
    });

    test('serializes a later snapshot behind an active write', () async {
      final firstWriteGate = Completer<void>();
      final saved = <int>[];
      var activeWrites = 0;
      var maximumActiveWrites = 0;
      final coordinator = AutosaveCoordinator<int>(
        delay: const Duration(milliseconds: 2),
        save: (value) async {
          activeWrites++;
          maximumActiveWrites = activeWrites > maximumActiveWrites
              ? activeWrites
              : maximumActiveWrites;
          saved.add(value);
          if (value == 1) await firstWriteGate.future;
          activeWrites--;
        },
      );

      coordinator.schedule(1);
      await Future<void>.delayed(const Duration(milliseconds: 8));
      coordinator.schedule(2);
      await Future<void>.delayed(const Duration(milliseconds: 8));

      expect(saved, [1]);
      expect(maximumActiveWrites, 1);
      firstWriteGate.complete();
      await coordinator.flush();

      expect(saved, [1, 2]);
      expect(maximumActiveWrites, 1);
      coordinator.dispose();
    });

    test('reports failure without discarding the editable snapshot', () async {
      final coordinator = AutosaveCoordinator<String>(
        delay: Duration.zero,
        save: (_) async => throw StateError('disk full'),
      );

      coordinator.schedule('teacher content');
      await coordinator.flush();

      expect(coordinator.status.phase, AutosavePhase.failed);
      expect(coordinator.status.error, isA<StateError>());
      coordinator.dispose();
    });
  });
}
