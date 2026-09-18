import 'package:edusheet/features/guided_experience/application/guide_target_registry.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GuideAnchor registers the real widget geometry and unregisters', (
    tester,
  ) async {
    final registry = GuideTargetRegistry();
    const targetId = GuideTargetId('sample-control');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideTargetRegistryProvider.overrideWithValue(registry),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GuideAnchor(
                targetId: targetId,
                child: SizedBox(width: 120, height: 48),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(registry.contains(targetId), isTrue);
    expect(registry.contextFor(targetId), isNotNull);
    expect(registry.rectFor(targetId)?.size, const Size(120, 48));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(registry.contains(targetId), isFalse);
    registry.dispose();
  });

  testWidgets('GuideAnchor can report simple real-control pointer activation', (
    tester,
  ) async {
    final registry = GuideTargetRegistry();
    const targetId = GuideTargetId('activation-control');
    final activation = registry.activations.first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideTargetRegistryProvider.overrideWithValue(registry),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GuideAnchor(
              targetId: targetId,
              reportPointerActivation: true,
              child: TextButton(
                onPressed: () {},
                child: const Text('activate-me'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('activate-me'));
    await tester.pump();

    expect(
      await activation.timeout(const Duration(seconds: 2)),
      targetId,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    registry.dispose();
  });

  testWidgets('GuideAnchor remains transparent without a ProviderScope', (
    tester,
  ) async {
    var presses = 0;
    const targetId = GuideTargetId('standalone-control');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideAnchor(
            targetId: targetId,
            reportPointerActivation: true,
            child: TextButton(
              onPressed: () => presses++,
              child: const Text('standalone-control'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('standalone-control'));
    await tester.pump();
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

}
