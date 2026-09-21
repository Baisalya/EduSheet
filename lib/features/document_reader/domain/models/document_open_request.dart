import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:edusheet/features/document_reader/domain/models/document_model.dart';

enum DocumentOpenSource {
  reader,
  filePicker,
  androidViewIntent,
  androidShareIntent,
  windowsCommandLine,
  unknown,
}

class DocumentOpenRequest {
  static const Set<String> portableEduSheetExtensions = {'.eds', '.edtp'};

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

  static List<DocumentOpenRequest> fromCommandLineAll(List<String> arguments) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const <DocumentOpenRequest>[];
    }

    final requests = <DocumentOpenRequest>[];
    final seen = <String>{};
    for (final raw in arguments) {
      final value = _stripWrappingQuotes(raw.trim());
      if (value.isEmpty || value.startsWith('--')) continue;
      final extension = p.extension(value).toLowerCase();
      if (!DocumentFile.supportedExtensions.contains(extension) &&
          !portableEduSheetExtensions.contains(extension)) {
        continue;
      }
      final normalizedKey = Platform.isWindows ? value.toLowerCase() : value;
      if (!seen.add(normalizedKey)) continue;

      requests.add(
        DocumentOpenRequest(
          source: DocumentOpenSource.windowsCommandLine,
          localPath: value,
          displayName: p.basename(value),
          activationId: 'desktop:$value',
        ),
      );
    }
    return requests;
  }

  static DocumentOpenRequest? fromCommandLine(List<String> arguments) {
    final requests = fromCommandLineAll(arguments);
    return requests.isEmpty ? null : requests.first;
  }

  String get dedupeKey => activationId ?? originalUri ?? localPath;

  String get effectiveExtension {
    final nameExtension = p.extension(displayName ?? '').toLowerCase();
    if (nameExtension.isNotEmpty) return nameExtension;
    return p.extension(localPath).toLowerCase();
  }

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
