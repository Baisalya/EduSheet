import 'dart:io';
import 'dart:typed_data';

enum DocumentFileReadFailure {
  cloudProviderUnavailable,
  missing,
  accessDenied,
  unreadable,
}

class DocumentFileReadException implements Exception {
  final DocumentFileReadFailure kind;
  final String path;
  final String message;
  final int? osErrorCode;

  const DocumentFileReadException({
    required this.kind,
    required this.path,
    required this.message,
    this.osErrorCode,
  });

  factory DocumentFileReadException.fromFileSystemException(
    FileSystemException error,
    String fallbackPath,
  ) {
    final path = error.path?.isNotEmpty == true ? error.path! : fallbackPath;
    final code = error.osError?.errorCode;

    if (Platform.isWindows && code == 362) {
      return DocumentFileReadException(
        kind: DocumentFileReadFailure.cloudProviderUnavailable,
        path: path,
        osErrorCode: code,
        message:
            'Windows can see this cloud file, but its contents are not available because the cloud file provider is not running.',
      );
    }

    if (code == 2 || code == 3) {
      return DocumentFileReadException(
        kind: DocumentFileReadFailure.missing,
        path: path,
        osErrorCode: code,
        message: 'The selected file is no longer available at this location.',
      );
    }

    if (code == 5 || code == 13) {
      return DocumentFileReadException(
        kind: DocumentFileReadFailure.accessDenied,
        path: path,
        osErrorCode: code,
        message: 'EduSheet does not currently have permission to read this file.',
      );
    }

    return DocumentFileReadException(
      kind: DocumentFileReadFailure.unreadable,
      path: path,
      osErrorCode: code,
      message: error.osError?.message ?? 'The selected file could not be read.',
    );
  }

  @override
  String toString() => 'DocumentFileReadException($kind, $path, $message)';
}

class DocumentFileReadService {
  const DocumentFileReadService._();

  static Future<Uint8List> readAllBytes(File file) async {
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (error) {
      throw DocumentFileReadException.fromFileSystemException(error, file.path);
    }
  }
}
