import 'dart:io';
import 'dart:typed_data';

import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:file_picker/file_picker.dart';

class SmartEditorPickedDocx {
  const SmartEditorPickedDocx({
    required this.name,
    this.path,
    this.bytes,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;
}

typedef SmartEditorDocxPicker = Future<SmartEditorPickedDocx?> Function();
typedef SmartEditorDocxImporter = Future<SmartEditorDocxImportResult> Function(
  File file,
);

/// Cross-platform Word file opener used by every Smart Editor entry point.
///
/// Windows normally supplies a real filesystem path, so the source DOCX is
/// opened directly without copying the whole file into memory. Android storage
/// providers are allowed to return bytes instead; those bytes are materialized
/// into a short-lived private temp file because the canonical DOCX importer is
/// deliberately File-based. The temp file is always removed after import.
class SmartEditorDocxFileOpener {
  SmartEditorDocxFileOpener({
    SmartEditorDocxPicker? pickFile,
    SmartEditorDocxImporter? importFile,
  })  : _pickFile = pickFile ?? _defaultPickFile,
        _importFile =
            importFile ?? const SmartEditorDocxService().importFile;

  final SmartEditorDocxPicker _pickFile;
  final SmartEditorDocxImporter _importFile;

  Future<SmartEditorDocxImportResult?> pickAndImport() async {
    final picked = await _pickFile();
    if (picked == null) return null;
    if (!picked.name.toLowerCase().endsWith('.docx')) {
      throw const FormatException('Please choose a Microsoft Word .docx file.');
    }

    Directory? temporaryDirectory;
    try {
      final source = await _resolveSource(
        picked,
        onTemporaryDirectory: (directory) => temporaryDirectory = directory,
      );
      return await _importFile(source);
    } finally {
      final directory = temporaryDirectory;
      if (directory != null) {
        try {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        } catch (_) {
          // Best-effort cleanup only. Import success remains authoritative.
        }
      }
    }
  }

  static Future<File> _resolveSource(
    SmartEditorPickedDocx picked, {
    required void Function(Directory directory) onTemporaryDirectory,
  }) async {
    final path = picked.path?.trim();
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) return file;
    }

    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'The selected Word file could not be read from this device.',
      );
    }

    final directory =
        await Directory.systemTemp.createTemp('edusheet-smart-docx-open-');
    onTemporaryDirectory(directory);
    final safeName = _safeFileName(picked.name);
    final file = File(
      '${directory.path}${Platform.pathSeparator}$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _safeFileName(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    final base = normalized.isEmpty ? 'Imported Word Document.docx' : normalized;
    return base.toLowerCase().endsWith('.docx') ? base : '$base.docx';
  }

  static Future<SmartEditorPickedDocx?> _defaultPickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['docx'],
      allowMultiple: false,
      // Android SAF/content providers can expose a document without a durable
      // filesystem path. Keep bytes there; Windows uses its native path.
      withData: Platform.isAndroid,
    );
    if (result == null || result.files.isEmpty) return null;
    final item = result.files.single;
    return SmartEditorPickedDocx(
      name: item.name,
      path: item.path,
      bytes: item.bytes,
    );
  }
}
