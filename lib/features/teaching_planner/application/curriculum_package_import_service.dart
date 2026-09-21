import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';

import '../data/portable_paper_asset_store.dart';
import '../data/teaching_resource_file_store.dart';
import '../domain/models/curriculum_package.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/repositories/curriculum_merge_repository.dart';
import '../domain/repositories/teaching_planner_repository.dart';
import '../domain/services/teaching_planner_integrity.dart';
import 'curriculum_merge_engine.dart';

class CurriculumPackageDryRun {
  final CurriculumMergePlan plan;
  final int expectedLocalRevision;

  const CurriculumPackageDryRun({
    required this.plan,
    required this.expectedLocalRevision,
  });
}

class CurriculumPackageImportResult {
  final TeachingPlannerWorkspace workspace;
  final CurriculumMergePlan plan;
  final int materializedPaperCount;
  final int materializedFileCount;

  const CurriculumPackageImportResult({
    required this.workspace,
    required this.plan,
    required this.materializedPaperCount,
    required this.materializedFileCount,
  });
}

/// Executes the Phase 6 merge transaction.
///
/// New binary state is staged under new local ids before the planner commit.
/// The planner document then commits with an expected local revision. If that
/// compare-and-set fails, all newly staged files/papers are rolled back.
class CurriculumPackageImportService {
  CurriculumPackageImportService({
    required TeachingPlannerRepository plannerRepository,
    required PaperRepository paperRepository,
    required TeachingResourceFileStore resourceFileStore,
    PortablePaperAssetStore? paperAssetStore,
    CurriculumMergeEngine? mergeEngine,
  }) : _plannerRepository = plannerRepository,
       _paperRepository = paperRepository,
       _resourceFileStore = resourceFileStore,
       _paperAssetStore = paperAssetStore ?? PortablePaperAssetStore(),
       _mergeEngine = mergeEngine ?? CurriculumMergeEngine();

  final TeachingPlannerRepository _plannerRepository;
  final PaperRepository _paperRepository;
  final TeachingResourceFileStore _resourceFileStore;
  final PortablePaperAssetStore _paperAssetStore;
  final CurriculumMergeEngine _mergeEngine;

  CurriculumMergeRepository get _mergeRepository {
    final repository = _plannerRepository;
    final mergeRepository = switch (repository) {
      CurriculumMergeRepository mergeRepository => mergeRepository,
      _ => null,
    };
    if (mergeRepository == null) {
      throw const CurriculumMergeException(
        'Curriculum package import is unavailable in this temporary planner session.',
      );
    }
    return mergeRepository;
  }

  Future<CurriculumPackageDryRun> dryRun(
    CurriculumPackagePreview preview,
  ) async {
    final snapshot = await _mergeRepository.loadCurriculumMergeSnapshot();
    final papers = await _paperRepository.getAllPapers();
    final plan = _mergeEngine.plan(
      current: snapshot.workspace,
      state: snapshot.mergeState,
      preview: preview,
      localPapers: papers,
    );
    return CurriculumPackageDryRun(
      plan: plan,
      expectedLocalRevision: snapshot.localRevision,
    );
  }

