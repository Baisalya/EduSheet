import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../data/teaching_resource_file_store.dart';
import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import '../domain/models/teaching_resource_owner.dart';
import 'teaching_planner_service.dart';
import 'teaching_resource_file_metadata.dart';

class TeachingAttachmentCandidate {
  final String fileName;
  final Uint8List bytes;
  final String? sourcePath;
  final int? sourceSizeBytes;

  const TeachingAttachmentCandidate({
    required this.fileName,
    required this.bytes,
    this.sourcePath,
    this.sourceSizeBytes,
  });

  int get sizeBytes => sourceSizeBytes ?? bytes.length;
}

typedef TeachingResourceAttachmentIdGenerator = String Function();

class TeachingResourceAttachmentService {
  TeachingResourceAttachmentService(
    this._plannerService,
    this._fileStore, {
    TeachingResourceAttachmentIdGenerator? idGenerator,
  }) : _idGenerator = idGenerator ?? (() => const Uuid().v4());

  final TeachingPlannerService _plannerService;
  final TeachingResourceFileStore _fileStore;
  final TeachingResourceAttachmentIdGenerator _idGenerator;

  Future<TeachingPlannerWorkspace> attachFiles({
    required TeachingResourceOwner owner,
    required List<TeachingAttachmentCandidate> files,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
  }) async {
    if (files.isEmpty) {
      throw const TeachingPlannerOperationException(
        'Choose at least one file to attach.',
      );
    }

    final writtenResourceIds = <String>[];
    final drafts = <TeachingFileResourceDraft>[];
    try {
      for (final candidate in files) {
        final fileName = candidate.fileName.trim();
        if (fileName.isEmpty) {
          throw const TeachingPlannerOperationException(
            'Attached file name cannot be empty.',
          );
        }
        final id = _idGenerator();
        writtenResourceIds.add(id);
        final blob = await _fileStore.writeManagedBlob(
          fileName: fileName,
          bytes: candidate.bytes,
        );
        final relativePath = blob.relativePath;
        drafts.add(
          TeachingFileResourceDraft(
            id: id,
            role: role,
            title: fileName,
            originalFileName: fileName,
            mimeType: TeachingResourceFileMetadata.mimeTypeForFileName(
              fileName,
            ),
            localRelativePath: relativePath,
            sizeBytes: candidate.bytes.length,
            contentSha256: blob.sha256Hex,
          ),
        );
      }

      return await _plannerService.createTeachingFileResources(
        owner: owner,
        files: drafts,
      );
    } catch (_) {
      for (final resourceId in writtenResourceIds) {
        try {
          await _fileStore.deleteResourceFiles(resourceId);
        } catch (_) {
          // Best-effort rollback. Never hide the original persistence failure.
        }
      }
      rethrow;
    }
  }

  Future<TeachingPlannerWorkspace> attachLinkedFiles({
    required TeachingResourceOwner owner,
    required List<TeachingAttachmentCandidate> files,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
  }) async {
    if (files.isEmpty) {
      throw const TeachingPlannerOperationException(
        'Choose at least one file to link.',
      );
    }
    final drafts = <TeachingFileResourceDraft>[];
    for (final candidate in files) {
      final fileName = candidate.fileName.trim();
      final sourcePath = candidate.sourcePath?.trim() ?? '';
      if (fileName.isEmpty || sourcePath.isEmpty) {
        throw const TeachingPlannerOperationException(
          'The selected file cannot be linked on this device.',
        );
      }
      drafts.add(
        TeachingFileResourceDraft(
          id: _idGenerator(),
          role: role,
          title: fileName,
          originalFileName: fileName,
          mimeType: TeachingResourceFileMetadata.mimeTypeForFileName(fileName),
          fileOwnership: TeachingResourceFileOwnership.linkedExternal,
          externalFilePath: sourcePath,
          sizeBytes: candidate.sizeBytes,
        ),
      );
    }
    return _plannerService.createTeachingFileResources(
      owner: owner,
      files: drafts,
    );
  }

  Future<TeachingPlannerWorkspace> replaceWithManagedCopy({
    required TeachingResource resource,
    required TeachingAttachmentCandidate file,
  }) async {
    if (resource.kind != TeachingResourceKind.file) {
      throw const TeachingPlannerOperationException(
        'Only file resources can be replaced.',
      );
    }
    final fileName = file.fileName.trim();
    if (fileName.isEmpty) {
      throw const TeachingPlannerOperationException(
        'Replacement file name cannot be empty.',
      );
    }

    // Copy-on-write: stage the new content-addressed blob first. The existing
    // attachment remains untouched until planner metadata commits successfully.
    final blob = await _fileStore.writeManagedBlob(
      fileName: fileName,
      bytes: file.bytes,
    );
    final updated = await _plannerService.updateTeachingFileLocation(
      resource.id,
      originalFileName: fileName,
      mimeType: TeachingResourceFileMetadata.mimeTypeForFileName(fileName),
      fileOwnership: TeachingResourceFileOwnership.managed,
      localRelativePath: blob.relativePath,
      externalFilePath: null,
      sizeBytes: file.bytes.length,
      contentSha256: blob.sha256Hex,
    );
    if (resource.fileOwnership == TeachingResourceFileOwnership.managed) {
      try {
        // Removes only the legacy resource-id directory. Shared Phase-4 blobs
        // are reference-safe and are reclaimed by storage maintenance later.
        await _fileStore.deleteResourceFiles(resource.id);
      } catch (_) {
        // Metadata already points at the verified new blob. Leaving a legacy
        // orphan is safer than reporting the successful replacement as failed.
      }
    }
    return updated;
  }

  Future<TeachingPlannerWorkspace> relinkExternalFile({
    required TeachingResource resource,
    required TeachingAttachmentCandidate file,
  }) async {
    if (resource.kind != TeachingResourceKind.file) {
      throw const TeachingPlannerOperationException(
        'Only file resources can be relinked.',
      );
    }
    final path = file.sourcePath?.trim() ?? '';
    if (path.isEmpty) {
      throw const TeachingPlannerOperationException(
        'The selected file cannot be linked on this device.',
      );
    }
    final fileName = file.fileName.trim();
    final updated = await _plannerService.updateTeachingFileLocation(
      resource.id,
      originalFileName: fileName,
      mimeType: TeachingResourceFileMetadata.mimeTypeForFileName(fileName),
      fileOwnership: TeachingResourceFileOwnership.linkedExternal,
      localRelativePath: null,
      externalFilePath: path,
      sizeBytes: file.sizeBytes,
      contentSha256: null,
    );
    if (resource.fileOwnership == TeachingResourceFileOwnership.managed) {
      try {
        await _fileStore.deleteResourceFiles(resource.id);
      } catch (_) {
        // Metadata already points to the external original. Stale managed bytes
        // are harmless and can be cleaned later rather than failing the relink.
      }
    }
    return updated;
  }
}
