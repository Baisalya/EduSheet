import 'package:edusheet/features/editor/data/portable/saved_paper_eds_codec.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/eds_import/application/eds_import_router.dart';
import 'package:edusheet/features/eds_import/domain/eds_import_inspection.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  test('routes a canonical v4 paper to Saved Papers', () async {
    final paper = Paper(
      id: 'paper-local',
      originId: 'paper-origin',
      revision: 3,
      updatedAt: now,
      title: 'Class 10 Algebra Test',
      schoolName: 'ABC Public School',
      createdAt: now.subtract(const Duration(days: 2)),
    );
    final source = const SavedPaperEdsCodec().encodeSnapshot(
      PortablePaperSnapshot(paper: paper),
      exportedAt: now,
      packageId: 'package-paper',
    );
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    final inspection = await router.inspect(source);

    expect(inspection, isA<PaperEdsImportInspection>());
    final paperInspection = inspection as PaperEdsImportInspection;
    expect(paperInspection.contentType, EdsContentType.paper);
    expect(paperInspection.destinationLabel, 'Saved Papers');
    expect(paperInspection.canImport, isTrue);
    expect(paperInspection.paperInspection.package.paper.originId, 'paper-origin');
    expect(paperInspection.paperInspection.package.paper.revision, 3);
  });

  test('routes a v4 planner backup to Teaching Planner', () async {
    const codec = TeachingPlannerBackupCodec();
    final source = codec.encode(
      TeachingPlannerWorkspace.empty(),
      exportedAt: now,
    );
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    final inspection = await router.inspect(source);

    expect(inspection, isA<PlannerBackupEdsImportInspection>());
    final planner = inspection as PlannerBackupEdsImportInspection;
    expect(planner.isLegacy, isFalse);
    expect(planner.payload.version, 4);
    expect(planner.destinationLabel, 'Teaching Planner');
    expect(planner.canImport, isTrue);
  });

  test('legacy planner v3 remains discoverable by the universal router', () async {
    const codec = TeachingPlannerBackupCodec();
    final source = codec.encode(
      TeachingPlannerWorkspace.empty(),
      exportedAt: now,
      targetVersion: 3,
    );
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    final inspection = await router.inspect(source);

    expect(inspection, isA<PlannerBackupEdsImportInspection>());
    final planner = inspection as PlannerBackupEdsImportInspection;
    expect(planner.isLegacy, isTrue);
    expect(planner.manifest, isNull);
    expect(planner.payload.version, 3);
  });

  test('malformed curriculum-looking v4 package is rejected before import', () async {
    final source = const EdsUnifiedContainer().encode(
      manifest: EdsPackageManifest(
        packageId: 'package-chapter',
        contentType: EdsContentType.chapterPack,
        schemaVersion: 1,
        entityId: 'chapter-local',
        originId: 'chapter-origin',
        revision: 2,
        title: 'Quadratic Equations',
        exportedAt: now,
      ),
      payload: const <String, dynamic>{'chapter': <String, dynamic>{}},
    );
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    await expectLater(router.inspect(source), throwsFormatException);
  });

  test('curriculum container kinds require their certified package payload', () async {
    const kinds = <EdsContentType>[
      EdsContentType.chapterPack,
      EdsContentType.subjectPack,
      EdsContentType.syllabus,
      EdsContentType.teacherPack,
      EdsContentType.schoolCurriculum,
    ];
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    for (final kind in kinds) {
      final source = const EdsUnifiedContainer().encode(
        manifest: EdsPackageManifest(
          packageId: 'package-placeholder',
          contentType: EdsContentType.chapterPack,
          schemaVersion: 1,
          entityId: 'entity-placeholder',
          originId: 'origin-placeholder',
          revision: 1,
          title: 'Portable placeholder',
          exportedAt: now,
        ),
        payload: const <String, dynamic>{},
      );
      final decoded = const EdsUnifiedContainer().decode(source);
      final typedSource = const EdsUnifiedContainer().encode(
        manifest: EdsPackageManifest(
          packageId: decoded.manifest.packageId,
          contentType: kind,
          schemaVersion: decoded.manifest.schemaVersion,
          entityId: decoded.manifest.entityId,
          originId: decoded.manifest.originId,
          revision: decoded.manifest.revision,
          title: decoded.manifest.title,
          exportedAt: decoded.manifest.exportedAt,
        ),
        payload: decoded.payload,
      );
      await expectLater(router.inspect(typedSource), throwsFormatException);
    }
  });

  test('planner package with an unsupported manifest schema is rejected', () async {
    final valid = const TeachingPlannerBackupCodec().encode(
      TeachingPlannerWorkspace.empty(),
      exportedAt: now,
    );
    final decoded = const EdsUnifiedContainer().decode(valid);
    final source = const EdsUnifiedContainer().encode(
      manifest: EdsPackageManifest(
        packageId: decoded.manifest.packageId,
        contentType: EdsContentType.plannerBackup,
        schemaVersion: 99,
        entityId: decoded.manifest.entityId,
        originId: decoded.manifest.originId,
        revision: decoded.manifest.revision,
        title: decoded.manifest.title,
        exportedAt: decoded.manifest.exportedAt,
      ),
      payload: decoded.payload,
    );
    final router = EdsImportRouter(
      paperRepository: _MemoryPaperRepository(),
    );

    await expectLater(router.inspect(source), throwsFormatException);
  });

  test('invalid input is rejected before any feature import runs', () async {
    final repository = _MemoryPaperRepository();
    final router = EdsImportRouter(paperRepository: repository);

    await expectLater(
      router.inspect('not-an-edusheet-file'),
      throwsFormatException,
    );
    expect(repository.saveCalls, 0);
    expect(repository.deleteCalls, 0);
  });
}

class _MemoryPaperRepository implements PaperRepository {
  final Map<String, Paper> _papers = <String, Paper>{};
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<Paper>> getAllPapers() async =>
      _papers.values.map((paper) => Paper.fromJson(paper.toJson())).toList();

  @override
  Future<void> savePaper(Paper paper) async {
    saveCalls++;
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }

  @override
  Future<void> deletePaper(String id) async {
    deleteCalls++;
    _papers.remove(id);
  }
}
