import 'package:edusheet/features/editor/data/portable/saved_paper_eds_codec.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_asset_store.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:uuid/uuid.dart';

enum SavedPaperImportMode { addAsNew, replaceSameLineage }

class SavedPaperImportLimitException implements Exception {
  const SavedPaperImportLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SavedPaperImportInspection {
  final SavedPaperEdsPackage package;
  final List<Paper> sameLineagePapers;
  final Paper? replaceTarget;
  final String? replaceBlockedReason;

  const SavedPaperImportInspection({
    required this.package,
    required this.sameLineagePapers,
    required this.replaceTarget,
    required this.replaceBlockedReason,
  });

  bool get canReplace => replaceTarget != null && replaceBlockedReason == null;
}

class SavedPaperImportResult {
  final Paper paper;
  final SavedPaperImportMode mode;
  final bool usedOriginalLocalId;
  final String createdAssetDirectory;

  const SavedPaperImportResult({
    required this.paper,
    required this.mode,
    required this.usedOriginalLocalId,
    required this.createdAssetDirectory,
  });
}

class SavedPaperEdsService {
  SavedPaperEdsService({
    required PaperRepository paperRepository,
    SavedPaperEdsCodec codec = const SavedPaperEdsCodec(),
    PortablePaperAssetStore? assetStore,
    String Function()? idGenerator,
  }) : _paperRepository = paperRepository,
       _codec = codec,
       _assetStore = assetStore ?? PortablePaperAssetStore(),
       _idGenerator = idGenerator ?? (() => const Uuid().v4());

  final PaperRepository _paperRepository;
  final SavedPaperEdsCodec _codec;
  final PortablePaperAssetStore _assetStore;
  final String Function() _idGenerator;

  Future<String> exportPaper(Paper paper) async {
    final snapshot = await PortablePaperSnapshot.capture(paper);
    return _codec.encodeSnapshot(snapshot);
  }

  Future<SavedPaperImportInspection> inspect(String source) async {
    final package = _codec.decode(source);
    final papers = await _paperRepository.getAllPapers();
    final sameLineage = papers
        .where((paper) => paper.originId == package.paper.originId)
        .toList(growable: false);

    Paper? target;
    final exactId = sameLineage
        .where((paper) => paper.id == package.paper.id)
        .toList(growable: false);
    if (exactId.length == 1) {
      target = exactId.single;
    } else if (sameLineage.length == 1) {
      target = sameLineage.single;
    }

    String? blockedReason;
    if (sameLineage.isEmpty) {
      blockedReason = 'No existing Saved Paper has this lineage.';
    } else if (target == null) {
      blockedReason =
          'More than one local copy has this lineage. Add safely as a new paper instead.';
    } else if (package.paper.revision < target.revision) {
      blockedReason =
          'The incoming revision is older than the matching local paper.';
    } else if (package.paper.revision == target.revision) {
      blockedReason =
          'The incoming file has the same revision as the matching local paper. EduSheet will not treat an equal revision as a newer replacement.';
    }

    return SavedPaperImportInspection(
      package: package,
      sameLineagePapers: List<Paper>.unmodifiable(sameLineage),
      replaceTarget: target,
      replaceBlockedReason: blockedReason,
    );
  }

