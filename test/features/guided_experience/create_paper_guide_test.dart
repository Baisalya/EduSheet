import 'package:edusheet/features/guided_experience/application/guide_catalog_providers.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/domain/guide_definition.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/guides/create_paper_guide.dart';
import 'package:edusheet/features/guided_experience/guides/create_syllabus_guide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Create Paper guide follows the real workflow in order', () {
    final guide = createPaperGuideDefinition;

    expect(guide.id, GuideId.createPaper);
    expect(guide.version, 1);
    expect(guide.steps, hasLength(13));
    expect(guide.stepIds, <GuideStepId>[
      CreatePaperGuideSteps.openCreatePaper,
      CreatePaperGuideSteps.openPaperSetup,
      CreatePaperGuideSteps.reviewPaperSetup,
      CreatePaperGuideSteps.savePaperSetup,
      CreatePaperGuideSteps.writeFirstQuestion,
      CreatePaperGuideSteps.typeQuestion,
      CreatePaperGuideSteps.authoringTools,
      CreatePaperGuideSteps.saveQuestion,
      CreatePaperGuideSteps.questionBank,
      CreatePaperGuideSteps.openPreview,
      CreatePaperGuideSteps.reviewPreview,
      CreatePaperGuideSteps.returnFromPreview,
      CreatePaperGuideSteps.outputPaper,
    ]);
  });

  test('real actions and validation-backed actions use the correct progression', () {
    final byId = <GuideStepId, GuideStep>{
      for (final step in createPaperGuideDefinition.steps) step.id: step,
    };

    expect(
      byId[CreatePaperGuideSteps.openCreatePaper]?.advanceMode,
      GuideAdvanceMode.targetActivated,
    );
    expect(
      byId[CreatePaperGuideSteps.openPaperSetup]?.advanceMode,
      GuideAdvanceMode.targetActivated,
    );
    expect(
      byId[CreatePaperGuideSteps.writeFirstQuestion]?.advanceMode,
      GuideAdvanceMode.targetActivated,
    );
    expect(
      byId[CreatePaperGuideSteps.openPreview]?.advanceMode,
      GuideAdvanceMode.targetActivated,
    );
    expect(
      byId[CreatePaperGuideSteps.returnFromPreview]?.advanceMode,
      GuideAdvanceMode.targetActivated,
    );

    expect(
      byId[CreatePaperGuideSteps.savePaperSetup]?.advanceMode,
      GuideAdvanceMode.conditionSatisfied,
    );
    expect(
      byId[CreatePaperGuideSteps.typeQuestion]?.advanceMode,
      GuideAdvanceMode.conditionSatisfied,
    );
    expect(
      byId[CreatePaperGuideSteps.saveQuestion]?.advanceMode,
      GuideAdvanceMode.conditionSatisfied,
    );
  });

  test('optional inspection steps allow the real surrounding UI to stay usable', () {
    final byId = <GuideStepId, GuideStep>{
      for (final step in createPaperGuideDefinition.steps) step.id: step,
    };

    for (final stepId in <GuideStepId>[
      CreatePaperGuideSteps.savePaperSetup,
      CreatePaperGuideSteps.authoringTools,
      CreatePaperGuideSteps.saveQuestion,
      CreatePaperGuideSteps.questionBank,
      CreatePaperGuideSteps.outputPaper,
    ]) {
      expect(byId[stepId]?.allowOutsideInteraction, isTrue);
    }

    expect(
      byId[CreatePaperGuideSteps.reviewPaperSetup]?.allowOutsideInteraction,
      isFalse,
    );
    expect(
      byId[CreatePaperGuideSteps.reviewPreview]?.allowOutsideInteraction,
      isFalse,
    );
  });

  test('contextual suggestion is scoped to first-time incomplete Create Paper', () {
    expect(
      createPaperContextualSuggestion.screen,
      GuidedScreenContext.createPaper,
    );
    expect(createPaperContextualSuggestion.requiresIncompleteAction, isTrue);
    expect(createPaperContextualSuggestion.requiresFirstTimeUse, isTrue);
    expect(
      createPaperContextualSuggestion.minimumInactivity,
      const Duration(minutes: 1),
    );
  });

  test('Settings catalog exposes completed Create Paper and Create Syllabus guides', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final catalog = container.read(guideCatalogProvider);

    expect(catalog, hasLength(2));
    expect(catalog[0].definition, same(createPaperGuideDefinition));
    expect(catalog[0].definition.id, GuideId.createPaper);
    expect(catalog[1].definition, same(createSyllabusGuideDefinition));
    expect(catalog[1].definition.id, GuideId.createSyllabus);
  });
}
