import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';

import '../data/portable_paper_snapshot.dart';
import '../data/teaching_planner_backup_codec.dart';
import '../data/teaching_resource_file_store.dart';
import '../domain/models/curriculum_merge_state.dart';
import '../domain/models/offline_sync_state.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import 'teaching_resource_portability.dart';

class MissingLinkedPaperReference {
  const MissingLinkedPaperReference({
    required this.resourceId,
    required this.resourceTitle,
    required this.linkedPaperId,
  });

  final String resourceId;
  final String resourceTitle;
  final String? linkedPaperId;
}

class TeachingPlannerBackupPreparation {
  const TeachingPlannerBackupPreparation({
    required this.originalWorkspace,
    required this.exportWorkspace,
    required this.resourceFiles,
    required this.paperSnapshots,
    required this.mergeState,
    required this.syncState,
    required this.missingLinkedPapers,
  });

  final TeachingPlannerWorkspace originalWorkspace;
  final TeachingPlannerWorkspace exportWorkspace;
  final Map<String, List<int>> resourceFiles;
  final Map<String, PortablePaperSnapshot> paperSnapshots;
  final CurriculumMergeState mergeState;
  final OfflineSyncState syncState;
  final List<MissingLinkedPaperReference> missingLinkedPapers;

  bool get needsRecoveryConfirmation => missingLinkedPapers.isNotEmpty;
}

class MissingLinkedPapersException implements Exception {
  const MissingLinkedPapersException(this.missingLinkedPapers);

  final List<MissingLinkedPaperReference> missingLinkedPapers;

  @override
  String toString() =>
      'Teaching Planner backup contains ${missingLinkedPapers.length} missing linked Saved Paper reference(s).';
}

/// Prepares a portable Teaching Planner backup without changing the live
/// planner or Saved Papers repository.
///
/// When a planner resource points at a Saved Paper that no longer exists on
/// this device, [prepare] reports that broken link and creates an in-memory
/// recovery copy with only the broken paper resource omitted. [encode] still
/// requires an explicit [allowRecovery] opt-in before that recovery copy can
/// become a `.eds` file.
class TeachingPlannerBackupExportService {
  TeachingPlannerBackupExportService({
    required PaperRepository paperRepository,
    required TeachingResourceFileStore resourceFileStore,
    TeachingPlannerBackupCodec codec = const TeachingPlannerBackupCodec(),
  }) : _paperRepository = paperRepository,
       _resourceFileStore = resourceFileStore,
       _codec = codec;

  final PaperRepository _paperRepository;
  final TeachingResourceFileStore _resourceFileStore;
  final TeachingPlannerBackupCodec _codec;

  Future<TeachingPlannerBackupPreparation> prepare({
    required TeachingPlannerWorkspace workspace,
    required CurriculumMergeState mergeState,
    required OfflineSyncState syncState,
  }) async {
    final resourceFiles = <String, List<int>>{};
    for (final resource in workspace.resources) {
      if (resource.kind != TeachingResourceKind.file) continue;
      if (!await _resourceFileStore.resourceExists(resource)) {
        throw FileSystemException(
          'Attached teaching file is missing: ${resource.originalFileName ?? resource.title}',
          resource.externalFilePath ?? resource.localRelativePath,
        );
      }
      resourceFiles[resource.id] = await _resourceFileStore.readResourceBytes(
        resource,
      );
    }

    final savedPapers = await _paperRepository.getAllPapers();
    final papersById = {for (final paper in savedPapers) paper.id: paper};
    final paperSnapshots = <String, PortablePaperSnapshot>{};
    final missingLinkedPapers = <MissingLinkedPaperReference>[];
    final missingResourceIds = <String>{};
    final missingPaperIds = <String>{};

    for (final resource in workspace.resources) {
      if (resource.kind != TeachingResourceKind.paper) continue;
      final paperId = resource.linkedPaperId?.trim() ?? '';
      final paper = paperId.isEmpty ? null : papersById[paperId];
      if (paper == null) {
        missingResourceIds.add(resource.id);
        if (paperId.isNotEmpty) missingPaperIds.add(paperId);
        missingLinkedPapers.add(
          MissingLinkedPaperReference(
            resourceId: resource.id,
            resourceTitle: resource.title,
            linkedPaperId: paperId.isEmpty ? null : paperId,
          ),
        );
        continue;
      }
    }

    // Capture once per linked paper. This stays separate from the resource loop
    // so duplicate links to one Saved Paper do not duplicate asset work.
    for (final paperId in workspace.resources
        .where((resource) => resource.kind == TeachingResourceKind.paper)
        .map((resource) => resource.linkedPaperId?.trim() ?? '')
        .where((id) => id.isNotEmpty && !missingPaperIds.contains(id))
        .toSet()) {
      final paper = papersById[paperId];
      if (paper != null) {
        paperSnapshots[paperId] = await PortablePaperSnapshot.capture(paper);
      }
    }

    final recoverableWorkspace = missingResourceIds.isEmpty
        ? workspace
        : workspace.copyWith(
            resources: workspace.resources
                .where((resource) => !missingResourceIds.contains(resource.id))
                .toList(growable: false),
          );
    final exportWorkspace = portableTeachingResourceWorkspaceWithFiles(
      recoverableWorkspace,
      resourceFiles,
    );
    final exportMergeState = _withoutMissingPaperState(
      mergeState,
      missingPaperIds: missingPaperIds,
      missingResourceIds: missingResourceIds,
    );
    final exportSyncState = _withoutMissingPaperSyncState(
      syncState,
      missingPaperIds: missingPaperIds,
      missingResourceIds: missingResourceIds,
    );

    return TeachingPlannerBackupPreparation(
      originalWorkspace: workspace,
      exportWorkspace: exportWorkspace,
      resourceFiles: Map<String, List<int>>.unmodifiable(resourceFiles),
      paperSnapshots: Map<String, PortablePaperSnapshot>.unmodifiable(
        paperSnapshots,
      ),
      mergeState: exportMergeState,
      syncState: exportSyncState,
      missingLinkedPapers: List<MissingLinkedPaperReference>.unmodifiable(
        missingLinkedPapers,
      ),
    );
  }

