import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';

import '../data/teaching_planner_backup_codec.dart';
import '../data/teaching_resource_file_store.dart';
import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/offline_sync_state.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import 'portable_paper_import_service.dart';

typedef TeachingPlannerWorkspaceSaver =
    Future<bool> Function(
      TeachingPlannerWorkspace workspace,
      CurriculumMergeState mergeState,
      OfflineSyncState syncState,
    );

class TeachingPlannerBackupRestoreResult {
  final bool saved;
  final int restoredPaperCount;
  final int reusedPaperCount;
  final int conflictCopyCount;

  const TeachingPlannerBackupRestoreResult({
    required this.saved,
    required this.restoredPaperCount,
    required this.reusedPaperCount,
    required this.conflictCopyCount,
  });
}

/// Transaction-like restore coordinator shared by the planner screen and the
/// universal `.eds` Import Center.
///
/// It owns the cross-feature side effects that make a planner backup portable:
/// embedded Saved Papers, attached teaching files, and the final workspace
/// commit. Any failure before the workspace commit restores the previous file
/// bytes and rolls back newly-created paper copies/assets.
class TeachingPlannerBackupRestoreService {
  TeachingPlannerBackupRestoreService({
    required PaperRepository paperRepository,
    required TeachingResourceFileStore resourceFileStore,
    PortablePaperImportService? paperImportService,
  }) : _resourceFileStore = resourceFileStore,
       _paperImportService =
           paperImportService ??
           PortablePaperImportService(paperRepository: paperRepository);

  final TeachingResourceFileStore _resourceFileStore;
  final PortablePaperImportService _paperImportService;

  Future<TeachingPlannerBackupRestoreResult> restore({
    required TeachingPlannerBackupPayload payload,
    required TeachingPlannerWorkspace currentWorkspace,
    required TeachingPlannerWorkspaceSaver saveWorkspace,
  }) async {
    var workspace = payload.workspace;
    PortablePaperImportResult? paperImport;
    final rollbackBytes = <String, List<int>>{};
    final rollbackNames = <String, String>{};
    final touchedResourceIds = <String>[];

    try {
      final importedPapers = await _paperImportService.importSnapshots(
        workspace: workspace,
        snapshots: payload.paperSnapshots,
      );
      paperImport = importedPapers;
      workspace = importedPapers.workspace;
      final restoredMergeState = _remapPaperReplicaIds(
        payload.mergeState,
        importedPapers.paperIdRemap,
      );
      final restoredSyncState = _remapPaperSyncIds(
        payload.syncState,
        importedPapers.paperIdRemap,
      );

      final restoredResources = <TeachingResource>[];
      for (final resource in workspace.resources) {
        if (resource.kind != TeachingResourceKind.file) {
          restoredResources.add(resource);
          continue;
        }

        final bytes = payload.resourceFiles[resource.id];
        if (bytes == null) {
          throw const FormatException(
            'This planner backup references an attached file that is not embedded in the .eds file.',
          );
        }

        final current = currentWorkspace.resourceById(resource.id);
        if (current != null) {
          final currentPath = current.localRelativePath;
          if (currentPath != null &&
              await _resourceFileStore.exists(currentPath)) {
            rollbackBytes[resource.id] = await _resourceFileStore.readBytes(
              currentPath,
            );
            rollbackNames[resource.id] =
                current.originalFileName ?? current.title;
          }
        }

        touchedResourceIds.add(resource.id);
        await _resourceFileStore.deleteResourceFiles(resource.id);
        final relativePath = await _resourceFileStore.writeBytes(
          resourceId: resource.id,
          fileName: resource.originalFileName ?? resource.title,
          bytes: bytes,
        );
        restoredResources.add(
          resource.copyWith(
            localRelativePath: relativePath,
            sizeBytes: bytes.length,
          ),
        );
      }

      workspace = workspace.copyWith(resources: restoredResources);
      final saved = await saveWorkspace(
        workspace,
        restoredMergeState,
        restoredSyncState,
      );
      if (!saved) {
        await _rollbackFiles(
          touchedResourceIds: touchedResourceIds,
          rollbackBytes: rollbackBytes,
          rollbackNames: rollbackNames,
        );
        await _paperImportService.rollback(importedPapers);
      }

      return TeachingPlannerBackupRestoreResult(
        saved: saved,
        restoredPaperCount: importedPapers.restoredCount,
        reusedPaperCount: importedPapers.reusedCount,
        conflictCopyCount: importedPapers.conflictCopyCount,
      );
    } catch (_) {
      await _rollbackFiles(
        touchedResourceIds: touchedResourceIds,
        rollbackBytes: rollbackBytes,
        rollbackNames: rollbackNames,
      );
      if (paperImport != null) {
        await _paperImportService.rollback(paperImport);
      }
      rethrow;
    }
  }

  CurriculumMergeState _remapPaperReplicaIds(
    CurriculumMergeState state,
    Map<String, String> paperIdRemap,
  ) {
    if (paperIdRemap.isEmpty || state.replicas.isEmpty) return state;
    return state.copyWith(
      replicas: state.replicas
          .map((record) {
            if (record.entityType != 'paper') return record;
            final mapped = paperIdRemap[record.localId];
            if (mapped == null || mapped == record.localId) return record;
            return record.copyWith(localId: mapped);
          })
          .toList(growable: false),
    );
  }

  OfflineSyncState _remapPaperSyncIds(
    OfflineSyncState state,
    Map<String, String> paperIdRemap,
  ) {
    if (paperIdRemap.isEmpty || !state.isInitialized) return state;
    return state.copyWith(
      entityClocks: state.entityClocks
          .map((clock) {
            if (clock.entityType != 'paper' || clock.localId == null) {
              return clock;
            }
            final mapped = paperIdRemap[clock.localId];
            if (mapped == null || mapped == clock.localId) return clock;
            return OfflineSyncEntityClock(
              entityType: clock.entityType,
              originId: clock.originId,
              localId: mapped,
              revision: clock.revision,
              fingerprint: clock.fingerprint,
              isDeleted: clock.isDeleted,
              changedAt: clock.changedAt,
            );
          })
          .toList(growable: false),
      journal: state.journal
          .map((entry) {
            if (entry.entityType != 'paper' || entry.localId == null) {
              return entry;
            }
            final mapped = paperIdRemap[entry.localId];
            if (mapped == null || mapped == entry.localId) return entry;
            return OfflineSyncJournalEntry(
              changeId: entry.changeId,
              sourceReplicaId: entry.sourceReplicaId,
              sequence: entry.sequence,
              direction: entry.direction,
              state: entry.state,
              entityType: entry.entityType,
              originId: entry.originId,
              localId: mapped,
              entityRevision: entry.entityRevision,
              operation: entry.operation,
              layer: entry.layer,
              occurredAt: entry.occurredAt,
              payload: entry.payload,
              conflictReason: entry.conflictReason,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _rollbackFiles({
    required List<String> touchedResourceIds,
    required Map<String, List<int>> rollbackBytes,
    required Map<String, String> rollbackNames,
  }) async {
    for (final id in touchedResourceIds.reversed) {
      await _resourceFileStore.deleteResourceFiles(id);
      final old = rollbackBytes[id];
      if (old != null) {
        await _resourceFileStore.writeBytes(
          resourceId: id,
          fileName: rollbackNames[id] ?? 'resource.bin',
          bytes: old,
        );
      } else {
        await _resourceFileStore.deleteResourceFiles(id);
      }
    }
  }
}
