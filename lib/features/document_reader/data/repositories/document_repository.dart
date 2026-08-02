import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/document_model.dart';

class DocumentRepository {
  static const Set<String> supportedExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.rtf',
    '.odt',
    '.xls',
    '.xlsx',
    '.csv',
    '.ods',
    '.ppt',
    '.pptx',
    '.odp',
    '.txt',
  };

  Future<List<DocumentFile>> getDocuments() async {
    final documents = <DocumentFile>[];
    final seenPaths = <String>{};

    for (String path in await _pathsToScan()) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await _scanDirectory(dir, documents, seenPaths);
      }
    }

    // Sort by last modified date (newest first)
    documents.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    return documents;
  }

  Future<void> _scanDirectory(
    Directory directory,
    List<DocumentFile> documents,
    Set<String> seenPaths,
  ) async {
    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final entity in entities) {
      if (entity is Directory) {
        await _scanDirectory(entity, documents, seenPaths);
        continue;
      }

      if (entity is! File) continue;

      final ext = p.extension(entity.path).toLowerCase();
      final normalizedPath = p.normalize(entity.path);
      if (!supportedExtensions.contains(ext) ||
          !seenPaths.add(normalizedPath)) {
        continue;
      }

      try {
        final stat = await entity.stat();
        documents.add(
          DocumentFile(
            name: p.basename(entity.path),
            path: entity.path,
            extension: ext,
            size: stat.size,
            lastModified: stat.modified,
            type: DocumentFile.getDocumentType(ext),
          ),
        );
      } catch (_) {
        // Skip files that disappear or cannot be read while scanning.
      }
    }
  }

  Future<List<String>> _pathsToScan() async {
    final paths = <String>{};

    Future<void> addIfAvailable(Future<Directory?> directoryFuture) async {
      try {
        final directory = await directoryFuture;
        if (directory != null) paths.add(directory.path);
      } catch (_) {
        // Directory is not available on every platform.
      }
    }

    await addIfAvailable(getApplicationDocumentsDirectory());
    await addIfAvailable(getApplicationSupportDirectory());

    if (Platform.isAndroid) {
      try {
        final externalDirs = await getExternalStorageDirectories();
        for (final directory in externalDirs ?? <Directory>[]) {
          paths.add(directory.path);
        }
      } catch (_) {
        // External app directories can be unavailable on some devices.
      }
    } else {
      await addIfAvailable(getDownloadsDirectory());
      final home =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        paths.addAll([
          p.join(home, 'Desktop'),
          p.join(home, 'Documents'),
          p.join(home, 'Downloads'),
        ]);
      }
    }

    return paths.toList();
  }

  Future<DocumentFile?> getDocumentFromFilePath(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final ext = p.extension(filePath).toLowerCase();
      if (!supportedExtensions.contains(ext)) return null;
      final stat = await file.stat();
      return DocumentFile(
        name: p.basename(filePath),
        path: filePath,
        extension: ext,
        size: stat.size,
        lastModified: stat.modified,
        type: DocumentFile.getDocumentType(ext),
      );
    }
    return null;
  }
}