  String encode(
    TeachingPlannerBackupPreparation preparation, {
    bool allowRecovery = false,
    DateTime? exportedAt,
  }) {
    if (preparation.needsRecoveryConfirmation && !allowRecovery) {
      throw MissingLinkedPapersException(preparation.missingLinkedPapers);
    }
    return _codec.encode(
      preparation.exportWorkspace,
      exportedAt: exportedAt,
      resourceFiles: preparation.resourceFiles,
      paperSnapshots: preparation.paperSnapshots,
      mergeState: preparation.mergeState,
      syncState: preparation.syncState,
    );
  }

  CurriculumMergeState _withoutMissingPaperState(
    CurriculumMergeState state, {
    required Set<String> missingPaperIds,
    required Set<String> missingResourceIds,
  }) {
    if (missingPaperIds.isEmpty && missingResourceIds.isEmpty) return state;
    return state.copyWith(
      replicas: state.replicas
          .where(
            (record) => !_matchesMissingLocalId(
              record.entityType,
              record.localId,
              missingPaperIds: missingPaperIds,
              missingResourceIds: missingResourceIds,
            ),
          )
          .toList(growable: false),
    );
  }

  OfflineSyncState _withoutMissingPaperSyncState(
    OfflineSyncState state, {
    required Set<String> missingPaperIds,
    required Set<String> missingResourceIds,
  }) {
    if (missingPaperIds.isEmpty && missingResourceIds.isEmpty) return state;

    final removedOriginKeys = <String>{};
    for (final clock in state.entityClocks) {
      final localId = clock.localId;
      if (localId != null &&
          _matchesMissingLocalId(
            clock.entityType,
            localId,
            missingPaperIds: missingPaperIds,
            missingResourceIds: missingResourceIds,
          )) {
        removedOriginKeys.add('${clock.entityType}:${clock.originId}');
      }
    }
    for (final entry in state.journal) {
      final localId = entry.localId;
      if (localId != null &&
          _matchesMissingLocalId(
            entry.entityType,
            localId,
            missingPaperIds: missingPaperIds,
            missingResourceIds: missingResourceIds,
          )) {
        removedOriginKeys.add('${entry.entityType}:${entry.originId}');
      }
    }

    return state.copyWith(
      entityClocks: state.entityClocks
          .where(
            (clock) =>
                !removedOriginKeys.contains('${clock.entityType}:${clock.originId}'),
          )
          .toList(growable: false),
      journal: state.journal
          .where(
            (entry) =>
                !removedOriginKeys.contains('${entry.entityType}:${entry.originId}'),
          )
          .toList(growable: false),
    );
  }

  bool _matchesMissingLocalId(
    String entityType,
    String localId, {
    required Set<String> missingPaperIds,
    required Set<String> missingResourceIds,
  }) {
    return (entityType == 'paper' && missingPaperIds.contains(localId)) ||
        (entityType == 'resource' && missingResourceIds.contains(localId));
  }
}