  Future<SavedPaperImportResult> importInspected(
    SavedPaperImportInspection inspection, {
    required SavedPaperImportMode mode,
    required int? maximumSavedPaperCount,
  }) async {
    final package = inspection.package;
    final snapshot = package.snapshot;
    final papers = await _paperRepository.getAllPapers();
    final reservedIds = papers.map((paper) => paper.id).toSet();

    if (mode == SavedPaperImportMode.replaceSameLineage) {
      final target = inspection.replaceTarget;
      if (!inspection.canReplace || target == null) {
        throw StateError(
          inspection.replaceBlockedReason ??
              'This paper cannot replace the existing Saved Paper.',
        );
      }
      final currentMatches = papers
          .where((paper) => paper.id == target.id)
          .toList(growable: false);
      if (currentMatches.length != 1) {
        throw StateError(
          'The matching Saved Paper changed after the import preview. Re-open the .eds file and try again.',
        );
      }
      final current = currentMatches.single;
      if (current.originId != snapshot.paper.originId) {
        throw StateError('EduSheet blocked a cross-lineage paper replacement.');
      }
      if (current.revision != target.revision) {
        throw StateError(
          'The matching Saved Paper was edited after the import preview. EduSheet kept the newer local work unchanged.',
        );
      }
      if (snapshot.paper.revision <= current.revision) {
        throw StateError(
          'Only a newer revision can replace the matching local paper.',
        );
      }
      return _replaceTarget(snapshot, current);
    }

    if (maximumSavedPaperCount != null &&
        papers.length >= maximumSavedPaperCount) {
      throw SavedPaperImportLimitException(
        'Free saved-paper limit reached. The file remains available, and an existing matching paper can still be replaced.',
      );
    }

    final lineageExists = papers.any(
      (paper) => paper.originId == snapshot.paper.originId,
    );
    final originalIdAvailable = !reservedIds.contains(snapshot.paper.id);
    final targetId = !lineageExists && originalIdAvailable
        ? snapshot.paper.id
        : _nextUniqueId(reservedIds);
    return _materializeAndSave(
      snapshot,
      targetId: targetId,
      mode: SavedPaperImportMode.addAsNew,
      usedOriginalLocalId: targetId == snapshot.paper.id,
    );
  }

  Future<SavedPaperImportResult> _replaceTarget(
    PortablePaperSnapshot snapshot,
    Paper target,
  ) async {
    final materialized = await _assetStore.materialize(
      snapshot,
      targetPaperId: target.id,
    );
    final restored = snapshot.restoreWithPaths(
      materialized.resolvedPaths,
      paperId: target.id,
    );

    try {
      final repository = _paperRepository;
      final importRepository = switch (repository) {
        PaperImportRepository importRepository => importRepository,
        _ => null,
      };
      if (importRepository == null) {
        throw StateError(
          'This Saved Paper repository does not support atomic lineage replacement. Add the file as a new paper instead.',
        );
      }
      await importRepository.replacePaperFromImport(
        restored,
        expectedOriginId: target.originId,
        expectedRevision: target.revision,
      );
      return SavedPaperImportResult(
        paper: restored,
        mode: SavedPaperImportMode.replaceSameLineage,
        usedOriginalLocalId: restored.id == snapshot.paper.id,
        createdAssetDirectory: materialized.directoryPath,
      );
    } catch (_) {
      await _assetStore.deleteMaterialization(materialized.directoryPath);
      rethrow;
    }
  }

  Future<SavedPaperImportResult> _materializeAndSave(
    PortablePaperSnapshot snapshot, {
    required String targetId,
    required SavedPaperImportMode mode,
    required bool usedOriginalLocalId,
  }) async {
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
      return SavedPaperImportResult(
        paper: restored,
        mode: mode,
        usedOriginalLocalId: usedOriginalLocalId,
        createdAssetDirectory: materialized.directoryPath,
      );
    } catch (_) {
      // Never issue a compensating delete here: another local save could have
      // claimed the id between preview and persistence. Atomic repositories
      // either commit the imported paper or keep their previous generation.
      await _assetStore.deleteMaterialization(materialized.directoryPath);
      rethrow;
    }
  }

  String _nextUniqueId(Set<String> reserved) {
    for (var attempt = 0; attempt < 100; attempt++) {
      final candidate = _idGenerator().trim();
      if (candidate.isNotEmpty && !reserved.contains(candidate)) {
        return candidate;
      }
    }
    throw StateError('Could not allocate a safe Saved Paper id for import.');
  }
}
