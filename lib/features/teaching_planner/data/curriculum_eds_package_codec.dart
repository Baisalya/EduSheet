import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'package:edusheet/shared/portable/eds_unified_container.dart';

import '../application/curriculum_package_builder_service.dart';
import '../domain/models/curriculum_package.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/models/teaching_resource_owner.dart';
import 'portable_attachment_manifest.dart';
import 'portable_paper_snapshot.dart';
import 'teaching_planner_document_codec.dart';

class CurriculumEdsPackageCodec {
  const CurriculumEdsPackageCodec({
    EdsUnifiedContainer container = const EdsUnifiedContainer(),
    TeachingPlannerDocumentCodec documentCodec =
        const TeachingPlannerDocumentCodec(),
  }) : _container = container,
       _documentCodec = documentCodec;

  final EdsUnifiedContainer _container;
  final TeachingPlannerDocumentCodec _documentCodec;

  static const String format = 'edusheet.curriculum-package';
  static const int version = 1;
  static const int packageSchemaVersion = 1;

  String encode({
    required CurriculumPackageBuildResult build,
    required CurriculumPackageSelection selection,
    required CurriculumPackageInclusions inclusions,
    CurriculumAssignmentMetadata? assignment,
    String? sourceSchool,
    DateTime? exportedAt,
  }) {
    _validateContentType(build.contentType);
    _validateSelectionShape(selection);
    final expectedType = assignment == null
        ? _contentTypeForSelection(selection)
        : EdsContentType.teacherPack;
    if (build.contentType != expectedType) {
      throw const FormatException(
        'Curriculum build type does not match its selected scope.',
      );
    }
    if (build.contentType == EdsContentType.teacherPack && assignment == null) {
      throw const FormatException(
        'Teacher assignment package is missing assignment metadata.',
      );
    }
    if (build.contentType != EdsContentType.teacherPack && assignment != null) {
      throw const FormatException(
        'Assignment metadata can only be carried by a teacher package.',
      );
    }
    if (assignment != null) {
      final assignmentId = assignment.assignmentId.trim();
      if (assignmentId.isEmpty ||
          assignment.roleIntent.trim().isEmpty ||
          build.entityId != assignmentId ||
          build.originId != assignmentId) {
        throw const FormatException(
          'Teacher assignment lineage metadata is inconsistent.',
        );
      }
    } else {
      final expectedIdentity = _expectedPackageIdentity(
        build.workspace,
        selection,
      );
      if (build.entityId != expectedIdentity ||
          build.originId != expectedIdentity) {
        throw const FormatException(
          'Curriculum build identity does not match its selected scope.',
        );
      }
    }
    _validateSelectionBindings(build.workspace, selection);
    _validateResourceScope(build.workspace, selection);
    _validateEmbeddedFiles(build);
    _validateLineage(build.workspace, build.paperSnapshots, build.lineage);

    final exportTime = exportedAt ?? DateTime.now();
    final assignmentSchool = _optionalText(assignment?.sourceSchool);
    final explicitSchool = _optionalText(sourceSchool);
    if (assignmentSchool != null &&
        explicitSchool != null &&
        assignmentSchool != explicitSchool) {
      throw const FormatException(
        'Teacher assignment school metadata is inconsistent.',
      );
    }
    final normalizedSchool = assignmentSchool ?? explicitSchool;
    final document = _documentCodec.encode(
      build.workspace,
      updatedAt: exportTime,
    );
    final attachmentManifest = build.resourceFiles.isEmpty
        ? const <String, dynamic>{}
        : buildPortableAttachmentManifest(
            build.workspace.resources,
            build.resourceFiles,
          );
    if (attachmentManifest.isNotEmpty) {
      verifyPortableAttachmentManifest(
        resources: build.workspace.resources,
        files: build.resourceFiles,
        rawManifest: attachmentManifest,
      );
    }
    final payload = <String, dynamic>{
      'format': format,
      'version': version,
      'selection': selection.toJson(),
      'inclusions': inclusions.toJson(),
      if (assignment != null) 'assignment': assignment.toJson(),
      'sourceSchool': ?normalizedSchool,
      'document': document,
      if (build.resourceFiles.isNotEmpty)
        'resourceFiles': <String, String>{
          for (final entry in build.resourceFiles.entries)
            entry.key: base64Encode(entry.value),
        },
      if (attachmentManifest.isNotEmpty)
        'attachmentManifest': attachmentManifest,
      if (build.paperSnapshots.isNotEmpty)
        'paperSnapshots': <String, dynamic>{
          for (final entry in build.paperSnapshots.entries)
            entry.key: entry.value.toJson(),
        },
      'lineage': build.lineage.map((item) => item.toJson()).toList(),
    };

    final metadata = _manifestMetadata(
      build,
      selection: selection,
      assignment: assignment,
      sourceSchool: normalizedSchool,
    );
    final manifest = EdsPackageManifest(
      packageId: const Uuid().v4(),
      contentType: build.contentType,
      schemaVersion: packageSchemaVersion,
      entityId: build.entityId,
      originId: build.originId,
      revision: build.revision,
      title: build.title,
      exportedAt: exportTime,
      metadata: metadata,
    );
    return _container.encode(manifest: manifest, payload: payload);
  }

