import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../data/teaching_pack_codec.dart';

class TeachingPackSaveDialogRequest {
  const TeachingPackSaveDialogRequest({
    required this.dialogTitle,
    required this.fileName,
    required this.bytes,
  });

  final String dialogTitle;
  final String fileName;
  final Uint8List? bytes;
}

typedef TeachingPackSaveFilePicker = Future<String?> Function(
  TeachingPackSaveDialogRequest request,
);
typedef TeachingPackTextFileWriter = Future<void> Function(
  String path,
  String source,
);

/// Platform-safe `.edtp` saver.
///
/// Android document providers receive bytes directly from `file_picker`.
/// Desktop keeps the existing path-based save flow so native Save As behavior
/// remains unchanged.
class TeachingPackExportFileSaver {
  TeachingPackExportFileSaver({
    bool? isAndroid,
    TeachingPackSaveFilePicker? saveFile,
    TeachingPackTextFileWriter? writeTextFile,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _saveFile = saveFile ?? _defaultSaveFile,
       _writeTextFile = writeTextFile ?? _defaultWriteTextFile;

  final bool _isAndroid;
  final TeachingPackSaveFilePicker _saveFile;
  final TeachingPackTextFileWriter _writeTextFile;

  Future<String?> save({
    required String source,
    required String fileName,
    required String dialogTitle,
  }) async {
    final request = TeachingPackSaveDialogRequest(
      dialogTitle: dialogTitle,
      fileName: _withExtension(fileName),
      bytes: _isAndroid ? Uint8List.fromList(utf8.encode(source)) : null,
    );
    final path = await _saveFile(request);
    if (path == null) return null;

    if (_isAndroid) return path;

    final finalPath = _withExtension(path);
    await _writeTextFile(finalPath, source);
    return finalPath;
  }

  static String _withExtension(String value) {
    final extension = '.${TeachingPackCodec.fileExtension}';
    return value.toLowerCase().endsWith(extension) ? value : '$value$extension';
  }

  static Future<String?> _defaultSaveFile(TeachingPackSaveDialogRequest request) {
    return FilePicker.platform.saveFile(
      dialogTitle: request.dialogTitle,
      fileName: request.fileName,
      type: FileType.custom,
      allowedExtensions: const [TeachingPackCodec.fileExtension],
      bytes: request.bytes,
    );
  }

  static Future<void> _defaultWriteTextFile(String path, String source) async {
    await File(path).writeAsString(source, flush: true);
  }
}
