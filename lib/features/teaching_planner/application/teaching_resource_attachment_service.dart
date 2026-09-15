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

  const TeachingAttachmentCandidate({
    required this.fileName,
    required this.bytes,
  });
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
        final relativePath = await _fileStore.writeBytes(
          resourceId: id,
          fileName: fileName,
          bytes: candidate.bytes,
        );
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
}
