import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/document_model.dart';
import '../../domain/models/document_open_request.dart';

class DocumentRepository {
  static const Set<String> supportedExtensions = DocumentFile.supportedExtensions;
  static const int _desktopScanDepth = 2;
  static const int _appScanDepth = 3;
  static const int _maxDiscoveredDocuments = 1200;

  Future<List<DocumentFile>> getDocuments() async {
    final documents = <DocumentFile>[];
    final seenPaths = <String>{};

    for (final root in await _scanRoots()) {
      if (documents.length >= _maxDiscoveredDocuments) break;
      await _scanDirectory(
        root.directory,
        documents,
        seenPaths,
        depth: 0,
        maxDepth: root.maxDepth,
      );
    }

    documents.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return documents;
  }

  Future<void> _scanDirectory(
    Directory directory,
    List<DocumentFile> documents,
    Set<String> seenPaths, {
    required int depth,
    required int maxDepth,
  }) async {
    if (depth > maxDepth || documents.length >= _maxDiscoveredDocuments) {
      return;
    }

    Stream<FileSystemEntity> stream;
    try {
      stream = directory.list(followLinks: false);
    } catch (_) {
      return;
    }

    try {
      await for (final entity in stream) {
        if (documents.length >= _maxDiscoveredDocuments) return;

        final baseName = p.basename(entity.path);
        if (baseName.startsWith('.') || _shouldSkipDirectoryName(baseName)) {
          continue;
        }

        if (entity is Directory) {
          await _scanDirectory(
            entity,
            documents,
            seenPaths,
            depth: depth + 1,
            maxDepth: maxDepth,
          );
          continue;
        }

        if (entity is! File) continue;
        final document = await getDocumentFromFilePath(entity.path);
        if (document == null) continue;

        final normalizedPath = p.normalize(document.path);
        if (seenPaths.add(normalizedPath)) {
          documents.add(document);
        }
      }
    } on FileSystemException {
      // A discovery root can contain protected or transient subdirectories.
    }
  }

  bool _shouldSkipDirectoryName(String name) {
    final lower = name.toLowerCase();
    return lower == 'node_modules' ||
        lower == '.git' ||
        lower == 'build' ||
        lower == 'cache' ||
        lower == 'caches' ||
        lower == 'temp' ||
        lower == 'tmp' ||
        lower == 'appdata';
  }

  Future<List<_ScanRoot>> _scanRoots() async {
    final roots = <String, _ScanRoot>{};

    Future<void> addDirectory(Future<Directory?> directoryFuture, int depth) async {
      try {
        final directory = await directoryFuture;
        if (directory != null) {
          roots[p.normalize(directory.path)] = _ScanRoot(directory, depth);
        }
      } catch (_) {
        // Directory is not exposed on every platform.
      }
    }

    await addDirectory(getApplicationDocumentsDirectory(), _appScanDepth);
    await addDirectory(getApplicationSupportDirectory(), _appScanDepth);

    if (Platform.isAndroid) {
      try {
        final externalDirs = await getExternalStorageDirectories();
        for (final directory in externalDirs ?? <Directory>[]) {
          roots[p.normalize(directory.path)] = _ScanRoot(
            directory,
            _appScanDepth,
          );
        }
      } catch (_) {
        // Scoped-storage app directories can be unavailable on some devices.
      }
    } else {
      await addDirectory(getDownloadsDirectory(), _desktopScanDepth);
      final home =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        for (final name in const ['Desktop', 'Documents', 'Downloads']) {
          final directory = Directory(p.join(home, name));
          roots[p.normalize(directory.path)] = _ScanRoot(
            directory,
            _desktopScanDepth,
          );
        }
      }
    }

    return roots.values.toList();
  }

  Future<DocumentFile?> getDocumentFromRequest(
    DocumentOpenRequest request,
  ) async {
    return getDocumentFromFilePath(
      request.localPath,
      displayName: request.displayName,
      mimeType: request.mimeType,
      originalUri: request.originalUri,
    );
  }

  Future<DocumentFile?> getDocumentFromFilePath(
    String filePath, {
    String? displayName,
    String? mimeType,
    String? originalUri,
  }) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) return null;

      var ext = p.extension(filePath).toLowerCase();
      final originalName = displayName?.trim();
      if (originalName != null && originalName.isNotEmpty) {
        final displayExtension = p.extension(originalName).toLowerCase();
        if (displayExtension.isNotEmpty) ext = displayExtension;
      }
      if (!supportedExtensions.contains(ext)) return null;

      final stat = await file.stat();
      return DocumentFile(
        name: originalName == null || originalName.isEmpty
            ? p.basename(filePath)
            : originalName,
        path: filePath,
        extension: ext,
        size: stat.size,
        lastModified: stat.modified,
        type: DocumentFile.getDocumentType(ext),
        mimeType: mimeType,
        originalUri: originalUri,
      );
    } on FileSystemException {
      return null;
    }
  }
}

class _ScanRoot {
  final Directory directory;
  final int maxDepth;

  const _ScanRoot(this.directory, this.maxDepth);
}
