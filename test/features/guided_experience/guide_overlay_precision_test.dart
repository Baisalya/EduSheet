import 'package:edusheet/features/guided_experience/application/guided_experience_providers.dart';
import 'package:edusheet/features/guided_experience/domain/guide_definition.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress_repository.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_anchor.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_coach_card.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_overlay_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = GuideTargetId('phase8-target');
const _step = GuideStepId('phase8-step');

class _MemoryProgressRepository implements GuideProgressRepository {
  final Map<GuideId, GuideProgress> values = {};
  @override
  Future<Map<GuideId, GuideProgress>> loadAll() async => Map.of(values);
  @override
  Future<void> save(GuideProgress progress) async =>
      values[progress.guideId] = progress;

  @override
  Future<void> remove(GuideId guideId) async => values.remove(guideId);
}

GuideDefinition _guide({GuideAdvanceMode mode = GuideAdvanceMode.manual}) =>
    GuideDefinition(
      id: const GuideId('phase8-precision'),
      version: 1,
      steps: [
        GuideStep(
          id: _step,
          title: 'Use this button',
          message: 'The helper must stay clear of the highlighted control.',
          targetId: _target,
          advanceMode: mode,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coach never covers the highlighted bottom button', (tester) async {
    final container = ProviderContainer(
      overrides: [
        guideProgressRepositoryProvider.overrideWithValue(_MemoryProgressRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GuideOverlayHost(
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 120,
                    right: 120,
                    bottom: 24,
                    child: GuideAnchor(
                      targetId: _target,
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Important button'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(guidedExperienceControllerProvider.notifier).startGuide(
          _guide(),
          restart: true,
        );
    await tester.pump();
    await tester.pump();

    final targetRect = tester.getRect(find.text('Important button'));
    final coachRect = tester.getRect(find.byType(GuideCoachCard));
    expect(coachRect.overlaps(targetRect.inflate(6)), isFalse);
  });

  testWidgets('highlighted real button remains clickable through spotlight', (tester) async {
    var taps = 0;
    final container = ProviderContainer(
      overrides: [
        guideProgressRepositoryProvider.overrideWithValue(_MemoryProgressRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GuideOverlayHost(
            child: Scaffold(
              body: Center(
                child: GuideAnchor(
                  targetId: _target,
                  reportPointerActivation: true,
                  child: FilledButton(
                    onPressed: () => taps += 1,
                    child: const Text('Tap highlighted'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(guidedExperienceControllerProvider.notifier).startGuide(
          _guide(mode: GuideAdvanceMode.targetActivated),
          restart: true,
        );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Tap highlighted'));
    await tester.pump();
    expect(taps, 1);
    expect(container.read(guidedExperienceControllerProvider).activeSession, isNull);
  });

  testWidgets('late mounted target replaces waiting state with precise coach', (tester) async {
    final container = ProviderContainer(
      overrides: [
        guideProgressRepositoryProvider.overrideWithValue(_MemoryProgressRepository()),
      ],
    );
    addTearDown(container.dispose);
    final showTarget = ValueNotifier<bool>(false);
    addTearDown(showTarget.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GuideOverlayHost(
            child: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showTarget,
                builder: (context, visible, _) => visible
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: GuideAnchor(
                          targetId: _target,
                          child: const SizedBox(key: ValueKey('late-target-box'), width: 180, height: 48),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(guidedExperienceControllerProvider.notifier).startGuide(
          _guide(),
          restart: true,
        );
    await tester.pump();
    expect(find.byType(GuideCoachCard), findsOneWidget);

    showTarget.value = true;
    await tester.pump();
    await tester.pump();

    final targetRect = tester.getRect(find.byKey(const ValueKey('late-target-box')));
    final coachRect = tester.getRect(find.byType(GuideCoachCard));
    expect(coachRect.overlaps(targetRect.inflate(6)), isFalse);
  });

  testWidgets('spotlight blocks unrelated controls outside the target', (tester) async {
    var targetTaps = 0;
    var outsideTaps = 0;
    final container = ProviderContainer(
      overrides: [
        guideProgressRepositoryProvider.overrideWithValue(_MemoryProgressRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GuideOverlayHost(
            child: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GuideAnchor(
                    targetId: _target,
                    reportPointerActivation: true,
                    child: FilledButton(
                      onPressed: () => targetTaps += 1,
                      child: const Text('Only this button'),
                    ),
                  ),
                  const SizedBox(height: 120),
                  TextButton(
                    onPressed: () => outsideTaps += 1,
                    child: const Text('Unrelated button'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await container.read(guidedExperienceControllerProvider.notifier).startGuide(
          _guide(mode: GuideAdvanceMode.targetActivated),
          restart: true,
        );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Unrelated button'));
    await tester.pump();
    expect(outsideTaps, 0);
    expect(container.read(guidedExperienceControllerProvider).activeSession, isNotNull);

    await tester.tap(find.text('Only this button'));
    await tester.pump();
    expect(targetTaps, 1);
    expect(container.read(guidedExperienceControllerProvider).activeSession, isNull);
  });

}
