import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class SmartEditorBinarySaveRequest {
  const SmartEditorBinarySaveRequest({
    required this.dialogTitle,
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String dialogTitle;
  final String fileName;
  final String extension;
  final Uint8List bytes;
}

typedef SmartEditorSaveFilePicker = Future<String?> Function(
  SmartEditorBinarySaveRequest request,
);
typedef SmartEditorBinaryWriter = Future<void> Function(
  String path,
  Uint8List bytes,
);

/// Platform-safe binary Save As helper.
///
/// Android document providers receive bytes directly from file_picker. Desktop
/// keeps path-based writes so native Save As behavior remains predictable.
class SmartEditorBinaryFileSaver {
  SmartEditorBinaryFileSaver({
    bool? isAndroid,
    SmartEditorSaveFilePicker? saveFile,
    SmartEditorBinaryWriter? writeBytes,
  })  : _isAndroid = isAndroid ?? Platform.isAndroid,
        _saveFile = saveFile ?? _defaultSaveFile,
        _writeBytes = writeBytes ?? _defaultWriteBytes;

  final bool _isAndroid;
  final SmartEditorSaveFilePicker _saveFile;
  final SmartEditorBinaryWriter _writeBytes;

  Future<String?> save({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required String dialogTitle,
  }) async {
    final normalizedExtension = extension.replaceFirst('.', '').toLowerCase();
    final normalizedName = _withExtension(fileName, normalizedExtension);
    final request = SmartEditorBinarySaveRequest(
      dialogTitle: dialogTitle,
      fileName: normalizedName,
      extension: normalizedExtension,
      bytes: bytes,
    );
    final path = await _saveFile(request);
    if (path == null) return null;
    if (_isAndroid) return path;

    final finalPath = _withExtension(path, normalizedExtension);
    await _writeBytes(finalPath, bytes);
    return finalPath;
  }

  static String _withExtension(String value, String extension) {
    final suffix = '.$extension';
    return value.toLowerCase().endsWith(suffix) ? value : '$value$suffix';
  }

  static Future<String?> _defaultSaveFile(SmartEditorBinarySaveRequest request) {
    return FilePicker.platform.saveFile(
      dialogTitle: request.dialogTitle,
      fileName: request.fileName,
      type: FileType.custom,
      allowedExtensions: <String>[request.extension],
      bytes: Platform.isAndroid ? request.bytes : null,
    );
  }

  static Future<void> _defaultWriteBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}