  CurriculumPackagePreview decode(String source) {
    final package = _container.decode(source);
    _validateContentType(package.manifest.contentType);
    if (package.manifest.schemaVersion != packageSchemaVersion) {
      throw const FormatException(
        'Unsupported EduSheet curriculum package schema version.',
      );
    }
    final json = package.payload;
    if (json['format'] != format || _int(json['version']) != version) {
      throw const FormatException('Unsupported EduSheet curriculum package.');
    }
    final selectionJson = json['selection'];
    final inclusionsJson = json['inclusions'];
    final document = json['document'];
    if (selectionJson is! Map || inclusionsJson is! Map) {
      throw const FormatException(
        'Curriculum package selection metadata is missing.',
      );
    }

    final selection = CurriculumPackageSelection.fromJson(
      Map<String, dynamic>.from(selectionJson),
    );
    final inclusions = CurriculumPackageInclusions.fromJson(
      Map<String, dynamic>.from(inclusionsJson),
    );
    _validateSelectionShape(selection);
    final workspace = _documentCodec.decode(document);
    final sourceSchool = _optionalText(json['sourceSchool']);
    final assignmentJson = json['assignment'];
    final assignment = assignmentJson is Map
        ? CurriculumAssignmentMetadata.fromJson(
            Map<String, dynamic>.from(assignmentJson),
          )
        : null;
    if (package.manifest.contentType == EdsContentType.teacherPack &&
        assignment == null) {
      throw const FormatException(
        'Teacher package is missing assignment metadata.',
      );
    }
    if (package.manifest.contentType != EdsContentType.teacherPack &&
        assignment != null) {
      throw const FormatException(
        'Only teacher packages can contain assignment metadata.',
      );
    }
    final manifestSchool = _optionalText(
      package.manifest.metadata['sourceSchool'],
    );
    if (manifestSchool != sourceSchool ||
        (assignment?.sourceSchool != null &&
            _optionalText(assignment?.sourceSchool) != sourceSchool)) {
      throw const FormatException(
        'Curriculum package school metadata is inconsistent.',
      );
    }
    final expectedType = assignment == null
        ? _contentTypeForSelection(selection)
        : EdsContentType.teacherPack;
    if (package.manifest.contentType != expectedType) {
      throw const FormatException(
        'Curriculum package content type does not match its selected scope.',
      );
    }
    if (assignment != null) {
      if (package.manifest.entityId != assignment.assignmentId ||
          package.manifest.originId != assignment.assignmentId) {
        throw const FormatException(
          'Teacher package assignment lineage does not match its manifest.',
        );
      }
    } else {
      final expectedIdentity = _expectedPackageIdentity(workspace, selection);
      if (package.manifest.entityId != expectedIdentity ||
          package.manifest.originId != expectedIdentity) {
        throw const FormatException(
          'Curriculum package identity does not match its selected scope.',
        );
      }
    }
    _validateSelectionBindings(workspace, selection);
    _validateResourceScope(workspace, selection);

    final resourceFiles = _decodeResourceFiles(json['resourceFiles']);
    final paperSnapshots = _decodePaperSnapshots(json['paperSnapshots']);
    _validateDecodedAssets(workspace.resources, resourceFiles, paperSnapshots);
    verifyPortableAttachmentManifest(
      resources: workspace.resources,
      files: resourceFiles,
      rawManifest: json['attachmentManifest'],
    );
    final lineage = _decodeLineage(json['lineage']);
    _validateLineage(workspace, paperSnapshots, lineage);

    return CurriculumPackagePreview(
      manifest: package.manifest,
      payload: CurriculumPackagePayload(
        contentType: package.manifest.contentType,
        selection: selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: sourceSchool,
        workspace: workspace,
        resourceFiles: resourceFiles,
        paperSnapshotsJson: <String, dynamic>{
          for (final entry in paperSnapshots.entries)
            entry.key: entry.value.toJson(),
        },
        lineage: lineage,
      ),
    );
  }

