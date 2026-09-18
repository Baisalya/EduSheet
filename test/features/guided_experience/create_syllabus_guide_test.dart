import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/domain/guide_definition.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/guides/create_syllabus_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Create Syllabus guide follows the real Teaching Planner workflow', () {
    final guide = createSyllabusGuideDefinition;

    expect(guide.id, GuideId.createSyllabus);
    expect(guide.version, 1);
    expect(guide.steps, hasLength(13));
    expect(guide.stepIds, <GuideStepId>[
      CreateSyllabusGuideSteps.openTeachingPlanner,
      CreateSyllabusGuideSteps.openClassSetup,
      CreateSyllabusGuideSteps.saveClass,
      CreateSyllabusGuideSteps.openSyllabus,
      CreateSyllabusGuideSteps.openCreateSyllabus,
      CreateSyllabusGuideSteps.saveCreateSyllabus,
      CreateSyllabusGuideSteps.openSubject,
      CreateSyllabusGuideSteps.saveSubject,
      CreateSyllabusGuideSteps.openChapter,
      CreateSyllabusGuideSteps.saveChapter,
      CreateSyllabusGuideSteps.optionalStructure,
      CreateSyllabusGuideSteps.manageSyllabus,
      CreateSyllabusGuideSteps.finishSetup,
    ]);
  });

  test('real open controls and validation-backed saves use separate progression', () {
    final byId = <GuideStepId, GuideStep>{
      for (final step in createSyllabusGuideDefinition.steps) step.id: step,
    };

    for (final stepId in <GuideStepId>[
      CreateSyllabusGuideSteps.openTeachingPlanner,
      CreateSyllabusGuideSteps.openClassSetup,
      CreateSyllabusGuideSteps.openSyllabus,
      CreateSyllabusGuideSteps.openCreateSyllabus,
      CreateSyllabusGuideSteps.openSubject,
      CreateSyllabusGuideSteps.openChapter,
    ]) {
      expect(byId[stepId]?.advanceMode, GuideAdvanceMode.targetActivated);
    }

    for (final stepId in <GuideStepId>[
      CreateSyllabusGuideSteps.saveClass,
      CreateSyllabusGuideSteps.saveCreateSyllabus,
      CreateSyllabusGuideSteps.saveSubject,
      CreateSyllabusGuideSteps.saveChapter,
      CreateSyllabusGuideSteps.finishSetup,
    ]) {
      expect(byId[stepId]?.advanceMode, GuideAdvanceMode.conditionSatisfied);
      expect(byId[stepId]?.allowOutsideInteraction, isTrue);
    }
  });

  test('units and topics stay optional in the guide', () {
    final optional = createSyllabusGuideDefinition.steps.singleWhere(
      (step) => step.id == CreateSyllabusGuideSteps.optionalStructure,
    );
    expect(optional.advanceMode, GuideAdvanceMode.manual);
    expect(optional.allowOutsideInteraction, isTrue);
    expect(optional.message, contains('optional'));
  });

  test('syllabus contextual suggestion is scoped to first-time incomplete use', () {
    expect(
      createSyllabusContextualSuggestion.screen,
      GuidedScreenContext.syllabus,
    );
    expect(createSyllabusContextualSuggestion.requiresIncompleteAction, isTrue);
    expect(createSyllabusContextualSuggestion.requiresFirstTimeUse, isTrue);
    expect(
      createSyllabusContextualSuggestion.minimumInactivity,
      const Duration(minutes: 1),
    );
  });
}
