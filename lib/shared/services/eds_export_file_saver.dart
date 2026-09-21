import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class EdsSaveDialogRequest {
  const EdsSaveDialogRequest({
    required this.dialogTitle,
    required this.fileName,
    required this.bytes,
  });

  final String dialogTitle;
  final String fileName;
  final Uint8List? bytes;
}

typedef EdsSaveFilePicker = Future<String?> Function(
  EdsSaveDialogRequest request,
);
typedef EdsTextFileWriter = Future<void> Function(String path, String source);

class EdsExportFileSaver {
  EdsExportFileSaver({
    bool? isAndroid,
    EdsSaveFilePicker? saveFile,
    EdsTextFileWriter? writeTextFile,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _saveFile = saveFile ?? _defaultSaveFile,
       _writeTextFile = writeTextFile ?? _defaultWriteTextFile;

  final bool _isAndroid;
  final EdsSaveFilePicker _saveFile;
  final EdsTextFileWriter _writeTextFile;

  Future<String?> save({
    required String source,
    required String fileName,
    required String dialogTitle,
  }) async {
    final request = EdsSaveDialogRequest(
      dialogTitle: dialogTitle,
      fileName: _withEdsExtension(fileName),
      bytes: _isAndroid ? Uint8List.fromList(utf8.encode(source)) : null,
    );
    final path = await _saveFile(request);
    if (path == null) return null;

    if (_isAndroid) {
      return path;
    }

    final portablePath = _withEdsExtension(path);
    await _writeTextFile(portablePath, source);
    return portablePath;
  }

  static String _withEdsExtension(String value) {
    return value.toLowerCase().endsWith('.eds') ? value : '$value.eds';
  }

  static Future<String?> _defaultSaveFile(EdsSaveDialogRequest request) {
    return FilePicker.platform.saveFile(
      dialogTitle: request.dialogTitle,
      fileName: request.fileName,
      type: FileType.custom,
      allowedExtensions: const ['eds'],
      bytes: request.bytes,
    );
  }

  static Future<void> _defaultWriteTextFile(String path, String source) async {
    await File(path).writeAsString(source, flush: true);
  }
}
