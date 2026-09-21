import '../domain/models/offline_sync_change_set.dart';
import '../domain/models/offline_sync_state.dart';
import '../domain/repositories/offline_sync_repository.dart';
import '../domain/repositories/teaching_planner_repository.dart';

class OfflineSyncContractUnavailable implements Exception {
  const OfflineSyncContractUnavailable();

  @override
  String toString() =>
      'OfflineSyncContractUnavailable: This planner repository does not expose the local sync contract.';
}

class OfflineSyncContractSummary {
  final String replicaId;
  final int pendingCount;
  final int conflictCount;
  final int tombstoneCount;
  final int appliedInboundCount;

  const OfflineSyncContractSummary({
    required this.replicaId,
    required this.pendingCount,
    required this.conflictCount,
    required this.tombstoneCount,
    required this.appliedInboundCount,
  });
}

/// Phase 9 local-only facade. It intentionally performs no HTTP, sockets,
/// authentication, background polling, or cloud writes.
class OfflineSyncContractService {
  OfflineSyncContractService(this._plannerRepository);

  final TeachingPlannerRepository _plannerRepository;

  OfflineSyncRepository get _repository {
    final repository = _plannerRepository;
    return switch (repository) {
      OfflineSyncRepository value => value,
      _ => throw const OfflineSyncContractUnavailable(),
    };
  }

  Future<OfflineSyncContractSummary> summary() async {
    final state = (await _repository.loadOfflineSyncSnapshot()).syncState;
    return OfflineSyncContractSummary(
      replicaId: state.replicaId,
      pendingCount: state.pendingOutbound.length,
      conflictCount: state.conflicts.length,
      tombstoneCount: state.entityClocks.where((item) => item.isDeleted).length,
      appliedInboundCount: state.appliedInboundChangeIds.length,
    );
  }

  Future<OfflineSyncChangeSet?> createOutboundBatch({int maxChanges = 200}) =>
      _repository.buildPendingChangeSet(maxChanges: maxChanges);

  Future<void> acknowledge(OfflineSyncChangeSet changeSet) =>
      _repository.acknowledgeOutboundChangeSet(changeSet);

  Future<void> recordInboundOutcome({
    required OfflineSyncChangeSet changeSet,
    Set<String> conflictChangeIds = const {},
    Map<String, String> conflictReasons = const {},
  }) => _repository.recordInboundChangeSetOutcome(
    changeSet: changeSet,
    conflictChangeIds: conflictChangeIds,
    conflictReasons: conflictReasons,
  );

  Future<OfflineSyncState> loadState() async =>
      (await _repository.loadOfflineSyncSnapshot()).syncState;
}
