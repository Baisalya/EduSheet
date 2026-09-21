import 'package:edusheet/features/editor/application/saved_paper_eds_service.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/teaching_planner/data/curriculum_eds_package_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';

import '../domain/eds_import_inspection.dart';

/// Detects and validates an EduSheet portable file before any mutation occurs.
///
/// Detection and structural validation stay centralized. Feature-specific
/// services own mutation. Curriculum packages are structurally validated here
/// and Phase 6 imports them through the origin/revision-aware merge engine.
class EdsImportRouter {
  EdsImportRouter({
    required PaperRepository paperRepository,
    EdsUnifiedContainer container = const EdsUnifiedContainer(),
    TeachingPlannerBackupCodec plannerCodec = const TeachingPlannerBackupCodec(),
    CurriculumEdsPackageCodec curriculumCodec = const CurriculumEdsPackageCodec(),
  }) : _container = container,
       _plannerCodec = plannerCodec,
       _curriculumCodec = curriculumCodec,
       _paperService = SavedPaperEdsService(paperRepository: paperRepository);

  final EdsUnifiedContainer _container;
  final TeachingPlannerBackupCodec _plannerCodec;
  final CurriculumEdsPackageCodec _curriculumCodec;
  final SavedPaperEdsService _paperService;

  Future<EdsImportInspection> inspect(String source) async {
    if (_container.looksLikeUnified(source)) {
      final package = _container.decode(source);
      switch (package.manifest.contentType) {
        case EdsContentType.paper:
          final paper = await _paperService.inspect(source);
          return PaperEdsImportInspection(paperInspection: paper);
        case EdsContentType.plannerBackup:
          final payload = _plannerCodec.decodePayload(source);
          return PlannerBackupEdsImportInspection(
            payload: payload,
            isLegacy: false,
            manifest: package.manifest,
          );
        case EdsContentType.chapterPack:
        case EdsContentType.subjectPack:
        case EdsContentType.syllabus:
        case EdsContentType.teacherPack:
        case EdsContentType.schoolCurriculum:
          final preview = _curriculumCodec.decode(source);
          return CurriculumPackageEdsImportInspection(preview: preview);
      }
    }

    // v1-v3 Teaching Planner files predate the universal envelope. Validate
    // them with the owning legacy codec instead of guessing from file names.
    try {
      final payload = _plannerCodec.decodePayload(source);
      return PlannerBackupEdsImportInspection(
        payload: payload,
        isLegacy: true,
      );
    } catch (_) {
      throw const FormatException(
        'This file is not a supported EduSheet .eds package.',
      );
    }
  }
}
