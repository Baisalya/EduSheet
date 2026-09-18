import '../../teaching_planner/domain/models/teaching_planner_workspace.dart';
import '../../teaching_planner/domain/repositories/teaching_planner_repository.dart';

/// Ephemeral Teaching Planner repository for Create Syllabus demo sessions.
///
/// The same repository interface and business service are used as production,
/// but every mutation stays in memory and is discarded when a demo restarts.
class InMemoryTeachingPlannerRepository
    implements TeachingPlannerRepository {
  TeachingPlannerWorkspace _workspace = TeachingPlannerWorkspace.empty();

  void reset() {
    _workspace = TeachingPlannerWorkspace.empty();
  }

  @override
  Future<TeachingPlannerWorkspace> load() async => _copy(_workspace);

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    _workspace = _copy(workspace);
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    final next = mutation(_copy(_workspace));
    _workspace = _copy(next);
    return _copy(_workspace);
  }

  TeachingPlannerWorkspace _copy(TeachingPlannerWorkspace workspace) {
    return TeachingPlannerWorkspace.fromJson(workspace.toJson());
  }
}
