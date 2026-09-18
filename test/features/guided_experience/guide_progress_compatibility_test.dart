import 'package:edusheet/features/guided_experience/domain/guide_ids.dart';
import 'package:edusheet/features/guided_experience/domain/guide_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide progress JSON preserves completion timestamp and step state', () {
    final completedAt = DateTime.utc(2026, 9, 16, 12, 30);
    final progress = GuideProgress(
      guideId: const GuideId('compat-guide'),
      definitionVersion: 2,
      status: GuideProgressStatus.completed,
      completedStepIds: <GuideStepId>{const GuideStepId('one')},
      completedAt: completedAt,
    );

    final restored = GuideProgress.fromJson(progress.toJson());
    expect(restored.guideId, progress.guideId);
    expect(restored.definitionVersion, 2);
    expect(restored.status, GuideProgressStatus.completed);
    expect(restored.completedStepIds, progress.completedStepIds);
    expect(restored.completedAt?.isAtSameMomentAs(completedAt), isTrue);
  });
}
