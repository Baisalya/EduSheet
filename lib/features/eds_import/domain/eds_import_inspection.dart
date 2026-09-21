import 'package:edusheet/features/editor/application/saved_paper_eds_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/curriculum_package.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';

sealed class EdsImportInspection {
  const EdsImportInspection({
    required this.contentType,
    required this.title,
    required this.isLegacy,
    this.manifest,
  });

  final EdsContentType contentType;
  final String title;
  final bool isLegacy;
  final EdsPackageManifest? manifest;

  bool get canImport;
  String get destinationLabel;
}

final class PaperEdsImportInspection extends EdsImportInspection {
  PaperEdsImportInspection({required this.paperInspection})
    : super(
        contentType: EdsContentType.paper,
        title: paperInspection.package.paper.title,
        isLegacy: false,
        manifest: paperInspection.package.manifest,
      );

  final SavedPaperImportInspection paperInspection;

  @override
  bool get canImport => true;

  @override
  String get destinationLabel => 'Saved Papers';
}

final class PlannerBackupEdsImportInspection extends EdsImportInspection {
  const PlannerBackupEdsImportInspection({
    required this.payload,
    required super.isLegacy,
    super.manifest,
  }) : super(
         contentType: EdsContentType.plannerBackup,
         title: 'EduSheet Teaching Planner',
       );

  final TeachingPlannerBackupPayload payload;

  @override
  bool get canImport => true;

  @override
  String get destinationLabel => 'Teaching Planner';
}

final class CurriculumPackageEdsImportInspection extends EdsImportInspection {
  CurriculumPackageEdsImportInspection({required this.preview})
    : super(
        contentType: preview.manifest.contentType,
        title: preview.manifest.title,
        isLegacy: false,
        manifest: preview.manifest,
      );

  final CurriculumPackagePreview preview;

  @override
  bool get canImport => true;

  @override
  String get destinationLabel => switch (contentType) {
    EdsContentType.chapterPack => 'Teaching Planner · Chapter',
    EdsContentType.subjectPack => 'Teaching Planner · Subject',
    EdsContentType.syllabus => 'Teaching Planner · Syllabus',
    EdsContentType.teacherPack => 'Teacher Workspace',
    EdsContentType.schoolCurriculum => 'School Workspace',
    EdsContentType.paper => 'Saved Papers',
    EdsContentType.plannerBackup => 'Teaching Planner',
  };
}

final class UnsupportedEdsImportInspection extends EdsImportInspection {
  const UnsupportedEdsImportInspection({
    required super.contentType,
    required super.title,
    required super.manifest,
  }) : super(isLegacy: false);

  @override
  bool get canImport => false;

  @override
  String get destinationLabel {
    switch (contentType) {
      case EdsContentType.chapterPack:
        return 'Teaching Planner · Chapter';
      case EdsContentType.subjectPack:
        return 'Teaching Planner · Subject';
      case EdsContentType.syllabus:
        return 'Teaching Planner · Syllabus';
      case EdsContentType.teacherPack:
        return 'Teacher Workspace';
      case EdsContentType.schoolCurriculum:
        return 'School Workspace';
      case EdsContentType.paper:
        return 'Saved Papers';
      case EdsContentType.plannerBackup:
        return 'Teaching Planner';
    }
  }
}
