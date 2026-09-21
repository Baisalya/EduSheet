import 'package:edusheet/shared/portable/eds_unified_container.dart';

import 'teaching_planner_workspace.dart';

/// User-selected curriculum slice to be exported as a portable `.eds` package.
enum CurriculumPackageScopeKind {
  schoolCurriculum,
  classSyllabus,
  subject,
  selectedUnits,
  selectedChapters,
  selectedLessons,
}

class CurriculumPackageSelection {
  final CurriculumPackageScopeKind kind;
  final String? classId;
  final String? subjectId;
  final Set<String> unitIds;
  final Set<String> chapterIds;
  final Set<String> lessonPlanIds;

  CurriculumPackageSelection({
    required this.kind,
    this.classId,
    this.subjectId,
    Set<String> unitIds = const {},
    Set<String> chapterIds = const {},
    Set<String> lessonPlanIds = const {},
  }) : unitIds = Set.unmodifiable(unitIds),
       chapterIds = Set.unmodifiable(chapterIds),
       lessonPlanIds = Set.unmodifiable(lessonPlanIds);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    if (classId != null) 'classId': classId,
    if (subjectId != null) 'subjectId': subjectId,
    if (unitIds.isNotEmpty) 'unitIds': unitIds.toList()..sort(),
    if (chapterIds.isNotEmpty) 'chapterIds': chapterIds.toList()..sort(),
    if (lessonPlanIds.isNotEmpty)
      'lessonPlanIds': lessonPlanIds.toList()..sort(),
  };

  factory CurriculumPackageSelection.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString() ?? '';
    final kind = CurriculumPackageScopeKind.values.firstWhere(
      (item) => item.name == kindName,
      orElse: () =>
          throw FormatException('Unknown curriculum package scope: $kindName'),
    );
    return CurriculumPackageSelection(
      kind: kind,
      classId: _optionalText(json['classId']),
      subjectId: _optionalText(json['subjectId']),
      unitIds: _stringSet(json['unitIds']),
      chapterIds: _stringSet(json['chapterIds']),
      lessonPlanIds: _stringSet(json['lessonPlanIds']),
    );
  }
}

class CurriculumPackageInclusions {
  final bool includeLessonPlans;
  final bool includeNotes;
  final bool includeFiles;
  final bool includeLinks;
  final bool includeGeometry;
  final bool includePapers;

  const CurriculumPackageInclusions({
    this.includeLessonPlans = true,
    this.includeNotes = true,
    this.includeFiles = true,
    this.includeLinks = true,
    this.includeGeometry = true,
    this.includePapers = true,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lessonPlans': includeLessonPlans,
    'notes': includeNotes,
    'files': includeFiles,
    'links': includeLinks,
    'geometry': includeGeometry,
    'papers': includePapers,
  };

  factory CurriculumPackageInclusions.fromJson(Map<String, dynamic> json) {
    bool value(String key, {bool fallback = true}) {
      final raw = json[key];
      return raw is bool ? raw : fallback;
    }

    return CurriculumPackageInclusions(
      includeLessonPlans: value('lessonPlans'),
      includeNotes: value('notes'),
      includeFiles: value('files'),
      includeLinks: value('links'),
      includeGeometry: value('geometry'),
      includePapers: value('papers'),
    );
  }
}

/// Offline assignment intent only. This metadata is not a security boundary.
class CurriculumAssignmentMetadata {
  final String assignmentId;
  final String? assignedTo;
  final String roleIntent;
  final bool editable;
  final String? sourceSchool;
  final String? note;

  const CurriculumAssignmentMetadata({
    required this.assignmentId,
    this.assignedTo,
    this.roleIntent = 'teacher',
    this.editable = true,
    this.sourceSchool,
    this.note,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'assignmentId': assignmentId,
    if (assignedTo != null) 'assignedTo': assignedTo,
    'roleIntent': roleIntent,
    'editable': editable,
    if (sourceSchool != null) 'sourceSchool': sourceSchool,
    if (note != null) 'note': note,
  };

  factory CurriculumAssignmentMetadata.fromJson(Map<String, dynamic> json) {
    final assignmentId = json['assignmentId']?.toString().trim() ?? '';
    if (assignmentId.isEmpty) {
      throw const FormatException('Teacher assignment id is missing.');
    }
    return CurriculumAssignmentMetadata(
      assignmentId: assignmentId,
      assignedTo: _optionalText(json['assignedTo']),
      roleIntent: _optionalText(json['roleIntent']) ?? 'teacher',
      editable: json['editable'] is bool ? json['editable'] as bool : true,
      sourceSchool: _optionalText(json['sourceSchool']),
      note: _optionalText(json['note']),
    );
  }
}

/// Sidecar lineage contract for future merge/sync. Existing local planner ids
/// become the first canonical origins; Phase 6 can map them to different local
/// replica ids without changing this package format.
class CurriculumEntityLineage {
  final String entityType;
  final String entityId;
  final String originId;
  final int revision;
  final DateTime updatedAt;

  const CurriculumEntityLineage({
    required this.entityType,
    required this.entityId,
    required this.originId,
    required this.revision,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entityType': entityType,
    'entityId': entityId,
    'originId': originId,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory CurriculumEntityLineage.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final revision = _positiveInt(json['revision']);
    final entityType = json['entityType']?.toString().trim() ?? '';
    final entityId = json['entityId']?.toString().trim() ?? '';
    final originId = json['originId']?.toString().trim() ?? '';
    if (updatedAt == null ||
        revision < 1 ||
        entityType.isEmpty ||
        entityId.isEmpty ||
        originId.isEmpty) {
      throw const FormatException('Curriculum lineage entry is invalid.');
    }
    return CurriculumEntityLineage(
      entityType: entityType,
      entityId: entityId,
      originId: originId,
      revision: revision,
      updatedAt: updatedAt,
    );
  }
}

class CurriculumPackagePayload {
  final EdsContentType contentType;
  final CurriculumPackageSelection selection;
  final CurriculumPackageInclusions inclusions;
  final CurriculumAssignmentMetadata? assignment;
  final String? sourceSchool;
  final TeachingPlannerWorkspace workspace;
  final Map<String, List<int>> resourceFiles;
  final Map<String, dynamic> paperSnapshotsJson;
  final List<CurriculumEntityLineage> lineage;

  CurriculumPackagePayload({
    required this.contentType,
    required this.selection,
    required this.inclusions,
    required this.workspace,
    required Map<String, List<int>> resourceFiles,
    required Map<String, dynamic> paperSnapshotsJson,
    required List<CurriculumEntityLineage> lineage,
    this.assignment,
    this.sourceSchool,
  }) : resourceFiles = Map.unmodifiable(resourceFiles),
       paperSnapshotsJson = Map.unmodifiable(paperSnapshotsJson),
       lineage = List.unmodifiable(lineage);

  int get paperCount => paperSnapshotsJson.length;
  int get attachmentCount => resourceFiles.length;
}

class CurriculumPackagePreview {
  final EdsPackageManifest manifest;
  final CurriculumPackagePayload payload;

  const CurriculumPackagePreview({
    required this.manifest,
    required this.payload,
  });
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

Set<String> _stringSet(Object? value) {
  if (value == null) return const {};
  if (value is! List) {
    throw const FormatException('Curriculum id selection must be a list.');
  }
  final result = <String>{};
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const FormatException(
        'Curriculum id selection contains an empty id.',
      );
    }
    result.add(text);
  }
  return result;
}

int _positiveInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}
