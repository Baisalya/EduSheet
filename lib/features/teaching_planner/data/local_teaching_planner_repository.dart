import 'dart:io';

import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/offline_sync_change_set.dart';
import '../domain/models/offline_sync_state.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/repositories/curriculum_merge_repository.dart';
import '../domain/repositories/offline_sync_repository.dart';
import '../domain/repositories/teaching_planner_repository.dart';
import 'teaching_planner_document_codec.dart';

class TeachingPlannerRepositoryException implements Exception {
  final String message;
  final Object? cause;

  const TeachingPlannerRepositoryException(this.message, {this.cause});

  @override
  String toString() => 'TeachingPlannerRepositoryException: $message';
}

class LocalTeachingPlannerRepository
    implements
        TeachingPlannerRepository,
        CurriculumMergeRepository,
        OfflineSyncRepository {
  static const String fileName = 'teaching_planner.json';

  final Future<File> Function() _fileResolver;
  final TeachingPlannerDocumentCodec _codec;
  final OfflineSyncTracker _syncTracker;
  final String Function() _syncReplicaIdGenerator;
  final DateTime Function() _clock;
  final SerializedOperationQueue _operations = SerializedOperationQueue();

  LocalTeachingPlannerRepository({
    Future<File> Function()? fileResolver,
    TeachingPlannerDocumentCodec codec = const TeachingPlannerDocumentCodec(),
    OfflineSyncTracker syncTracker = const OfflineSyncTracker(),
    String Function()? syncReplicaIdGenerator,
    DateTime Function()? clock,
  }) : _fileResolver = fileResolver ?? _defaultFile,
       _codec = codec,
       _syncTracker = syncTracker,
       _syncReplicaIdGenerator =
           syncReplicaIdGenerator ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  Future<TeachingPlannerStoredDocument> _loadStored() async {
    final store = await _store();
    final decoded = await store.readJson(orElse: _codec.emptyDocument());
    try {
      return _codec.decodeStored(decoded);
    } catch (primaryError) {
      if (!await store.backupFile.exists()) {
        throw TeachingPlannerRepositoryException(
          'Teaching Planner data is malformed or incompatible.',
          cause: primaryError,
        );
      }

      try {
        final backupStore = AtomicJsonFileStore(store.backupFile);
        final backup = await backupStore.readJson(
          orElse: _codec.emptyDocument(),
        );
        return _codec.decodeStored(backup);
      } catch (backupError) {
        throw TeachingPlannerRepositoryException(
          'Teaching Planner primary and backup data are both unusable.',
          cause: [primaryError, backupError],
        );
      }
    }
  }

  TeachingPlannerStoredDocument _initializeSync(
    TeachingPlannerStoredDocument document,
  ) {
    if (document.syncState.isInitialized) return document;
    return document.copyWith(
      syncState: _syncTracker.initialize(
        state: document.syncState,
        replicaId: _syncReplicaIdGenerator(),
      ),
    );
  }

  OfflineSyncState _recordLocalMutation({
    required TeachingPlannerStoredDocument current,
    required TeachingPlannerWorkspace nextWorkspace,
    required CurriculumMergeState nextMergeState,
  }) {
    final initialized = _initializeSync(current);
    return _syncTracker.recordLocalDiff(
      before: initialized.workspace,
      after: nextWorkspace,
      beforeMergeState: initialized.mergeState,
      afterMergeState: nextMergeState,
      state: initialized.syncState,
      changedAt: _clock(),
    );
  }

  @override
  Future<TeachingPlannerWorkspace> load() async =>
      (await _loadStored()).workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      final syncState = _recordLocalMutation(
        current: current,
        nextWorkspace: workspace,
        nextMergeState: current.mergeState,
      );
      await _writeStored(
        current.copyWith(
          workspace: workspace,
          syncState: syncState,
          localRevision: current.localRevision + 1,
        ),
      );
    });
  }

  @override
  Future<TeachingPlannerWorkspace> update(TeachingPlannerMutation mutation) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      final nextWorkspace = mutation(current.workspace);
      final syncState = _recordLocalMutation(
        current: current,
        nextWorkspace: nextWorkspace,
        nextMergeState: current.mergeState,
      );
      final next = current.copyWith(
        workspace: nextWorkspace,
        syncState: syncState,
        localRevision: current.localRevision + 1,
      );
      await _writeStored(next);
      return nextWorkspace;
    });
  }

  @override
  Future<TeachingPlannerWorkspace> updateCurriculumAware(
    CurriculumAwarePlannerMutation mutation,
  ) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      final nextWorkspace = mutation(current.workspace, current.mergeState);
      final syncState = _recordLocalMutation(
        current: current,
        nextWorkspace: nextWorkspace,
        nextMergeState: current.mergeState,
      );
      final next = current.copyWith(
        workspace: nextWorkspace,
        syncState: syncState,
        localRevision: current.localRevision + 1,
      );
      await _writeStored(next);
      return nextWorkspace;
    });
  }

  @override
  Future<CurriculumMergeRepositorySnapshot>
  loadCurriculumMergeSnapshot() async {
    final current = await _loadStored();
    return CurriculumMergeRepositorySnapshot(
      workspace: current.workspace,
      mergeState: current.mergeState,
      localRevision: current.localRevision,
    );
  }

  @override
  Future<CurriculumMergeRepositorySnapshot> commitCurriculumMerge({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required int expectedLocalRevision,
  }) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      if (current.localRevision != expectedLocalRevision) {
        throw StateError(
          'The Teaching Planner changed while the curriculum package was being prepared. EduSheet kept the newer local work unchanged; review and import again.',
        );
      }
      // Official package materialization is an inbound merge, not a local
      // outbound edit. Preserve the local journal to avoid an echo loop.
      final next = TeachingPlannerStoredDocument(
        workspace: workspace,
        mergeState: mergeState,
        syncState: current.syncState,
        localRevision: current.localRevision + 1,
      );
      await _writeStored(next);
      return CurriculumMergeRepositorySnapshot(
        workspace: workspace,
        mergeState: mergeState,
        localRevision: next.localRevision,
      );
    });
  }

  @override
  Future<void> replaceWorkspaceWithMergeState(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
  ) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      await _writeStored(
        TeachingPlannerStoredDocument(
          workspace: workspace,
          mergeState: mergeState,
          syncState: OfflineSyncState(replicaId: current.syncState.replicaId),
          localRevision: current.localRevision + 1,
        ),
      );
    });
  }

  @override
  Future<void> replaceWorkspaceAndResetMergeState(
    TeachingPlannerWorkspace workspace,
  ) => replaceWorkspaceWithMergeState(workspace, CurriculumMergeState.empty());

  @override
  Future<OfflineSyncRepositorySnapshot> loadOfflineSyncSnapshot() {
    return _operations.run(() async {
      var current = await _loadStored();
      if (!current.syncState.isInitialized) {
        current = _initializeSync(current);
        await _writeStored(current);
      }
      return OfflineSyncRepositorySnapshot(
        workspace: current.workspace,
        mergeState: current.mergeState,
        syncState: current.syncState,
        localRevision: current.localRevision,
      );
    });
  }

  @override
  Future<OfflineSyncChangeSet?> buildPendingChangeSet({int maxChanges = 200}) {
    if (maxChanges < 1) {
      throw ArgumentError.value(maxChanges, 'maxChanges', 'Must be positive.');
    }
    return _operations.run(() async {
      var current = await _loadStored();
      if (!current.syncState.isInitialized) {
        current = _initializeSync(current);
        await _writeStored(current);
      }
      final pending = current.syncState.pendingOutbound.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      if (pending.isEmpty) return null;
      final selected = pending.take(maxChanges).toList(growable: false);
      final first = selected.first.sequence;
      final last = selected.last.sequence;
      return OfflineSyncChangeSet(
        changeSetId: '${current.syncState.replicaId}:$first-$last',
        sourceReplicaId: current.syncState.replicaId,
        createdAt: selected.last.occurredAt,
        changes: selected.map(OfflineSyncChange.fromJournal).toList(),
      );
    });
  }

  @override
  Future<void> acknowledgeOutboundChangeSet(OfflineSyncChangeSet changeSet) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      if (changeSet.sourceReplicaId != current.syncState.replicaId) {
        throw StateError(
          'Cannot acknowledge a change-set from another replica.',
        );
      }
      final ids = changeSet.changes.map((item) => item.changeId).toSet();
      final pendingIds = current.syncState.pendingOutbound
          .map((item) => item.changeId)
          .toSet();
      if (!pendingIds.containsAll(ids)) {
        throw StateError(
          'The change-set is stale or already acknowledged; local sync state was not changed.',
        );
      }
      final journal = current.syncState.journal
          .map((entry) {
            if (!ids.contains(entry.changeId)) return entry;
            return entry.copyWith(state: OfflineSyncEntryState.acknowledged);
          })
          .toList(growable: false);
      await _writeStored(
        current.copyWith(
          syncState: current.syncState.copyWith(
            journal: _compactJournal(journal),
          ),
        ),
      );
    });
  }

  @override
  Future<void> recordInboundChangeSetOutcome({
    required OfflineSyncChangeSet changeSet,
    Set<String> conflictChangeIds = const {},
    Map<String, String> conflictReasons = const {},
  }) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      final known = <String>{
        ...current.syncState.appliedInboundChangeIds,
        ...current.syncState.journal.map((item) => item.changeId),
      };
      final journal = <OfflineSyncJournalEntry>[...current.syncState.journal];
      final applied = <String>[...current.syncState.appliedInboundChangeIds];
      for (final change in changeSet.changes) {
        if (known.contains(change.changeId)) continue;
        final isConflict = conflictChangeIds.contains(change.changeId);
        journal.add(
          OfflineSyncJournalEntry(
            changeId: change.changeId,
            sourceReplicaId: change.sourceReplicaId,
            sequence: change.sequence,
            direction: OfflineSyncDirection.inbound,
            state: isConflict
                ? OfflineSyncEntryState.conflict
                : OfflineSyncEntryState.applied,
            entityType: change.entityType,
            originId: change.originId,
            localId: change.localId,
            entityRevision: change.entityRevision,
            operation: change.operation,
            layer: change.layer,
            occurredAt: change.occurredAt,
            payload: change.payload,
            conflictReason: isConflict
                ? conflictReasons[change.changeId] ?? 'Merge conflict'
                : null,
          ),
        );
        if (!isConflict) applied.add(change.changeId);
        known.add(change.changeId);
      }
      final boundedApplied = applied.length <= 2000
          ? applied
          : applied.sublist(applied.length - 2000);
      await _writeStored(
        current.copyWith(
          syncState: current.syncState.copyWith(
            journal: _compactJournal(journal),
            appliedInboundChangeIds: boundedApplied,
          ),
        ),
      );
    });
  }

  @override
  Future<void> replaceWorkspaceWithSyncMetadata({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required OfflineSyncState syncState,
  }) {
    return _operations.run(() async {
      final current = _initializeSync(await _loadStored());
      final restoredSyncState = syncState.isInitialized
          ? syncState
          : OfflineSyncState(replicaId: current.syncState.replicaId);
      await _writeStored(
        TeachingPlannerStoredDocument(
          workspace: workspace,
          mergeState: mergeState,
          syncState: restoredSyncState,
          localRevision: current.localRevision + 1,
        ),
      );
    });
  }

  List<OfflineSyncJournalEntry> _compactJournal(
    List<OfflineSyncJournalEntry> journal,
  ) {
    final retainedCritical = journal
        .where(
          (entry) =>
              entry.state == OfflineSyncEntryState.pending ||
              entry.state == OfflineSyncEntryState.conflict,
        )
        .toList();
    final history = journal
        .where(
          (entry) =>
              entry.state == OfflineSyncEntryState.acknowledged ||
              entry.state == OfflineSyncEntryState.applied,
        )
        .toList();
    final tail = history.length <= 500
        ? history
        : history.sublist(history.length - 500);
    final result = <OfflineSyncJournalEntry>[...tail, ...retainedCritical];
    result.sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      if (byTime != 0) return byTime;
      return a.changeId.compareTo(b.changeId);
    });
    return result;
  }

  Future<void> _writeStored(TeachingPlannerStoredDocument document) async {
    final store = await _store();
    await store.writeJson(_codec.encodeStored(document));
  }
}
