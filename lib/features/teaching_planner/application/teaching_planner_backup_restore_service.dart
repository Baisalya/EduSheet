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
/// commit. Attachment restore is copy-on-write: existing referenced files are
/// never deleted before the workspace commit. Failed restores may leave only
/// unreferenced content-addressed blobs, which the storage maintenance tool can
/// safely clean later. Newly-created paper copies/assets are rolled back.
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

        final blob = await _resourceFileStore.writeManagedBlob(
          fileName: resource.originalFileName ?? resource.title,
          bytes: bytes,
        );
        restoredResources.add(
          resource.copyWith(
            fileOwnership: TeachingResourceFileOwnership.managed,
            localRelativePath: blob.relativePath,
            externalFilePath: null,
            sizeBytes: bytes.length,
            contentSha256: blob.sha256Hex,
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
        await _paperImportService.rollback(importedPapers);
      }

      return TeachingPlannerBackupRestoreResult(
        saved: saved,
        restoredPaperCount: importedPapers.restoredCount,
        reusedPaperCount: importedPapers.reusedCount,
        conflictCopyCount: importedPapers.conflictCopyCount,
      );
    } catch (_) {
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

}
