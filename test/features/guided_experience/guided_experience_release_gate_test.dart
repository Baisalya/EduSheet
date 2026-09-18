import 'package:edusheet/features/guided_experience/application/guide_catalog_providers.dart';
import 'package:edusheet/features/guided_experience/demo/guided_demo_session.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release catalog exposes both completed real-control guides exactly once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final catalog = container.read(guideCatalogProvider);
    final ids = catalog.map((entry) => entry.definition.id).toList();

    expect(catalog, hasLength(2));
    expect(ids, contains(GuideId.createPaper));
    expect(ids, contains(GuideId.createSyllabus));
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('release guides have stable unique targets for every shipped step', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final entry in container.read(guideCatalogProvider)) {
      final steps = entry.definition.steps;
      final targets = steps.map((step) => step.targetId).toList();

      expect(
        targets.every((target) => target != null),
        isTrue,
        reason: '${entry.title} contains a shipped step without a real target.',
      );
      expect(
        targets.whereType<GuideTargetId>().toSet(),
        hasLength(steps.length),
        reason: '${entry.title} reuses a target across multiple release steps.',
      );
    }
  });

  test('release demo surface stays limited to the two isolated shipped features', () {
    expect(
      GuidedDemoFeature.values,
      <GuidedDemoFeature>[
        GuidedDemoFeature.createPaper,
        GuidedDemoFeature.createSyllabus,
      ],
    );
  });
}
