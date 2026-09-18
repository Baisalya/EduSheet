import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_controller.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_providers.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_session.dart';
import 'package:edusheet/features/guided_experience/demo/in_memory_paper_repository.dart';
import 'package:edusheet/features/guided_experience/demo/in_memory_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Create Paper demo routes writes only to the in-memory repository', () async {
    final production = InMemoryPaperRepository();
    final demo = InMemoryPaperRepository();
    final original = Paper(
      id: 'real-paper',
      title: 'Real paper',
      createdAt: DateTime.utc(2026, 9, 16),
    );
    await production.savePaper(original);
    final before = (await production.getAllPapers())
        .map((paper) => paper.toJson())
        .toList();

    final container = ProviderContainer(
      overrides: [
        productionPaperRepositoryProvider.overrideWithValue(production),
        demoPaperRepositoryProvider.overrideWithValue(demo),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(paperRepositoryProvider), same(production));

    container
        .read(guidedDemoControllerProvider.notifier)
        .start(GuidedDemoFeature.createPaper);
    expect(container.read(paperRepositoryProvider), same(demo));

    await container.read(paperRepositoryProvider).savePaper(
      Paper(
        id: 'demo-paper',
        title: 'Demo only',
        createdAt: DateTime.utc(2026, 9, 16),
      ),
    );

    container.read(guidedDemoControllerProvider.notifier).stop();
    expect(container.read(paperRepositoryProvider), same(production));
    expect(
      (await production.getAllPapers()).map((paper) => paper.toJson()).toList(),
      before,
    );
    expect((await demo.getAllPapers()).single.title, 'Demo only');
  });

  test('Create Syllabus demo leaves production workspace unchanged', () async {
    final now = DateTime.utc(2026, 9, 16);
    final production = InMemoryTeachingPlannerRepository();
    final demo = InMemoryTeachingPlannerRepository();
    final originalWorkspace = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'real-class',
          name: 'Real Class',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await production.save(originalWorkspace);
    final before = (await production.load()).toJson();

    final container = ProviderContainer(
      overrides: [
        productionTeachingPlannerRepositoryProvider.overrideWithValue(
          production,
        ),
        demoTeachingPlannerRepositoryProvider.overrideWithValue(demo),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(teachingPlannerRepositoryProvider), same(production));

    container
        .read(guidedDemoControllerProvider.notifier)
        .start(GuidedDemoFeature.createSyllabus);
    expect(container.read(teachingPlannerRepositoryProvider), same(demo));

    await container.read(teachingPlannerRepositoryProvider).save(
      TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'demo-class',
            name: 'Demo Class',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );

    container.read(guidedDemoControllerProvider.notifier).stop();
    expect(container.read(teachingPlannerRepositoryProvider), same(production));
    expect((await production.load()).toJson(), before);
    expect((await demo.load()).classes.single.name, 'Demo Class');
  });

  test('paper and syllabus demo routing is feature-specific', () {
    final productionPaper = InMemoryPaperRepository();
    final demoPaper = InMemoryPaperRepository();
    final productionPlanner = InMemoryTeachingPlannerRepository();
    final demoPlanner = InMemoryTeachingPlannerRepository();
    final container = ProviderContainer(
      overrides: [
        productionPaperRepositoryProvider.overrideWithValue(productionPaper),
        demoPaperRepositoryProvider.overrideWithValue(demoPaper),
        productionTeachingPlannerRepositoryProvider.overrideWithValue(
          productionPlanner,
        ),
        demoTeachingPlannerRepositoryProvider.overrideWithValue(demoPlanner),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(guidedDemoControllerProvider.notifier)
        .start(GuidedDemoFeature.createPaper);
    expect(container.read(paperRepositoryProvider), same(demoPaper));
    expect(
      container.read(teachingPlannerRepositoryProvider),
      same(productionPlanner),
    );

    container
        .read(guidedDemoControllerProvider.notifier)
        .start(GuidedDemoFeature.createSyllabus);
    expect(container.read(paperRepositoryProvider), same(productionPaper));
    expect(container.read(teachingPlannerRepositoryProvider), same(demoPlanner));
  });

  test(
    'Create Paper demo does not persist an untouched new paper',
    () async {
      final production = InMemoryPaperRepository();
      final demo = InMemoryPaperRepository();
      final container = ProviderContainer(
        overrides: [
          productionPaperRepositoryProvider.overrideWithValue(production),
          demoPaperRepositoryProvider.overrideWithValue(demo),
        ],
      );
      addTearDown(container.dispose);

      final editor = container.read(editorStateProvider.notifier);
      final originalId = container.read(editorStateProvider).id;
      final snapshot = await editor.enterDemoIsolation(demo);

      expect(snapshot.currentDocumentPersisted, isFalse);
      expect(await production.getAllPapers(), isEmpty);

      await editor.exitDemoIsolation(snapshot, production);
      expect(container.read(editorStateProvider).id, originalId);
      expect(await production.getAllPapers(), isEmpty);
    },
  );

  test('Create Paper demo restores the pre-demo editor draft on exit', () async {
    final production = InMemoryPaperRepository();
    final demo = InMemoryPaperRepository();
    final container = ProviderContainer(
      overrides: [
        productionPaperRepositoryProvider.overrideWithValue(production),
        demoPaperRepositoryProvider.overrideWithValue(demo),
      ],
    );
    addTearDown(container.dispose);

    final realEditor = container.read(editorStateProvider.notifier);
    realEditor.updateTitle('Unsaved real draft');
    final snapshot = await realEditor.enterDemoIsolation(demo);
    expect(snapshot.currentDocumentPersisted, isTrue);
    final productionBeforeDemo = await production.getAllPapers();
    expect(productionBeforeDemo, hasLength(1));
    expect(productionBeforeDemo.single.title, 'Unsaved real draft');

    container
        .read(guidedDemoControllerProvider.notifier)
        .start(GuidedDemoFeature.createPaper);

    final demoEditor = container.read(editorStateProvider.notifier);
    expect(demoEditor, same(realEditor));
    demoEditor.updateTitle('Demo paper title');
    await demoEditor.savePaper();

    final productionDuringDemo = await production.getAllPapers();
    expect(productionDuringDemo, hasLength(1));
    expect(productionDuringDemo.single.title, 'Unsaved real draft');
    expect((await demo.getAllPapers()).single.title, 'Demo paper title');

    container.read(guidedDemoControllerProvider.notifier).stop();
    await demoEditor.exitDemoIsolation(snapshot, production);

    expect(container.read(editorStateProvider).title, 'Unsaved real draft');
    await container.read(editorStateProvider.notifier).savePaper();
    final realPapers = await production.getAllPapers();
    expect(realPapers, hasLength(1));
    expect(realPapers.single.title, 'Unsaved real draft');
    expect(realPapers.single.title, isNot('Demo paper title'));
  });
}
