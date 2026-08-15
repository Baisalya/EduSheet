import 'dart:io';

import 'package:path/path.dart' as p;

import 'document_model.dart';

enum DocumentOpenSource {
  reader,
  filePicker,
  androidViewIntent,
  androidShareIntent,
  windowsCommandLine,
  unknown,
}

class DocumentOpenRequest {
  final DocumentOpenSource source;
  final String localPath;
  final String? originalUri;
  final String? displayName;
  final String? mimeType;
  final String? activationId;

  const DocumentOpenRequest({
    required this.source,
    required this.localPath,
    this.originalUri,
    this.displayName,
    this.mimeType,
    this.activationId,
  });

  factory DocumentOpenRequest.fromPlatformMap(Map<Object?, Object?> map) {
    final sourceValue = map['source']?.toString();
    final source = switch (sourceValue) {
      'androidShareIntent' => DocumentOpenSource.androidShareIntent,
      'androidViewIntent' => DocumentOpenSource.androidViewIntent,
      'windowsCommandLine' => DocumentOpenSource.windowsCommandLine,
      _ => DocumentOpenSource.unknown,
    };

    return DocumentOpenRequest(
      source: source,
      localPath: map['path']?.toString() ?? '',
      originalUri: _nonEmpty(map['uri']),
      displayName: _nonEmpty(map['name']),
      mimeType: _nonEmpty(map['mimeType']),
      activationId: _nonEmpty(map['activationId']),
    );
  }

  factory DocumentOpenRequest.fromFilePicker(String path) {
    return DocumentOpenRequest(
      source: DocumentOpenSource.filePicker,
      localPath: path,
      displayName: p.basename(path),
    );
  }

  factory DocumentOpenRequest.fromReader(String path) {
    return DocumentOpenRequest(
      source: DocumentOpenSource.reader,
      localPath: path,
      displayName: p.basename(path),
    );
  }

  static DocumentOpenRequest? fromCommandLine(List<String> arguments) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }

    for (final raw in arguments) {
      final value = _stripWrappingQuotes(raw.trim());
      if (value.isEmpty || value.startsWith('--')) continue;
      final extension = p.extension(value).toLowerCase();
      if (!DocumentFile.supportedExtensions.contains(extension)) continue;

      return DocumentOpenRequest(
        source: DocumentOpenSource.windowsCommandLine,
        localPath: value,
        displayName: p.basename(value),
        activationId: 'desktop:$value',
      );
    }
    return null;
  }

  String get dedupeKey => activationId ?? originalUri ?? localPath;

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _stripWrappingQuotes(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
