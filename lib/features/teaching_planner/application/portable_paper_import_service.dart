import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:uuid/uuid.dart';

import '../data/portable_paper_asset_store.dart';
import '../data/portable_paper_snapshot.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';

typedef PortablePaperIdGenerator = String Function();

class PortablePaperImportResult {
  final TeachingPlannerWorkspace workspace;
  final Map<String, String> paperIdRemap;
  final List<String> createdPaperIds;
  final List<String> createdAssetDirectories;
  final int restoredCount;
  final int reusedCount;
  final int conflictCopyCount;

  const PortablePaperImportResult({
    required this.workspace,
    required this.paperIdRemap,
    required this.createdPaperIds,
    required this.createdAssetDirectories,
    required this.restoredCount,
    required this.reusedCount,
    required this.conflictCopyCount,
  });
}

/// Imports v3 paper snapshots without ever overwriting a saved paper already on
/// the destination device.
///
/// Missing id -> restore using the original id.
/// Same id + identical portable content -> reuse the existing paper.
/// Same id + different content -> create a new id and remap planner links.
class PortablePaperImportService {
  PortablePaperImportService({
    required PaperRepository paperRepository,
    PortablePaperAssetStore? assetStore,
    PortablePaperIdGenerator? idGenerator,
  })  : _paperRepository = paperRepository,
        _assetStore = assetStore ?? PortablePaperAssetStore(),
        _idGenerator = idGenerator ?? (() => const Uuid().v4());

  final PaperRepository _paperRepository;
  final PortablePaperAssetStore _assetStore;
  final PortablePaperIdGenerator _idGenerator;

  Future<PortablePaperImportResult> importSnapshots({
    required TeachingPlannerWorkspace workspace,
    required Map<String, PortablePaperSnapshot> snapshots,
  }) async {
    if (snapshots.isEmpty) {
      return PortablePaperImportResult(
        workspace: workspace,
        paperIdRemap: const {},
        createdPaperIds: const [],
        createdAssetDirectories: const [],
        restoredCount: 0,
        reusedCount: 0,
        conflictCopyCount: 0,
      );
    }

    final existing = await _paperRepository.getAllPapers();
    final existingById = <String, Paper>{
      for (final paper in existing) paper.id: paper,
    };
    final reservedIds = <String>{
      ...existingById.keys,
      ...snapshots.keys,
    };
    final remap = <String, String>{};
    final createdIds = <String>[];
    final createdDirectories = <String>[];
    var restoredCount = 0;
    var reusedCount = 0;
    var conflictCopyCount = 0;

    try {
      for (final entry in snapshots.entries) {
        final originalId = entry.key;
        final snapshot = entry.value;
        final current = existingById[originalId];
        if (current != null && await snapshot.representsSamePaper(current)) {
          remap[originalId] = originalId;
          reusedCount++;
          continue;
        }

        final targetId = current == null
            ? originalId
            : _nextUniqueId(reservedIds);
        reservedIds.add(targetId);

        final materialized = await _assetStore.materialize(
          snapshot,
          targetPaperId: targetId,
        );
        try {
          final restored = snapshot.restoreWithPaths(
            materialized.resolvedPaths,
            paperId: targetId,
          );
          await _paperRepository.savePaper(restored);
        } catch (_) {
          try {
            await _paperRepository.deletePaper(targetId);
          } catch (_) {
            // The target id was reserved for this import, so cleanup is safe.
          }
          await _assetStore.deleteMaterialization(materialized.directoryPath);
          rethrow;
        }

        createdIds.add(targetId);
        if (materialized.directoryPath.isNotEmpty) {
          createdDirectories.add(materialized.directoryPath);
        }
        remap[originalId] = targetId;
        if (current == null) {
          restoredCount++;
        } else {
          conflictCopyCount++;
        }
      }

      final resources = workspace.resources
          .map((resource) => _remapResource(resource, remap))
          .toList(growable: false);
      return PortablePaperImportResult(
        workspace: workspace.copyWith(resources: resources),
        paperIdRemap: Map<String, String>.unmodifiable(remap),
        createdPaperIds: List<String>.unmodifiable(createdIds),
        createdAssetDirectories: List<String>.unmodifiable(createdDirectories),
        restoredCount: restoredCount,
        reusedCount: reusedCount,
        conflictCopyCount: conflictCopyCount,
      );
    } catch (_) {
      await _rollbackCreated(createdIds, createdDirectories);
      rethrow;
    }
  }

  Future<void> rollback(PortablePaperImportResult result) => _rollbackCreated(
        result.createdPaperIds,
        result.createdAssetDirectories,
      );

  String _nextUniqueId(Set<String> reserved) {
    for (var attempt = 0; attempt < 100; attempt++) {
      final candidate = _idGenerator().trim();
      if (candidate.isNotEmpty && !reserved.contains(candidate)) {
        return candidate;
      }
    }
    throw StateError('Could not allocate a safe paper id for import.');
  }

  TeachingResource _remapResource(
    TeachingResource resource,
    Map<String, String> remap,
  ) {
    if (resource.kind != TeachingResourceKind.paper) return resource;
    final linkedId = resource.linkedPaperId;
    if (linkedId == null) return resource;
    final mapped = remap[linkedId];
    if (mapped == null || mapped == linkedId) return resource;
    return resource.copyWith(linkedPaperId: mapped);
  }

  Future<void> _rollbackCreated(
    List<String> createdIds,
    List<String> createdDirectories,
  ) async {
    for (final id in createdIds.reversed) {
      try {
        await _paperRepository.deletePaper(id);
      } catch (_) {
        // Best-effort rollback continues so one storage error does not strand
        // every later imported paper/asset.
      }
    }
    for (final directory in createdDirectories.reversed) {
      try {
        await _assetStore.deleteMaterialization(directory);
      } catch (_) {
        // Same best-effort rollback rule for file-system cleanup.
      }
    }
  }
}
