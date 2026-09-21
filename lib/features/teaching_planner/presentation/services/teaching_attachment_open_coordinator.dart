import 'dart:io';

import 'package:edusheet/features/document_reader/data/repositories/document_repository.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import '../../application/teaching_resource_file_metadata.dart';
import '../../data/teaching_resource_file_store.dart';
import '../../domain/models/teaching_resource.dart';

enum TeachingAttachmentOpenKind { document, image, eds, edtp, external, missing, invalid }

class TeachingAttachmentOpenResult {
  const TeachingAttachmentOpenResult._({
    required this.kind,
    this.file,
    this.document,
    this.message,
  });

  const TeachingAttachmentOpenResult.document({
    required File file,
    required DocumentFile document,
  }) : this._(
         kind: TeachingAttachmentOpenKind.document,
         file: file,
         document: document,
       );

  const TeachingAttachmentOpenResult.image(File file)
    : this._(kind: TeachingAttachmentOpenKind.image, file: file);

  const TeachingAttachmentOpenResult.eds(File file)
    : this._(kind: TeachingAttachmentOpenKind.eds, file: file);

  const TeachingAttachmentOpenResult.edtp(File file)
    : this._(kind: TeachingAttachmentOpenKind.edtp, file: file);

  const TeachingAttachmentOpenResult.external(File file)
    : this._(kind: TeachingAttachmentOpenKind.external, file: file);

  const TeachingAttachmentOpenResult.missing(String message)
    : this._(kind: TeachingAttachmentOpenKind.missing, message: message);

  const TeachingAttachmentOpenResult.invalid(String message)
    : this._(kind: TeachingAttachmentOpenKind.invalid, message: message);

  final TeachingAttachmentOpenKind kind;
  final File? file;
  final DocumentFile? document;
  final String? message;
}

class TeachingAttachmentOpenCoordinator {
  const TeachingAttachmentOpenCoordinator({
    required TeachingResourceFileStore fileStore,
    required DocumentRepository documentRepository,
  }) : _fileStore = fileStore,
       _documentRepository = documentRepository;

  final TeachingResourceFileStore _fileStore;
  final DocumentRepository _documentRepository;

  Future<TeachingAttachmentOpenResult> resolve(
    TeachingResource resource,
  ) async {
    if (resource.kind != TeachingResourceKind.file) {
      return const TeachingAttachmentOpenResult.invalid(
        'Only attached files can be opened with the file viewer.',
      );
    }

    final file = await _fileStore.resolveResourceFile(resource);
    if (file == null || !await file.exists()) {
      return TeachingAttachmentOpenResult.missing(
        resource.fileOwnership == TeachingResourceFileOwnership.linkedExternal
            ? 'The linked original file cannot be found. Locate it, replace it with a managed EduSheet copy, or remove the attachment.'
            : 'This EduSheet-managed attachment is missing. Locate or replace the file, or remove the attachment.',
      );
    }

    final fileName = resource.originalFileName ?? resource.title;
    final extension = DocumentFile.extensionFromName(fileName);
    if (extension == '.eds') {
      return TeachingAttachmentOpenResult.eds(file);
    }
    if (extension == '.edtp') {
      return TeachingAttachmentOpenResult.edtp(file);
    }
    if (DocumentFile.supportedExtensions.contains(extension)) {
      final document = await _documentRepository.getDocumentFromFilePath(
        file.path,
        displayName: fileName,
        mimeType: resource.mimeType,
      );
      if (document != null) {
        return TeachingAttachmentOpenResult.document(
          file: file,
          document: document,
        );
      }
    }

    final category = TeachingResourceFileMetadata.categoryFor(
      fileName: fileName,
      mimeType: resource.mimeType,
    );
    if (category == TeachingResourceFileCategory.image) {
      return TeachingAttachmentOpenResult.image(file);
    }

    return TeachingAttachmentOpenResult.external(file);
  }
}
