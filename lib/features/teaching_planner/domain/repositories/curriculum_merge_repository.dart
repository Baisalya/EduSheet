import '../models/curriculum_merge_state.dart';
import '../models/teaching_planner_workspace.dart';

typedef CurriculumAwarePlannerMutation =
    TeachingPlannerWorkspace Function(
      TeachingPlannerWorkspace workspace,
      CurriculumMergeState mergeState,
    );

class CurriculumMergeRepositorySnapshot {
  final TeachingPlannerWorkspace workspace;
  final CurriculumMergeState mergeState;
  final int localRevision;

  const CurriculumMergeRepositorySnapshot({
    required this.workspace,
    required this.mergeState,
    required this.localRevision,
  });
}

/// Optional repository capability used by curriculum `.eds` imports.
///
/// [commitCurriculumMerge] is compare-and-set: it must reject the write when
/// the planner changed after [loadCurriculumMergeSnapshot].
abstract interface class CurriculumMergeRepository {
  Future<CurriculumMergeRepositorySnapshot> loadCurriculumMergeSnapshot();

  /// Atomically applies a normal planner mutation while exposing the current
  /// curriculum replica sidecar. This is used by the Master/Teacher layer
  /// policy so an entity cannot become official between a preflight check and
  /// the persisted write.
  Future<TeachingPlannerWorkspace> updateCurriculumAware(
    CurriculumAwarePlannerMutation mutation,
  );

  Future<CurriculumMergeRepositorySnapshot> commitCurriculumMerge({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required int expectedLocalRevision,
  });

  /// Full planner replacement used by backup restore. New v4 backups can
  /// transport replica mappings; legacy backups pass an empty state.
  Future<void> replaceWorkspaceWithMergeState(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
  );

  Future<void> replaceWorkspaceAndResetMergeState(
    TeachingPlannerWorkspace workspace,
  );
}
