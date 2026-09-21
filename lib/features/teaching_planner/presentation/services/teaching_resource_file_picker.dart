import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../application/teaching_resource_attachment_service.dart';

class TeachingAttachmentSelectionException implements Exception {
  final String message;

  const TeachingAttachmentSelectionException(this.message);

  @override
  String toString() => message;
}

class TeachingResourceFilePicker {
  const TeachingResourceFilePicker();

  /// Portable planner packages embed file bytes as base64 JSON. Keep a firm
  /// upper bound before reading selected files into Flutter memory.
  static const int maxSingleFileBytes = 128 * 1024 * 1024;
  static const int maxSelectionBytes = 256 * 1024 * 1024;

  Future<List<TeachingAttachmentCandidate>> pickFiles({
    String dialogTitle = 'Add teaching material',
    bool allowMultiple = true,
    bool readBytes = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      allowMultiple: allowMultiple,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return const <TeachingAttachmentCandidate>[];
    }

    if (readBytes) {
      var totalBytes = 0;
      for (final picked in result.files) {
        if (picked.size > maxSingleFileBytes) {
          throw TeachingAttachmentSelectionException(
            '${picked.name} is too large to keep as a portable EduSheet attachment. Choose a file under 128 MB${Platform.isWindows ? ' or use Link original on Windows' : ''}.',
          );
        }
        totalBytes += picked.size;
        if (totalBytes > maxSelectionBytes) {
          throw const TeachingAttachmentSelectionException(
            'The selected files are over 256 MB in total. Add fewer files at a time so EduSheet can keep the planner portable and memory-safe.',
          );
        }
      }
    }

    final candidates = <TeachingAttachmentCandidate>[];
    var actualTotalBytes = 0;
    for (final picked in result.files) {
      final bytes = readBytes
          ? (picked.bytes ?? await _readPath(picked.path))
          : Uint8List(0);
      if (bytes == null) {
        throw FileSystemException(
          'Selected file could not be read.',
          picked.path,
        );
      }
      if (readBytes) {
        if (bytes.length > maxSingleFileBytes) {
          throw TeachingAttachmentSelectionException(
            '${picked.name} is too large to keep as a portable EduSheet attachment. Choose a file under 128 MB${Platform.isWindows ? ' or use Link original on Windows' : ''}.',
          );
        }
        actualTotalBytes += bytes.length;
        if (actualTotalBytes > maxSelectionBytes) {
          throw const TeachingAttachmentSelectionException(
            'The selected files are over 256 MB in total. Add fewer files at a time so EduSheet can keep the planner portable and memory-safe.',
          );
        }
      }
      candidates.add(
        TeachingAttachmentCandidate(
          fileName: picked.name,
          bytes: bytes,
          sourcePath: picked.path,
          sourceSizeBytes: picked.size,
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  Future<Uint8List?> _readPath(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsBytes();
  }
}
