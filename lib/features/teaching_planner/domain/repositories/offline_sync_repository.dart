import '../models/curriculum_merge_state.dart';
import '../models/offline_sync_change_set.dart';
import '../models/offline_sync_state.dart';
import '../models/teaching_planner_workspace.dart';

class OfflineSyncRepositorySnapshot {
  final TeachingPlannerWorkspace workspace;
  final CurriculumMergeState mergeState;
  final OfflineSyncState syncState;
  final int localRevision;

  const OfflineSyncRepositorySnapshot({
    required this.workspace,
    required this.mergeState,
    required this.syncState,
    required this.localRevision,
  });
}

/// Local-only Phase 9 capability. No network is performed here.
abstract interface class OfflineSyncRepository {
  Future<OfflineSyncRepositorySnapshot> loadOfflineSyncSnapshot();

  Future<OfflineSyncChangeSet?> buildPendingChangeSet({int maxChanges = 200});

  Future<void> acknowledgeOutboundChangeSet(OfflineSyncChangeSet changeSet);

  Future<void> recordInboundChangeSetOutcome({
    required OfflineSyncChangeSet changeSet,
    Set<String> conflictChangeIds = const {},
    Map<String, String> conflictReasons = const {},
  });

  Future<void> replaceWorkspaceWithSyncMetadata({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required OfflineSyncState syncState,
  });
}
