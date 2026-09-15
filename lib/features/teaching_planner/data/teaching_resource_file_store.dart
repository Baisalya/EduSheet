import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TeachingResourceFileStore {
  TeachingResourceFileStore({Future<Directory> Function()? rootResolver})
    : _rootResolver = rootResolver ?? _defaultRoot;

  final Future<Directory> Function() _rootResolver;

  static Future<Directory> _defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'teaching_planner_resources'));
  }

  Future<String> writeBytes({
    required String resourceId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final root = await _rootResolver();
    final safeId = _safeSegment(resourceId);
    final safeName = _safeFileName(fileName);
    final directory = Directory(p.join(root.path, safeId));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, safeName));
    await file.writeAsBytes(bytes, flush: true);
    return p.join(safeId, safeName);
  }

  Future<Uint8List> readBytes(String relativePath) async {
    final file = await resolve(relativePath);
    return file.readAsBytes();
  }

  Future<File> resolve(String relativePath) async {
    final root = await _rootResolver();
    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) {
      throw const FileSystemException('Unsafe Teaching Planner resource path.');
    }
    final file = File(p.join(root.path, normalized));
    final rootCanonical = p.normalize(root.absolute.path);
    final fileCanonical = p.normalize(file.absolute.path);
    if (!p.isWithin(rootCanonical, fileCanonical)) {
      throw const FileSystemException('Unsafe Teaching Planner resource path.');
    }
    return file;
  }

  Future<bool> exists(String? relativePath) async {
    if (relativePath == null || relativePath.trim().isEmpty) return false;
    try {
      return await (await resolve(relativePath)).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteResourceFiles(String resourceId) async {
    final root = await _rootResolver();
    final directory = Directory(p.join(root.path, _safeSegment(resourceId)));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static String _safeSegment(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static String _safeFileName(String value) {
    final base = p.basename(value).trim();
    final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return safe.isEmpty ? 'resource.bin' : safe;
  }
}
