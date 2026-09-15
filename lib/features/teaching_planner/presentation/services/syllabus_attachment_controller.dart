import 'package:open_filex/open_filex.dart';

import '../../application/teaching_resource_attachment_service.dart';
import '../../data/teaching_resource_file_store.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../models/syllabus_node_ref.dart';
import 'teaching_resource_file_picker.dart';

typedef SyllabusAttachFiles =
    Future<bool> Function({
      required TeachingResourceOwner owner,
      required List<TeachingAttachmentCandidate> files,
    });

typedef SyllabusArchiveResource = Future<bool> Function(String resourceId);

class SyllabusAttachmentActionResult {
  final bool success;
  final bool cancelled;
  final String? message;

  const SyllabusAttachmentActionResult._({
    required this.success,
    required this.cancelled,
    this.message,
  });

  const SyllabusAttachmentActionResult.success([String? message])
    : this._(success: true, cancelled: false, message: message);

  const SyllabusAttachmentActionResult.cancelled()
    : this._(success: false, cancelled: true);

  const SyllabusAttachmentActionResult.failure(String message)
    : this._(success: false, cancelled: false, message: message);
}

class SyllabusAttachmentController {
  const SyllabusAttachmentController({
    required TeachingResourceFilePicker picker,
    required TeachingResourceFileStore fileStore,
    required SyllabusAttachFiles attachFiles,
    required SyllabusArchiveResource archiveResource,
  }) : _picker = picker,
       _fileStore = fileStore,
       _attachFiles = attachFiles,
       _archiveResource = archiveResource;

  final TeachingResourceFilePicker _picker;
  final TeachingResourceFileStore _fileStore;
  final SyllabusAttachFiles _attachFiles;
  final SyllabusArchiveResource _archiveResource;

  Future<SyllabusAttachmentActionResult> addFiles(SyllabusNodeRef node) async {
    try {
      final files = await _picker.pickFiles(
        dialogTitle: 'Attach files to syllabus',
        allowMultiple: true,
      );
      if (files.isEmpty) {
        return const SyllabusAttachmentActionResult.cancelled();
      }
      final saved = await _attachFiles(owner: ownerForNode(node), files: files);
      if (!saved) {
        return const SyllabusAttachmentActionResult.failure(
          'Those files could not be attached. Your syllabus was not changed.',
        );
      }
      final message = files.length == 1
          ? '${files.single.fileName} attached to syllabus.'
          : '${files.length} files attached to syllabus.';
      return SyllabusAttachmentActionResult.success(message);
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'Those files could not be attached. Your syllabus was not changed.',
      );
    }
  }

  Future<SyllabusAttachmentActionResult> open(TeachingResource resource) async {
    final relativePath = resource.localRelativePath;
    if (relativePath == null || relativePath.trim().isEmpty) {
      return const SyllabusAttachmentActionResult.failure(
        'This attachment has no local file path.',
      );
    }
    try {
      final file = await _fileStore.resolve(relativePath);
      if (!await file.exists()) {
        return const SyllabusAttachmentActionResult.failure(
          'This attachment is missing on this device. Restore a portable .eds backup that contains it.',
        );
      }
      await OpenFilex.open(file.path);
      return const SyllabusAttachmentActionResult.success();
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'This attachment could not be opened.',
      );
    }
  }

  Future<SyllabusAttachmentActionResult> archive(
    TeachingResource resource,
  ) async {
    try {
      final saved = await _archiveResource(resource.id);
      if (!saved) {
        return const SyllabusAttachmentActionResult.failure(
          'The attachment could not be removed from this syllabus.',
        );
      }
      return const SyllabusAttachmentActionResult.success(
        'Attachment removed from syllabus.',
      );
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'The attachment could not be removed from this syllabus.',
      );
    }
  }

  static TeachingResourceOwner ownerForNode(SyllabusNodeRef node) {
    return switch (node.kind) {
      SyllabusNodeKind.classValue => TeachingResourceOwner.plannerClass(
        node.id,
      ),
      SyllabusNodeKind.subject => TeachingResourceOwner.subject(node.id),
      SyllabusNodeKind.unit => TeachingResourceOwner.unit(node.id),
      SyllabusNodeKind.chapter => TeachingResourceOwner.chapter(node.id),
      SyllabusNodeKind.topic => TeachingResourceOwner.topic(node.id),
    };
  }
}
