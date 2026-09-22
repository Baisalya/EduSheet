import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_restore_service.dart';
import 'package:edusheet/features/teaching_planner/data/local_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/data/offline_sync_change_set_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_resource_file_store.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_merge_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/offline_sync_change_set.dart';
import 'package:edusheet/features/teaching_planner/domain/models/offline_sync_state.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t1 = DateTime.utc(2026, 9, 18, 10);
  final t2 = DateTime.utc(2026, 9, 18, 11);
  final t3 = DateTime.utc(2026, 9, 18, 12);

  test(
    'schema 9 migrates through schema 11 with an uninitialized local sync sidecar',
    () {
      const codec = TeachingPlannerDocumentCodec();
      final legacy = <String, dynamic>{
        'schemaVersion': 9,
        'localRevision': 7,
        'curriculumMerge': <String, dynamic>{
          'replicas': <dynamic>[],
          'receipts': <dynamic>[],
        },
        'workspace': TeachingPlannerWorkspace.empty().toJson(),
      };

      final migrated = codec.decodeStored(legacy);

      expect(TeachingPlannerDocumentCodec.currentSchemaVersion, 11);
      expect(migrated.localRevision, 7);
      expect(migrated.syncState.isInitialized, isFalse);
      expect(migrated.syncState.nextSequence, 1);
    },
  );

  test(
    'local mutations create stable revisions and a real delete tombstone',
    () async {
      final temp = await Directory.systemTemp.createTemp('eds-phase9-journal-');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/planner.json');
      final ticks = <DateTime>[t1, t2, t3].iterator;
      DateTime clock() {
        ticks.moveNext();
        return ticks.current;
      }

      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => file,
        syncReplicaIdGenerator: () => 'replica-a',
        clock: clock,
      );
      final created = PlannerClass(
        id: 'class-local',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: t1,
        updatedAt: t1,
      );

      await repository.update(
        (workspace) => workspace.copyWith(classes: [created]),
      );
      await repository.update(
        (workspace) => workspace.copyWith(
          classes: [created.copyWith(name: 'Class X', updatedAt: t2)],
        ),
      );
      await repository.update(
        (workspace) => workspace.copyWith(classes: const []),
      );

      final snapshot = await repository.loadOfflineSyncSnapshot();
      final pending = snapshot.syncState.pendingOutbound;
      const origin = 'local:replica-a:class:class-local';

      expect(snapshot.syncState.replicaId, 'replica-a');
      expect(pending.map((item) => item.changeId), [
        'replica-a:1',
        'replica-a:2',
        'replica-a:3',
      ]);
      expect(pending.map((item) => item.originId).toSet(), {origin});
      expect(pending.map((item) => item.entityRevision), [1, 2, 3]);
      expect(pending.last.operation, OfflineSyncOperation.delete);
      expect(pending.last.payload, isNull);
      final clockState = snapshot.syncState.clockFor('class', origin);
      expect(clockState?.revision, 3);
      expect(clockState?.isDeleted, isTrue);
      expect(clockState?.localId, isNull);
    },
  );

  test(
    'pending change-set is deterministic, portable, and acknowledged atomically',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'eds-phase9-change-set-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => File('${temp.path}/planner.json'),
        syncReplicaIdGenerator: () => 'replica-a',
        clock: () => t1,
      );
      await repository.update(
        (workspace) => workspace.copyWith(
          classes: [
            PlannerClass(
              id: 'class-1',
              name: 'Class 10',
              sortOrder: 0,
              createdAt: t1,
              updatedAt: t1,
            ),
          ],
        ),
      );

      final first = await repository.buildPendingChangeSet();
      final second = await repository.buildPendingChangeSet();
      expect(first, isNotNull);
      expect(second?.changeSetId, first?.changeSetId);
      expect(first?.changeSetId, 'replica-a:1-1');

      const codec = OfflineSyncChangeSetCodec();
      final restored = codec.decode(codec.encode(first!));
      expect(restored.changeSetId, first.changeSetId);
      expect(restored.changes.single.changeId, 'replica-a:1');
      expect(restored.changes.single.payload?['name'], 'Class 10');

      await repository.acknowledgeOutboundChangeSet(restored);
      expect(await repository.buildPendingChangeSet(), isNull);
      final snapshot = await repository.loadOfflineSyncSnapshot();
      expect(
        snapshot.syncState.journal.single.state,
        OfflineSyncEntryState.acknowledged,
      );
    },
  );

  test(
    'official curriculum merge is inbound and does not echo into outbound journal',
    () async {
      final temp = await Directory.systemTemp.createTemp('eds-phase9-echo-');
      addTearDown(() => temp.delete(recursive: true));
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => File('${temp.path}/planner.json'),
        syncReplicaIdGenerator: () => 'teacher-replica',
        clock: () => t1,
      );
      final before = await repository.loadCurriculumMergeSnapshot();
      final officialClass = PlannerClass(
        id: 'local-class-10',
        name: 'Class 10',
        academicYear: '2026-27',
        sortOrder: 0,
        createdAt: t1,
        updatedAt: t1,
      );
      final mergeState = CurriculumMergeState(
        replicas: [
          CurriculumReplicaRecord(
            entityType: 'class',
            localId: officialClass.id,
            originId: 'school-class-10',
            sourceRevision: 4,
            sourceUpdatedAt: t1,
            importedAt: t1,
            sourcePackageOriginId: 'assignment-1',
          ),
        ],
      );

      await repository.commitCurriculumMerge(
        workspace: TeachingPlannerWorkspace(classes: [officialClass]),
        mergeState: mergeState,
        expectedLocalRevision: before.localRevision,
      );

      final sync = await repository.loadOfflineSyncSnapshot();
      expect(sync.workspace.classes.single.id, officialClass.id);
      expect(sync.syncState.replicaId, 'teacher-replica');
      expect(sync.syncState.pendingOutbound, isEmpty);
    },
  );

  test(
    'inbound outcome ledger is idempotent and records conflicts separately',
    () async {
      final temp = await Directory.systemTemp.createTemp('eds-phase9-inbound-');
      addTearDown(() => temp.delete(recursive: true));
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => File('${temp.path}/planner.json'),
        syncReplicaIdGenerator: () => 'replica-local',
      );
      final applied = OfflineSyncChange(
        changeId: 'school:1',
        sourceReplicaId: 'school',
        sequence: 1,
        entityType: 'class',
        originId: 'school-class-10',
        localId: 'class-10',
        entityRevision: 5,
        operation: OfflineSyncOperation.upsert,
        layer: OfflineSyncLayer.officialMaster,
        occurredAt: t1,
        payload: <String, dynamic>{'id': 'class-10', 'name': 'Class 10'},
      );
      final conflict = OfflineSyncChange(
        changeId: 'school:2',
        sourceReplicaId: 'school',
        sequence: 2,
        entityType: 'lessonPlan',
        originId: 'lesson-1',
        localId: 'lesson-local',
        entityRevision: 7,
        operation: OfflineSyncOperation.upsert,
        layer: OfflineSyncLayer.teacherWorking,
        occurredAt: t2,
        payload: <String, dynamic>{'id': 'lesson-local'},
      );
      final changeSet = OfflineSyncChangeSet(
        changeSetId: 'school:1-2',
        sourceReplicaId: 'school',
        createdAt: t2,
        changes: [applied, conflict],
      );

      await repository.recordInboundChangeSetOutcome(
        changeSet: changeSet,
        conflictChangeIds: const {'school:2'},
        conflictReasons: const {
          'school:2': 'Teacher working copy diverged.',
        },
      );
      await repository.recordInboundChangeSetOutcome(
        changeSet: changeSet,
        conflictChangeIds: const {'school:2'},
      );

      final state = (await repository.loadOfflineSyncSnapshot()).syncState;
      expect(state.appliedInboundChangeIds, ['school:1']);
      expect(
        state.journal.where(
          (item) => item.direction == OfflineSyncDirection.inbound,
        ),
        hasLength(2),
      );
      expect(state.conflicts.single.changeId, 'school:2');
      expect(
        state.conflicts.single.conflictReason,
        'Teacher working copy diverged.',
      );
    },
  );

  test('v4 planner backup preserves initialized sync metadata', () {
    final syncState = OfflineSyncState(
      replicaId: 'replica-a',
      nextSequence: 2,
      journal: [
        OfflineSyncJournalEntry(
          changeId: 'replica-a:1',
          sourceReplicaId: 'replica-a',
          sequence: 1,
          direction: OfflineSyncDirection.outbound,
          state: OfflineSyncEntryState.pending,
          entityType: 'class',
          originId: 'local:replica-a:class:class-1',
          localId: 'class-1',
          entityRevision: 1,
          operation: OfflineSyncOperation.upsert,
          layer: OfflineSyncLayer.teacherLocal,
          occurredAt: t1,
          payload: <String, dynamic>{'id': 'class-1', 'name': 'Class 10'},
        ),
      ],
    );
    final source = const TeachingPlannerBackupCodec().encode(
      TeachingPlannerWorkspace.empty(),
      exportedAt: t2,
      syncState: syncState,
    );

    final restored = const TeachingPlannerBackupCodec().decodePayload(source);

    expect(restored.syncState.replicaId, 'replica-a');
    expect(restored.syncState.pendingOutbound.single.changeId, 'replica-a:1');
  });

  test(
    'backup restore passes preserved sync metadata into the atomic workspace saver',
    () async {
      final temp = await Directory.systemTemp.createTemp('eds-phase9-restore-');
      addTearDown(() => temp.delete(recursive: true));
      final syncState = OfflineSyncState(
        replicaId: 'replica-backup',
        nextSequence: 2,
        journal: [
          OfflineSyncJournalEntry(
            changeId: 'replica-backup:1',
            sourceReplicaId: 'replica-backup',
            sequence: 1,
            direction: OfflineSyncDirection.outbound,
            state: OfflineSyncEntryState.pending,
            entityType: 'class',
            originId: 'local:replica-backup:class:class-1',
            localId: 'class-1',
            entityRevision: 1,
            operation: OfflineSyncOperation.upsert,
            layer: OfflineSyncLayer.teacherLocal,
            occurredAt: t1,
            payload: <String, dynamic>{'id': 'class-1'},
          ),
        ],
      );
      final service = TeachingPlannerBackupRestoreService(
        paperRepository: _MemoryPaperRepository(),
        resourceFileStore: TeachingResourceFileStore(
          rootResolver: () async => temp,
        ),
      );
      OfflineSyncState? savedSyncState;

      final result = await service.restore(
        payload: TeachingPlannerBackupPayload(
          workspace: TeachingPlannerWorkspace.empty(),
          syncState: syncState,
          version: 4,
        ),
        currentWorkspace: TeachingPlannerWorkspace.empty(),
        saveWorkspace: (_, _, restoredSyncState) async {
          savedSyncState = restoredSyncState;
          return true;
        },
      );

      expect(result.saved, isTrue);
      expect(savedSyncState?.replicaId, 'replica-backup');
      expect(
        savedSyncState?.pendingOutbound.single.changeId,
        'replica-backup:1',
      );
    },
  );

  test(
    'legacy restore without sync metadata keeps this device replica identity',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'eds-phase9-legacy-restore-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => File('${temp.path}/planner.json'),
        syncReplicaIdGenerator: () => 'device-replica',
      );
      final before = await repository.loadOfflineSyncSnapshot();

      await repository.replaceWorkspaceWithSyncMetadata(
        workspace: TeachingPlannerWorkspace.empty(),
        mergeState: CurriculumMergeState.empty(),
        syncState: OfflineSyncState.uninitialized(),
      );

      final after = await repository.loadOfflineSyncSnapshot();
      expect(before.syncState.replicaId, 'device-replica');
      expect(after.syncState.replicaId, 'device-replica');
      expect(after.syncState.pendingOutbound, isEmpty);
    },
  );
}

class _MemoryPaperRepository implements PaperRepository {
  final Map<String, Paper> _papers = <String, Paper>{};

  @override
  Future<List<Paper>> getAllPapers() async => _papers.values.toList();

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = paper;
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }
}
