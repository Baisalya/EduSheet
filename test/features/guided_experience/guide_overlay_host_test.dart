import 'package:edusheet/core/navigation/windows_escape_back_scope.dart';
import 'package:edusheet/features/guided_experience/application/guided_experience_providers.dart';
import 'package:edusheet/features/guided_experience/domain/guide_definition.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress_repository.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_anchor.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guide_overlay_host.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/guided_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryGuideProgressRepository implements GuideProgressRepository {
  final Map<GuideId, GuideProgress> _values = <GuideId, GuideProgress>{};

  @override
  Future<Map<GuideId, GuideProgress>> loadAll() async =>
      <GuideId, GuideProgress>{..._values};

  @override
  Future<void> remove(GuideId guideId) async {
    _values.remove(guideId);
  }

  @override
  Future<void> save(GuideProgress progress) async {
    _values[progress.guideId] = progress;
  }
}

const _targetId = GuideTargetId('real-action');

GuideDefinition _targetGuide() {
  return GuideDefinition(
    id: GuideId.createPaper,
    version: 1,
    steps: const <GuideStep>[
      GuideStep(
        id: GuideStepId('real-action-step'),
        title: 'Use the real action',
        message: 'Click the highlighted application control.',
        targetId: _targetId,
        advanceMode: GuideAdvanceMode.targetActivated,
      ),
      GuideStep(
        id: GuideStepId('finish-step'),
        title: 'Finished action',
        message: 'The real control was activated.',
      ),
    ],
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        guideProgressRepositoryProvider.overrideWithValue(
          _MemoryGuideProgressRepository(),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<GlobalKey<NavigatorState>> pumpApp(
    WidgetTester tester, {
    required VoidCallback onRealAction,
    VoidCallback? onOutsideAction,
    bool reduceMotion = false,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: WindowsEscapeBackScope(
              enabled: true,
              navigatorKey: navigatorKey,
              child: GuideOverlayHost(child: child!),
            ),
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, 0.55),
                  child: GuideAnchor(
                    targetId: _targetId,
                    reportPointerActivation: true,
                    child: FilledButton(
                      onPressed: onRealAction,
                      child: const Text('Real action'),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.85, -0.85),
                  child: FilledButton(
                    onPressed: onOutsideAction,
                    child: const Text('Outside action'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('spotlight keeps real target clickable and advances afterward', (
    tester,
  ) async {
    var realActionCount = 0;
    await pumpApp(tester, onRealAction: () => realActionCount += 1);

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(_targetGuide(), restart: true);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Use the real action'), findsOneWidget);
    expect(find.byType(GuidedHelper), findsOneWidget);

    await tester.tap(find.text('Real action'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(realActionCount, 1);
    expect(find.text('Finished action'), findsOneWidget);
  });

  testWidgets('spotlight absorbs application taps outside the highlighted target', (
    tester,
  ) async {
    var realActionCount = 0;
    var outsideActionCount = 0;
    await pumpApp(
      tester,
      onRealAction: () => realActionCount += 1,
      onOutsideAction: () => outsideActionCount += 1,
    );

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(_targetGuide(), restart: true);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tapAt(tester.getCenter(find.text('Outside action')));
    await tester.pump();

    expect(outsideActionCount, 0);
    expect(realActionCount, 0);
    expect(find.text('Use the real action'), findsOneWidget);
  });

  testWidgets('reduced-motion preference replaces animation with static helper', (
    tester,
  ) async {
    await pumpApp(
      tester,
      reduceMotion: true,
      onRealAction: () {},
    );

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(_targetGuide(), restart: true);
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
  });

  testWidgets('Escape stops the guide before Navigator back handling', (
    tester,
  ) async {
    final navigatorKey = await pumpApp(tester, onRealAction: () {});
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('child-page')),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(
          GuideDefinition(
            id: GuideId.createSyllabus,
            version: 1,
            steps: const <GuideStep>[
              GuideStep(
                id: GuideStepId('manual'),
                title: 'Guide open',
                message: 'This guide should close first.',
              ),
            ],
          ),
          restart: true,
        );
    await tester.pump(const Duration(milliseconds: 20));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      container.read(guidedExperienceControllerProvider).activeSession,
      isNull,
    );
    expect(find.text('child-page'), findsOneWidget);
  });

  testWidgets('helper geometry is recalculated after a free-form window resize', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, onRealAction: () {});

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(_targetGuide(), restart: true);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    final before = tester.getTopLeft(find.byType(GuidedHelper));

    await tester.binding.setSurfaceSize(const Size(520, 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final after = tester.getTopLeft(find.byType(GuidedHelper));

    expect(after, isNot(before));
    expect(after.dx, inInclusiveRange(0, 520));
    expect(after.dy, inInclusiveRange(0, 900));
  });

  testWidgets('off-screen target is brought into view before spotlighting', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.binding.setSurfaceSize(const Size(600, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => GuideOverlayHost(child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 1100),
                  GuideAnchor(
                    targetId: _targetId,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Far target'),
                    ),
                  ),
                  const SizedBox(height: 300),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getCenter(find.text('Far target')).dy, greaterThan(600));

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(
          GuideDefinition(
            id: GuideId.createPaper,
            version: 1,
            steps: const <GuideStep>[
              GuideStep(
                id: GuideStepId('far-target'),
                title: 'Far target guide',
                message: 'Bring the real control into view.',
                targetId: _targetId,
              ),
            ],
          ),
          restart: true,
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 20));

    expect(tester.getCenter(find.text('Far target')).dy, lessThan(600));
    expect(find.text('Far target guide'), findsOneWidget);
  });


  testWidgets('manual coach supports Next, Back, Done and Skip controls', (
    tester,
  ) async {
    await pumpApp(tester, onRealAction: () {});
    final definition = GuideDefinition(
      id: GuideId.createSyllabus,
      version: 1,
      steps: const <GuideStep>[
        GuideStep(
          id: GuideStepId('manual-one'),
          title: 'Manual one',
          message: 'First manual step.',
        ),
        GuideStep(
          id: GuideStepId('manual-two'),
          title: 'Manual two',
          message: 'Second manual step.',
        ),
      ],
    );

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(definition, restart: true);
    await tester.pump();

    expect(find.text('Manual one'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Manual two'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Manual one'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(container.read(guidedExperienceControllerProvider).activeSession, isNull);

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(definition, restart: true);
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(container.read(guidedExperienceControllerProvider).activeSession, isNull);
  });


  testWidgets('missing target stays recoverable and resumes when target appears', (
    tester,
  ) async {
    var showTarget = false;
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => GuideOverlayHost(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: showTarget
                    ? GuideAnchor(
                        targetId: _targetId,
                        child: FilledButton(
                          onPressed: () {},
                          child: const Text('Appeared target'),
                        ),
                      )
                    : FilledButton(
                        onPressed: () => setState(() => showTarget = true),
                        child: const Text('Reveal target'),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(_targetGuide(), restart: true);
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Waiting for this control to become available.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reveal target'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Appeared target'), findsOneWidget);
    expect(find.byType(GuidedHelper), findsOneWidget);
  });

  testWidgets('informational spotlight can allow nearby real interaction', (
    tester,
  ) async {
    var outsideActionCount = 0;
    await pumpApp(
      tester,
      onRealAction: () {},
      onOutsideAction: () => outsideActionCount += 1,
    );

    await container
        .read(guidedExperienceControllerProvider.notifier)
        .startGuide(
          GuideDefinition(
            id: GuideId.createPaper,
            version: 1,
            steps: const <GuideStep>[
              GuideStep(
                id: GuideStepId('inspect-with-context'),
                title: 'Inspect nearby controls',
                message: 'The spotlight is informational.',
                targetId: _targetId,
                allowOutsideInteraction: true,
              ),
            ],
          ),
          restart: true,
        );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Outside action'));
    await tester.pump();

    expect(outsideActionCount, 1);
    expect(find.text('Inspect nearby controls'), findsOneWidget);
  });

}
