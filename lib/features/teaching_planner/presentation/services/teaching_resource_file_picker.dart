import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../application/teaching_resource_attachment_service.dart';

class TeachingResourceFilePicker {
  const TeachingResourceFilePicker();

  Future<List<TeachingAttachmentCandidate>> pickFiles({
    String dialogTitle = 'Add teaching material',
    bool allowMultiple = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      allowMultiple: allowMultiple,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return const <TeachingAttachmentCandidate>[];
    }

    final candidates = <TeachingAttachmentCandidate>[];
    for (final picked in result.files) {
      final bytes = picked.bytes ?? await _readPath(picked.path);
      if (bytes == null) {
        throw FileSystemException(
          'Selected file could not be read.',
          picked.path,
        );
      }
      candidates.add(
        TeachingAttachmentCandidate(fileName: picked.name, bytes: bytes),
      );
    }
    return List.unmodifiable(candidates);
  }

  Future<Uint8List?> _readPath(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsBytes();
  }
}
