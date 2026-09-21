import '../../application/teaching_resource_attachment_service.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../models/syllabus_node_ref.dart';
import 'teaching_attachment_open_coordinator.dart';
import 'teaching_resource_file_picker.dart';

typedef SyllabusAttachFiles =
    Future<bool> Function({
      required TeachingResourceOwner owner,
      required List<TeachingAttachmentCandidate> files,
    });

typedef SyllabusArchiveResource = Future<bool> Function(String resourceId);
typedef SyllabusReplaceResource =
    Future<bool> Function({
      required TeachingResource resource,
      required TeachingAttachmentCandidate file,
    });

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
    TeachingAttachmentOpenCoordinator? openCoordinator,
    required SyllabusAttachFiles attachFiles,
    SyllabusAttachFiles? attachLinkedFiles,
    required SyllabusArchiveResource archiveResource,
    SyllabusReplaceResource? replaceManagedResource,
    SyllabusReplaceResource? relinkResource,
  }) : _picker = picker,
       _openCoordinator = openCoordinator,
       _attachFiles = attachFiles,
       _attachLinkedFiles = attachLinkedFiles,
       _archiveResource = archiveResource,
       _replaceManagedResource = replaceManagedResource,
       _relinkResource = relinkResource;

  final TeachingResourceFilePicker _picker;
  final TeachingAttachmentOpenCoordinator? _openCoordinator;
  final SyllabusAttachFiles _attachFiles;
  final SyllabusAttachFiles? _attachLinkedFiles;
  final SyllabusArchiveResource _archiveResource;
  final SyllabusReplaceResource? _replaceManagedResource;
  final SyllabusReplaceResource? _relinkResource;

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
          ? '${files.single.fileName} added to EduSheet.'
          : '${files.length} files added to EduSheet.';
      return SyllabusAttachmentActionResult.success(message);
    } on TeachingAttachmentSelectionException catch (error) {
      return SyllabusAttachmentActionResult.failure(error.message);
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'Those files could not be attached. Your syllabus was not changed.',
      );
    }
  }

  Future<SyllabusAttachmentActionResult> linkFiles(SyllabusNodeRef node) async {
    try {
      final files = await _picker.pickFiles(
        dialogTitle: 'Link original files',
        allowMultiple: true,
        readBytes: false,
      );
      if (files.isEmpty) {
        return const SyllabusAttachmentActionResult.cancelled();
      }
      if (files.any((item) => (item.sourcePath ?? '').trim().isEmpty)) {
        return const SyllabusAttachmentActionResult.failure(
          'These files cannot be linked on this device. Add them to EduSheet instead.',
        );
      }
      final attachLinkedFiles = _attachLinkedFiles;
      if (attachLinkedFiles == null) {
        return const SyllabusAttachmentActionResult.failure(
          'Linking original files is not available here.',
        );
      }
      final saved = await attachLinkedFiles(
        owner: ownerForNode(node),
        files: files,
      );
      if (!saved) {
        return const SyllabusAttachmentActionResult.failure(
          'Those originals could not be linked. Your syllabus was not changed.',
        );
      }
      return SyllabusAttachmentActionResult.success(
        files.length == 1
            ? '${files.single.fileName} linked to its original file.'
            : '${files.length} original files linked.',
      );
    } on TeachingAttachmentSelectionException catch (error) {
      return SyllabusAttachmentActionResult.failure(error.message);
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'Those originals could not be linked. Your syllabus was not changed.',
      );
    }
  }

  Future<TeachingAttachmentOpenResult> resolveOpen(
    TeachingResource resource,
  ) {
    final coordinator = _openCoordinator;
    if (coordinator == null) {
      return Future.value(
        const TeachingAttachmentOpenResult.invalid(
          'The EduSheet attachment viewer is not available here.',
        ),
      );
    }
    return coordinator.resolve(resource);
  }

  Future<SyllabusAttachmentActionResult> locate(
    TeachingResource resource,
  ) async {
    try {
      final files = await _picker.pickFiles(
        dialogTitle: 'Locate attachment',
        allowMultiple: false,
        readBytes: resource.fileOwnership !=
            TeachingResourceFileOwnership.linkedExternal,
      );
      if (files.isEmpty) {
        return const SyllabusAttachmentActionResult.cancelled();
      }
      final file = files.single;
      final relinkResource = _relinkResource;
      final replaceManagedResource = _replaceManagedResource;
      if (replaceManagedResource == null) {
        return const SyllabusAttachmentActionResult.failure(
          'Attachment recovery is not available here.',
        );
      }
      final saved = resource.fileOwnership ==
                  TeachingResourceFileOwnership.linkedExternal &&
              (file.sourcePath ?? '').trim().isNotEmpty &&
              relinkResource != null
          ? await relinkResource(resource: resource, file: file)
          : await replaceManagedResource(resource: resource, file: file);
      return saved
          ? const SyllabusAttachmentActionResult.success(
              'Attachment location updated.',
            )
          : const SyllabusAttachmentActionResult.failure(
              'The attachment could not be updated.',
            );
    } on TeachingAttachmentSelectionException catch (error) {
      return SyllabusAttachmentActionResult.failure(error.message);
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'The attachment could not be updated.',
      );
    }
  }

  Future<SyllabusAttachmentActionResult> replace(
    TeachingResource resource,
  ) async {
    try {
      final files = await _picker.pickFiles(
        dialogTitle: 'Replace attachment',
        allowMultiple: false,
      );
      if (files.isEmpty) {
        return const SyllabusAttachmentActionResult.cancelled();
      }
      final replaceManagedResource = _replaceManagedResource;
      if (replaceManagedResource == null) {
        return const SyllabusAttachmentActionResult.failure(
          'Attachment replacement is not available here.',
        );
      }
      final saved = await replaceManagedResource(
        resource: resource,
        file: files.single,
      );
      return saved
          ? const SyllabusAttachmentActionResult.success(
              'Attachment replaced with an EduSheet-managed copy.',
            )
          : const SyllabusAttachmentActionResult.failure(
              'The replacement file could not be saved.',
            );
    } on TeachingAttachmentSelectionException catch (error) {
      return SyllabusAttachmentActionResult.failure(error.message);
    } catch (_) {
      return const SyllabusAttachmentActionResult.failure(
        'The replacement file could not be saved.',
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
