import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'portable_paper_snapshot.dart';

class PortablePaperMaterialization {
  final Map<String, String> resolvedPaths;
  final String directoryPath;

  const PortablePaperMaterialization({
    required this.resolvedPaths,
    required this.directoryPath,
  });
}

class PortablePaperAssetStore {
  PortablePaperAssetStore({
    Future<Directory> Function()? rootResolver,
    String Function()? importDirectoryId,
  }) : _rootResolver = rootResolver ?? _defaultRoot,
       _importDirectoryId = importDirectoryId ?? (() => const Uuid().v4());

  final Future<Directory> Function() _rootResolver;
  final String Function() _importDirectoryId;

  static Future<Directory> _defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      p.join(documents.path, 'edusheet', 'portable-paper-assets'),
    );
  }

  Future<PortablePaperMaterialization> materialize(
    PortablePaperSnapshot snapshot, {
    required String targetPaperId,
  }) async {
    if (snapshot.assets.isEmpty) {
      return const PortablePaperMaterialization(
        resolvedPaths: <String, String>{},
        directoryPath: '',
      );
    }
    final root = await _rootResolver();
    await root.create(recursive: true);
    final directory = Directory(
      p.join(root.path, _safeSegment(targetPaperId), _importDirectoryId()),
    );
    await directory.create(recursive: true);
    final resolved = <String, String>{};
    try {
      var index = 0;
      for (final entry in snapshot.assets.entries) {
        final safeName = _safeFileName(entry.value.fileName);
        final file = File(p.join(directory.path, '$index-$safeName'));
        await file.writeAsBytes(entry.value.bytes, flush: true);
        resolved[entry.key] = file.path;
        index++;
      }
      return PortablePaperMaterialization(
        resolvedPaths: Map<String, String>.unmodifiable(resolved),
        directoryPath: directory.path,
      );
    } catch (_) {
      await _deleteDirectory(directory.path);
      rethrow;
    }
  }

  Future<void> deleteMaterialization(String directoryPath) =>
      _deleteDirectory(directoryPath);

  Future<void> _deleteDirectory(String directoryPath) async {
    if (directoryPath.trim().isEmpty) return;
    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'paper' : safe;
  }

  String _safeFileName(String value) {
    final base = p.basename(value).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return base.trim().isEmpty ? 'paper-asset.bin' : base;
  }
}
