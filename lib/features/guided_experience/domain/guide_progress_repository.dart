import 'guide_ids.dart';
import 'guide_progress.dart';

abstract interface class GuideProgressRepository {
  Future<Map<GuideId, GuideProgress>> loadAll();

  Future<void> save(GuideProgress progress);

  Future<void> remove(GuideId guideId);
}