  Future<CurriculumPackageImportResult> import(
    CurriculumPackagePreview preview,
  ) async {
    // Re-read immediately before staging so a preview dialog can never become
    // an unsafe stale write.
    final previewRun = await dryRun(preview);
    final plan = previewRun.plan;
    final createdPaperIds = <String>[];
    final createdPaperDirectories = <String>[];
    final createdResourceIds = <String>[];
    var workspace = plan.workspace;

    try {
      for (final paperPlan in plan.paperMaterializations) {
        final materialized = await _paperAssetStore.materialize(
          paperPlan.snapshot,
          targetPaperId: paperPlan.targetLocalPaperId,
        );
        createdPaperIds.add(paperPlan.targetLocalPaperId);
        if (materialized.directoryPath.isNotEmpty) {
          createdPaperDirectories.add(materialized.directoryPath);
        }
        final paper = paperPlan.snapshot.restoreWithPaths(
          materialized.resolvedPaths,
          paperId: paperPlan.targetLocalPaperId,
        );
        await _paperRepository.savePaper(paper);
      }

      final resources = <String, TeachingResource>{
        for (final item in workspace.resources) item.id: item,
      };
      for (final filePlan in plan.fileMaterializations) {
        createdResourceIds.add(filePlan.targetLocalResourceId);
        final relativePath = await _resourceFileStore.writeBytes(
          resourceId: filePlan.targetLocalResourceId,
          fileName: filePlan.fileName,
          bytes: filePlan.bytes,
        );
        final resource = resources[filePlan.targetLocalResourceId];
        if (resource == null || resource.kind != TeachingResourceKind.file) {
          throw const CurriculumMergeException(
            'A staged teaching file lost its planner resource binding.',
          );
        }
        resources[filePlan.targetLocalResourceId] = resource.copyWith(
          localRelativePath: relativePath,
          sizeBytes: filePlan.bytes.length,
        );
      }
      workspace = workspace.copyWith(
        resources: resources.values.toList(growable: false),
      );
      TeachingPlannerIntegrity.validateOrThrow(workspace);

      await _mergeRepository.commitCurriculumMerge(
        workspace: workspace,
        mergeState: plan.mergeState,
        expectedLocalRevision: previewRun.expectedLocalRevision,
      );
    } catch (_) {
      await _rollback(
        paperIds: createdPaperIds,
        paperDirectories: createdPaperDirectories,
        resourceIds: createdResourceIds,
      );
      rethrow;
    }

    await _cleanupSuperseded(plan, committedWorkspace: workspace);
    return CurriculumPackageImportResult(
      workspace: workspace,
      plan: plan,
      materializedPaperCount: plan.paperMaterializations.length,
      materializedFileCount: plan.fileMaterializations.length,
    );
  }

  Future<void> _rollback({
    required List<String> paperIds,
    required List<String> paperDirectories,
    required List<String> resourceIds,
  }) async {
    for (final id in resourceIds.reversed) {
      try {
        await _resourceFileStore.deleteResourceFiles(id);
      } catch (_) {
        // Continue rollback so one file-system problem does not strand all
        // other staged import data.
      }
    }
    for (final id in paperIds.reversed) {
      try {
        await _paperRepository.deletePaper(id);
      } catch (_) {
        // Best effort, same rule as resource cleanup.
      }
    }
    for (final directory in paperDirectories.reversed) {
      try {
        await _paperAssetStore.deleteMaterialization(directory);
      } catch (_) {
        // Best effort.
      }
    }
  }

  Future<void> _cleanupSuperseded(
    CurriculumMergePlan plan, {
    required TeachingPlannerWorkspace committedWorkspace,
  }) async {
    for (final filePlan in plan.fileMaterializations) {
      final oldId = filePlan.supersededLocalResourceId;
      if (!filePlan.cleanupSuperseded || oldId == null) continue;
      if (committedWorkspace.resourceById(oldId) != null) continue;
      try {
        await _resourceFileStore.deleteResourceFiles(oldId);
      } catch (_) {
        // Cleanup must never turn a committed merge into a reported failure.
      }
    }

    final referencedPaperIds = committedWorkspace.resources
        .where((item) => item.kind == TeachingResourceKind.paper)
        .map((item) => item.linkedPaperId)
        .whereType<String>()
        .toSet();
    for (final paperPlan in plan.paperMaterializations) {
      final oldId = paperPlan.supersededLocalPaperId;
      if (!paperPlan.cleanupSupersededWhenUnreferenced || oldId == null) {
        continue;
      }
      if (referencedPaperIds.contains(oldId)) continue;
      try {
        await _paperRepository.deletePaper(oldId);
      } catch (_) {
        // A harmless duplicate is preferable to deleting user data unsafely.
      }
    }
  }
}
