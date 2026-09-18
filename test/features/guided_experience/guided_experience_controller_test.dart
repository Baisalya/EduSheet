import 'package:edusheet/features/guided_experience/application/guided_experience_controller.dart';
import 'package:edusheet/features/guided_experience/domain/guide_definition.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress_repository.dart';
import 'package:edusheet/features/guided_experience/domain/guide_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryGuideProgressRepository implements GuideProgressRepository {
  _MemoryGuideProgressRepository([
    Map<GuideId, GuideProgress> initial = const <GuideId, GuideProgress>{},
  ]) : values = <GuideId, GuideProgress>{...initial};

  final Map<GuideId, GuideProgress> values;
  int saveCount = 0;

  @override
  Future<Map<GuideId, GuideProgress>> loadAll() async =>
      <GuideId, GuideProgress>{...values};

  @override
  Future<void> remove(GuideId guideId) async {
    values.remove(guideId);
  }

  @override
  Future<void> save(GuideProgress progress) async {
    saveCount += 1;
    values[progress.guideId] = progress;
  }
}

GuideDefinition _definition() {
  return GuideDefinition(
    id: GuideId.createPaper,
    version: 1,
    steps: const <GuideStep>[
      GuideStep(
        id: GuideStepId('start'),
        title: 'Start',
        message: 'Start the workflow.',
      ),
      GuideStep(
        id: GuideStepId('finish'),
        title: 'Finish',
        message: 'Finish the workflow.',
      ),
    ],
  );
}

void main() {
  test('guide can progress, go back, and complete without business state', () async {
    final repository = _MemoryGuideProgressRepository();
    final controller = GuidedExperienceController(repository);
    final definition = _definition();

    await controller.startGuide(definition);
    expect(controller.state.activeSession?.currentStepId, const GuideStepId('start'));
    expect(controller.state.activeDefinition, same(definition));
    expect(controller.state.activeStep?.id, const GuideStepId('start'));
    expect(
      controller.state.progressFor(GuideId.createPaper)?.status,
      GuideProgressStatus.inProgress,
    );

    await controller.advance();
    expect(
      controller.state.activeSession?.currentStepId,
      const GuideStepId('finish'),
    );
    expect(
      controller.state.progressFor(GuideId.createPaper)?.completedStepIds,
      contains(const GuideStepId('start')),
    );

    await controller.goBack();
    expect(controller.state.activeSession?.currentStepId, const GuideStepId('start'));

    await controller.advance();
    await controller.advance();

    final progress = controller.state.progressFor(GuideId.createPaper)!;
    expect(controller.state.activeSession, isNull);
    expect(controller.state.activeDefinition, isNull);
    expect(progress.status, GuideProgressStatus.completed);
    expect(progress.currentStepId, isNull);
    expect(progress.completedStepIds, containsAll(definition.stepIds));
    expect(progress.completedAt, isNotNull);
  });

  test('replay session does not replace already-completed persisted progress', () async {
    final originalProgress = GuideProgress(
      guideId: GuideId.createPaper,
      definitionVersion: 1,
      status: GuideProgressStatus.completed,
      completedStepIds: <GuideStepId>{
        const GuideStepId('start'),
        const GuideStepId('finish'),
      },
      completedAt: DateTime(2026, 9, 1),
    );
    final repository = _MemoryGuideProgressRepository(<GuideId, GuideProgress>{
      GuideId.createPaper: originalProgress,
    });
    final controller = GuidedExperienceController(repository);
    await controller.load();
    final savesBeforeReplay = repository.saveCount;

    await controller.startGuide(
      _definition(),
      mode: GuideSessionMode.replay,
      restart: true,
    );
    await controller.advance();
    await controller.advance();

    expect(controller.state.activeSession, isNull);
    expect(repository.saveCount, savesBeforeReplay);
    expect(
      controller.state.progressFor(GuideId.createPaper)?.status,
      GuideProgressStatus.completed,
    );
  });

  test('condition-satisfied steps advance only when the active step matches', () async {
    final repository = _MemoryGuideProgressRepository();
    final controller = GuidedExperienceController(repository);
    final definition = GuideDefinition(
      id: GuideId.createSyllabus,
      version: 1,
      steps: const <GuideStep>[
        GuideStep(
          id: GuideStepId('wait-for-real-state'),
          title: 'Wait',
          message: 'Wait for real state.',
          advanceMode: GuideAdvanceMode.conditionSatisfied,
        ),
        GuideStep(
          id: GuideStepId('after-real-state'),
          title: 'After',
          message: 'Real state changed.',
        ),
      ],
    );

    await controller.startGuide(definition, restart: true);
    await controller.notifyConditionSatisfied(const GuideStepId('wrong-step'));
    expect(
      controller.state.activeSession?.currentStepId,
      const GuideStepId('wait-for-real-state'),
    );

    await controller.notifyConditionSatisfied(
      const GuideStepId('wait-for-real-state'),
    );
    expect(
      controller.state.activeSession?.currentStepId,
      const GuideStepId('after-real-state'),
    );
  });

  test('replayGuide uses replay mode without mutating persisted progress', () async {
    final originalProgress = GuideProgress(
      guideId: GuideId.createPaper,
      status: GuideProgressStatus.completed,
      completedStepIds: <GuideStepId>{
        const GuideStepId('start'),
        const GuideStepId('finish'),
      },
    );
    final repository = _MemoryGuideProgressRepository(<GuideId, GuideProgress>{
      GuideId.createPaper: originalProgress,
    });
    final controller = GuidedExperienceController(repository);
    await controller.load();
    final savesBeforeReplay = repository.saveCount;

    await controller.replayGuide(_definition());

    expect(controller.state.activeSession?.mode, GuideSessionMode.replay);
    expect(controller.state.activeSession?.currentStepIndex, 0);
    expect(repository.saveCount, savesBeforeReplay);
  });

  test('guide can start at a real contextual step without changing definition order', () async {
    final repository = _MemoryGuideProgressRepository();
    final controller = GuidedExperienceController(repository);

    await controller.startGuide(
      _definition(),
      restart: true,
      startAtStepId: const GuideStepId('finish'),
    );

    expect(controller.state.activeSession?.currentStepIndex, 1);
    expect(
      controller.state.activeSession?.currentStepId,
      const GuideStepId('finish'),
    );
  });

  test('guide rejects a contextual start step outside the definition', () async {
    final repository = _MemoryGuideProgressRepository();
    final controller = GuidedExperienceController(repository);

    await expectLater(
      controller.startGuide(
        _definition(),
        startAtStepId: const GuideStepId('missing'),
      ),
      throwsArgumentError,
    );
  });

  test('demo sessions never persist or replace saved guide progress', () async {
    final repository = _MemoryGuideProgressRepository();
    final controller = GuidedExperienceController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.startGuide(
      _definition(),
      mode: GuideSessionMode.demo,
      restart: true,
    );
    await controller.advance();
    await controller.complete();

    expect(repository.saveCount, 0);
    expect(repository.values, isEmpty);
    expect(controller.state.progressByGuide, isEmpty);
  });
}
