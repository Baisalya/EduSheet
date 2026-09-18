import 'dart:convert';

import 'package:edusheet/features/guided_experience/data/shared_preferences_guide_progress_repository.dart';
import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists only guide metadata in SharedPreferences', () async {
    final repository = SharedPreferencesGuideProgressRepository();
    final progress = GuideProgress(
      guideId: GuideId.createSyllabus,
      definitionVersion: 2,
      status: GuideProgressStatus.inProgress,
      currentStepId: const GuideStepId('add-subject'),
      completedStepIds: <GuideStepId>{const GuideStepId('create-class')},
    );

    await repository.save(progress);
    final loaded = await repository.loadAll();

    expect(loaded[GuideId.createSyllabus]?.definitionVersion, 2);
    expect(
      loaded[GuideId.createSyllabus]?.currentStepId,
      const GuideStepId('add-subject'),
    );
    expect(
      loaded[GuideId.createSyllabus]?.completedStepIds,
      contains(const GuideStepId('create-class')),
    );
  });

  test('malformed guide metadata is ignored without affecting other entries', () async {
    final valid = GuideProgress(
      guideId: GuideId.createPaper,
      status: GuideProgressStatus.completed,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'guided_experience.progress.create_paper': jsonEncode(valid.toJson()),
      'guided_experience.progress.broken': '{broken-json',
    });

    final repository = SharedPreferencesGuideProgressRepository();
    final loaded = await repository.loadAll();

    expect(loaded.length, 1);
    expect(loaded[GuideId.createPaper]?.status, GuideProgressStatus.completed);
  });
}