  String _expectedPackageIdentity(
    TeachingPlannerWorkspace workspace,
    CurriculumPackageSelection selection,
  ) {
    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum => _selectionIdentity(
        'school-curriculum',
        workspace.classes.map((item) => item.id).toSet(),
      ),
      CurriculumPackageScopeKind.classSyllabus => _requiredId(
        selection.classId,
        'class',
      ),
      CurriculumPackageScopeKind.subject => _requiredId(
        selection.subjectId,
        'subject',
      ),
      CurriculumPackageScopeKind.selectedUnits => _selectionIdentity(
        'units',
        selection.unitIds,
      ),
      CurriculumPackageScopeKind.selectedChapters => _selectionIdentity(
        'chapters',
        selection.chapterIds,
      ),
      CurriculumPackageScopeKind.selectedLessons => _selectionIdentity(
        'lessons',
        selection.lessonPlanIds,
      ),
    };
  }

  EdsContentType _contentTypeForSelection(
    CurriculumPackageSelection selection,
  ) {
    return switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        EdsContentType.schoolCurriculum,
      CurriculumPackageScopeKind.classSyllabus => EdsContentType.syllabus,
      CurriculumPackageScopeKind.subject => EdsContentType.subjectPack,
      CurriculumPackageScopeKind.selectedUnits => EdsContentType.subjectPack,
      CurriculumPackageScopeKind.selectedChapters => EdsContentType.chapterPack,
      CurriculumPackageScopeKind.selectedLessons => EdsContentType.chapterPack,
    };
  }

  void _validateSelectionShape(CurriculumPackageSelection selection) {
    final hasClass = selection.classId != null;
    final hasSubject = selection.subjectId != null;
    final hasUnits = selection.unitIds.isNotEmpty;
    final hasChapters = selection.chapterIds.isNotEmpty;
    final hasLessons = selection.lessonPlanIds.isNotEmpty;

    final valid = switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        !hasClass && !hasSubject && !hasUnits && !hasChapters && !hasLessons,
      CurriculumPackageScopeKind.classSyllabus =>
        hasClass && !hasSubject && !hasUnits && !hasChapters && !hasLessons,
      CurriculumPackageScopeKind.subject =>
        hasClass && hasSubject && !hasUnits && !hasChapters && !hasLessons,
      CurriculumPackageScopeKind.selectedUnits =>
        hasClass && hasSubject && hasUnits && !hasChapters && !hasLessons,
      CurriculumPackageScopeKind.selectedChapters =>
        hasClass && hasSubject && !hasUnits && hasChapters && !hasLessons,
      CurriculumPackageScopeKind.selectedLessons =>
        hasClass && hasSubject && !hasUnits && !hasChapters && hasLessons,
    };
    if (!valid) {
      throw const FormatException(
        'Curriculum package selection contains mixed or incomplete scope ids.',
      );
    }
  }

  void _validateSelectionBindings(
    TeachingPlannerWorkspace workspace,
    CurriculumPackageSelection selection,
  ) {
    switch (selection.kind) {
      case CurriculumPackageScopeKind.schoolCurriculum:
        if (workspace.classes.isEmpty) {
          throw const FormatException('School curriculum package is empty.');
        }
        return;
      case CurriculumPackageScopeKind.classSyllabus:
        final classId = _requiredId(selection.classId, 'class');
        if (!_sameIds(workspace.classes.map((item) => item.id), {classId}) ||
            workspace.subjects.any((item) => item.classId != classId)) {
          throw const FormatException(
            'Class syllabus package contains data outside its selected class.',
          );
        }
        return;
      case CurriculumPackageScopeKind.subject:
        final binding = _subjectBinding(workspace, selection);
        if (!_sameIds(workspace.classes.map((item) => item.id), {binding.$1}) ||
            !_sameIds(workspace.subjects.map((item) => item.id), {
              binding.$2,
            })) {
          throw const FormatException(
            'Subject package contains data outside its selected hierarchy.',
          );
        }
        return;
      case CurriculumPackageScopeKind.selectedUnits:
        final binding = _subjectBinding(workspace, selection);
        if (selection.unitIds.isEmpty ||
            !_sameIds(workspace.classes.map((item) => item.id), {binding.$1}) ||
            !_sameIds(workspace.subjects.map((item) => item.id), {
              binding.$2,
            }) ||
            !_sameIds(
              workspace.units.map((item) => item.id),
              selection.unitIds,
            ) ||
            workspace.units.any((item) => item.subjectId != binding.$2) ||
            workspace.chapters.any(
              (item) =>
                  item.subjectId != binding.$2 ||
                  item.unitId == null ||
                  !selection.unitIds.contains(item.unitId),
            )) {
          throw const FormatException(
            'Unit package contains data outside its selected units.',
          );
        }
        return;
      case CurriculumPackageScopeKind.selectedChapters:
        final binding = _subjectBinding(workspace, selection);
        final chapters = workspace.chapters;
        final expectedUnitIds = chapters
            .map((item) => item.unitId)
            .whereType<String>()
            .toSet();
        if (selection.chapterIds.isEmpty ||
            !_sameIds(workspace.classes.map((item) => item.id), {binding.$1}) ||
            !_sameIds(workspace.subjects.map((item) => item.id), {
              binding.$2,
            }) ||
            !_sameIds(chapters.map((item) => item.id), selection.chapterIds) ||
            chapters.any((item) => item.subjectId != binding.$2) ||
            !_sameIds(
              workspace.units.map((item) => item.id),
              expectedUnitIds,
            ) ||
            workspace.topics.any(
              (item) => !selection.chapterIds.contains(item.chapterId),
            ) ||
            workspace.lessonPlans.any(
              (item) =>
                  item.classId != binding.$1 ||
                  item.subjectId != binding.$2 ||
                  !selection.chapterIds.contains(item.chapterId),
            )) {
          throw const FormatException(
            'Chapter package contains data outside its selected chapters.',
          );
        }
        return;
      case CurriculumPackageScopeKind.selectedLessons:
        final binding = _subjectBinding(workspace, selection);
        final lessons = workspace.lessonPlans;
        final expectedChapterIds = lessons
            .map((item) => item.chapterId)
            .toSet();
        final expectedTopicIds = lessons
            .expand((item) => item.topicIds)
            .toSet();
        final expectedUnitIds = workspace.chapters
            .map((item) => item.unitId)
            .whereType<String>()
            .toSet();
        if (selection.lessonPlanIds.isEmpty ||
            !_sameIds(workspace.classes.map((item) => item.id), {binding.$1}) ||
            !_sameIds(workspace.subjects.map((item) => item.id), {
              binding.$2,
            }) ||
            !_sameIds(
              lessons.map((item) => item.id),
              selection.lessonPlanIds,
            ) ||
            lessons.any(
              (item) =>
                  item.classId != binding.$1 || item.subjectId != binding.$2,
            ) ||
            !_sameIds(
              workspace.chapters.map((item) => item.id),
              expectedChapterIds,
            ) ||
            workspace.chapters.any((item) => item.subjectId != binding.$2) ||
            !_sameIds(
              workspace.units.map((item) => item.id),
              expectedUnitIds,
            ) ||
            !_sameIds(
              workspace.topics.map((item) => item.id),
              expectedTopicIds,
            )) {
          throw const FormatException(
            'Lesson package contains data outside its selected lessons.',
          );
        }
        return;
    }
  }

  void _validateResourceScope(
    TeachingPlannerWorkspace workspace,
    CurriculumPackageSelection selection,
  ) {
    bool allowed(TeachingResource resource) {
      final owner = resource.owner;
      return switch (selection.kind) {
        CurriculumPackageScopeKind.schoolCurriculum => true,
        CurriculumPackageScopeKind.classSyllabus => true,
        CurriculumPackageScopeKind.subject =>
          owner.type != TeachingResourceOwnerType.plannerClass,
        CurriculumPackageScopeKind.selectedUnits => switch (owner.type) {
          TeachingResourceOwnerType.plannerClass => false,
          TeachingResourceOwnerType.subject => false,
          TeachingResourceOwnerType.unit => selection.unitIds.contains(
            owner.id,
          ),
          TeachingResourceOwnerType.chapter => true,
          TeachingResourceOwnerType.topic => true,
          TeachingResourceOwnerType.lessonPlan => true,
        },
        CurriculumPackageScopeKind.selectedChapters => switch (owner.type) {
          TeachingResourceOwnerType.plannerClass => false,
          TeachingResourceOwnerType.subject => false,
          TeachingResourceOwnerType.unit => false,
          TeachingResourceOwnerType.chapter => selection.chapterIds.contains(
            owner.id,
          ),
          TeachingResourceOwnerType.topic => true,
          TeachingResourceOwnerType.lessonPlan => true,
        },
        CurriculumPackageScopeKind.selectedLessons =>
          owner.type == TeachingResourceOwnerType.lessonPlan &&
              selection.lessonPlanIds.contains(owner.id),
      };
    }

    if (workspace.resources.any((resource) => !allowed(resource))) {
      throw const FormatException(
        'Curriculum package contains resources outside its selected scope.',
      );
    }
  }

  (String, String) _subjectBinding(
    TeachingPlannerWorkspace workspace,
    CurriculumPackageSelection selection,
  ) {
    final classId = _requiredId(selection.classId, 'class');
    final subjectId = _requiredId(selection.subjectId, 'subject');
    final plannerClass = workspace.classById(classId);
    final subject = workspace.subjectById(subjectId);
    if (plannerClass == null || subject == null || subject.classId != classId) {
      throw const FormatException(
        'Curriculum package does not contain its selected class and subject.',
      );
    }
    return (classId, subjectId);
  }

  Map<String, dynamic> _manifestMetadata(
    CurriculumPackageBuildResult build, {
    required CurriculumPackageSelection selection,
    required CurriculumAssignmentMetadata? assignment,
    required String? sourceSchool,
  }) {
    final workspace = build.workspace;
    String? academicYear;
    String? className;
    String? subjectName;
    if (workspace.classes.length == 1) {
      className = workspace.classes.single.name;
      academicYear = workspace.classes.single.academicYear;
    }
    if (workspace.subjects.length == 1) {
      subjectName = workspace.subjects.single.name;
    }
    final assignedTo = assignment?.assignedTo;
    return <String, dynamic>{
      'scopeKind': selection.kind.name,
      'sourceSchool': ?sourceSchool,
      'academicYear': ?academicYear,
      'className': ?className,
      'subjectName': ?subjectName,
      'assignedTo': ?assignedTo,
      if (assignment != null) 'assignmentId': assignment.assignmentId,
      if (assignment != null) 'roleIntent': assignment.roleIntent,
      'classCount': workspace.classes.length,
      'subjectCount': workspace.subjects.length,
      'unitCount': workspace.units.length,
      'chapterCount': workspace.chapters.length,
      'topicCount': workspace.topics.length,
      'lessonCount': workspace.lessonPlans.length,
      'resourceCount': workspace.resources.length,
      'paperCount': build.paperSnapshots.length,
      'attachmentCount': build.resourceFiles.length,
    };
  }

  void _validateEmbeddedFiles(CurriculumPackageBuildResult build) {
    final requiredFiles = build.workspace.resources
        .where((item) => item.kind == TeachingResourceKind.file)
        .map((item) => item.id)
        .toSet();
    if (requiredFiles.length != build.resourceFiles.length ||
        !requiredFiles.containsAll(build.resourceFiles.keys)) {
      throw const FormatException(
        'Curriculum package file attachments are incomplete.',
      );
    }

    final requiredPapers = build.workspace.resources
        .where((item) => item.kind == TeachingResourceKind.paper)
        .map((item) => item.linkedPaperId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (requiredPapers.length != build.paperSnapshots.length ||
        !requiredPapers.containsAll(build.paperSnapshots.keys)) {
      throw const FormatException(
        'Curriculum package linked papers are incomplete.',
      );
    }
  }

  Map<String, List<int>> _decodeResourceFiles(Object? value) {
    if (value == null) return const {};
    if (value is! Map) {
      throw const FormatException(
        'Curriculum resourceFiles must be an object.',
      );
    }
    final result = <String, List<int>>{};
    for (final entry in value.entries) {
      if (entry.value is! String) {
        throw const FormatException(
          'Curriculum attachment payload is invalid.',
        );
      }
      result[entry.key.toString()] = base64Decode(entry.value as String);
    }
    return Map.unmodifiable(result);
  }

  Map<String, PortablePaperSnapshot> _decodePaperSnapshots(Object? value) {
    if (value == null) return const {};
    if (value is! Map) {
      throw const FormatException(
        'Curriculum paperSnapshots must be an object.',
      );
    }
    final result = <String, PortablePaperSnapshot>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) {
        throw const FormatException('Curriculum paper snapshot is invalid.');
      }
      result[entry.key.toString()] = PortablePaperSnapshot.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return Map.unmodifiable(result);
  }

  List<CurriculumEntityLineage> _decodeLineage(Object? value) {
    if (value is! List) {
      throw const FormatException('Curriculum lineage metadata is missing.');
    }
    return List.unmodifiable(
      value.map((item) {
        if (item is! Map) {
          throw const FormatException('Curriculum lineage entry is invalid.');
        }
        return CurriculumEntityLineage.fromJson(
          Map<String, dynamic>.from(item),
        );
      }),
    );
  }

  void _validateDecodedAssets(
    List<TeachingResource> resources,
    Map<String, List<int>> resourceFiles,
    Map<String, PortablePaperSnapshot> papers,
  ) {
    final requiredFiles = resources
        .where((item) => item.kind == TeachingResourceKind.file)
        .map((item) => item.id)
        .toSet();
    if (requiredFiles.difference(resourceFiles.keys.toSet()).isNotEmpty ||
        resourceFiles.keys.toSet().difference(requiredFiles).isNotEmpty) {
      throw const FormatException(
        'Curriculum package attachment bindings are inconsistent.',
      );
    }

    final requiredPapers = resources
        .where((item) => item.kind == TeachingResourceKind.paper)
        .map((item) => item.linkedPaperId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (requiredPapers.difference(papers.keys.toSet()).isNotEmpty ||
        papers.keys.toSet().difference(requiredPapers).isNotEmpty) {
      throw const FormatException(
        'Curriculum package paper bindings are inconsistent.',
      );
    }
    for (final entry in papers.entries) {
      if (entry.value.paper.id != entry.key) {
        throw const FormatException(
          'Curriculum package paper id does not match its snapshot.',
        );
      }
    }
  }

  void _validateLineage(
    TeachingPlannerWorkspace workspace,
    Map<String, PortablePaperSnapshot> papers,
    List<CurriculumEntityLineage> lineage,
  ) {
    final expected = <String>{
      for (final item in workspace.classes) 'class:${item.id}',
      for (final item in workspace.subjects) 'subject:${item.id}',
      for (final item in workspace.units) 'unit:${item.id}',
      for (final item in workspace.chapters) 'chapter:${item.id}',
      for (final item in workspace.topics) 'topic:${item.id}',
      for (final item in workspace.lessonPlans) 'lessonPlan:${item.id}',
      for (final item in workspace.resources) 'resource:${item.id}',
      for (final item in papers.values) 'paper:${item.paper.id}',
    };
    final actual = <String>{};
    for (final item in lineage) {
      final key = '${item.entityType}:${item.entityId}';
      if (!actual.add(key)) {
        throw const FormatException('Curriculum lineage contains duplicates.');
      }
    }
    if (expected.difference(actual).isNotEmpty ||
        actual.difference(expected).isNotEmpty) {
      throw const FormatException(
        'Curriculum lineage does not match the packaged entities.',
      );
    }
  }

  void _validateContentType(EdsContentType type) {
    switch (type) {
      case EdsContentType.chapterPack:
      case EdsContentType.subjectPack:
      case EdsContentType.syllabus:
      case EdsContentType.teacherPack:
      case EdsContentType.schoolCurriculum:
        return;
      case EdsContentType.paper:
      case EdsContentType.plannerBackup:
        throw FormatException(
          '${type.name} is not a curriculum package content type.',
        );
    }
  }
}

String _requiredId(String? value, String label) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    throw FormatException('Curriculum package $label id is missing.');
  }
  return text;
}

bool _sameIds(Iterable<String> actual, Set<String> expected) {
  final values = actual.toSet();
  return values.length == expected.length && values.containsAll(expected);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String _selectionIdentity(String prefix, Set<String> ids) {
  final sorted = ids.toList()..sort();
  return '$prefix:${sorted.join(',')}';
}
