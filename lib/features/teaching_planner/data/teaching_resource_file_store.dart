import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';

class ManagedTeachingBlob {
  final String relativePath;
  final String sha256Hex;
  final int sizeBytes;
  final bool reusedExistingBlob;

  const ManagedTeachingBlob({
    required this.relativePath,
    required this.sha256Hex,
    required this.sizeBytes,
    required this.reusedExistingBlob,
  });
}

class TeachingResourceStorageAudit {
  final int managedReferenceCount;
  final int uniqueReferencedBlobCount;
  final int orphanBlobCount;
  final int missingManagedFileCount;
  final int corruptManagedFileCount;
  final int reclaimedBytes;

  const TeachingResourceStorageAudit({
    required this.managedReferenceCount,
    required this.uniqueReferencedBlobCount,
    required this.orphanBlobCount,
    required this.missingManagedFileCount,
    required this.corruptManagedFileCount,
    this.reclaimedBytes = 0,
  });
}

class TeachingResourceFileStore {
  TeachingResourceFileStore({Future<Directory> Function()? rootResolver})
    : _rootResolver = rootResolver ?? _defaultRoot;

  final Future<Directory> Function() _rootResolver;

  static const String _blobDirectoryName = 'blobs';

  static Future<Directory> _defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'teaching_planner_resources'));
  }

  /// Writes a managed attachment to the content-addressed blob store.
  ///
  /// [resourceId] is retained for source compatibility with older callers but
  /// new files are intentionally not stored under the resource id. Two planner
  /// resources with identical bytes therefore share one physical blob.
  Future<String> writeBytes({
    required String resourceId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final blob = await writeManagedBlob(fileName: fileName, bytes: bytes);
    return blob.relativePath;
  }

  Future<ManagedTeachingBlob> writeManagedBlob({
    required String fileName,
    required List<int> bytes,
  }) async {
    final root = await _rootResolver();
    await root.create(recursive: true);
    final digest = sha256.convert(bytes).toString();
    final relativePath = p.join(
      _blobDirectoryName,
      digest.substring(0, 2),
      '$digest${_safeBlobExtension(fileName)}',
    );
    final file = await resolve(relativePath);
    final existed = await file.exists();
    if (existed) {
      final existingLength = await file.length();
      if (existingLength == bytes.length) {
        final existingHash = sha256.convert(await file.readAsBytes()).toString();
        if (existingHash == digest) {
          return ManagedTeachingBlob(
            relativePath: relativePath,
            sha256Hex: digest,
            sizeBytes: bytes.length,
            reusedExistingBlob: true,
          );
        }
      }
      // A path derived from SHA-256 must never contain different bytes. Keep
      // the user's existing blob untouched and fail rather than overwrite it.
      throw FileSystemException(
        'EduSheet attachment blob failed integrity verification.',
        file.path,
      );
    }
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      final tempHash = sha256.convert(await temp.readAsBytes()).toString();
      if (tempHash != digest) {
        throw FileSystemException(
          'EduSheet could not verify the attachment before saving it.',
          temp.path,
        );
      }
      try {
        await temp.rename(file.path);
      } on FileSystemException {
        // Another attachment write may have materialized the same content in
        // parallel. Accept the winner only after verifying its bytes.
        if (!await file.exists() ||
            await file.length() != bytes.length ||
            sha256.convert(await file.readAsBytes()).toString() != digest) {
          rethrow;
        }
        return ManagedTeachingBlob(
          relativePath: relativePath,
          sha256Hex: digest,
          sizeBytes: bytes.length,
          reusedExistingBlob: true,
        );
      }
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
    return ManagedTeachingBlob(
      relativePath: relativePath,
      sha256Hex: digest,
      sizeBytes: bytes.length,
      reusedExistingBlob: false,
    );
  }

  String sha256ForBytes(List<int> bytes) => sha256.convert(bytes).toString();

  Future<File?> resolveResourceFile(TeachingResource resource) async {
    if (resource.kind != TeachingResourceKind.file) return null;
    switch (resource.fileOwnership) {
      case TeachingResourceFileOwnership.managed:
        final relativePath = resource.localRelativePath;
        if (relativePath == null || relativePath.trim().isEmpty) return null;
        return resolve(relativePath);
      case TeachingResourceFileOwnership.linkedExternal:
        final externalPath = resource.externalFilePath;
        if (externalPath == null || externalPath.trim().isEmpty) return null;
        return File(externalPath);
    }
  }

  Future<bool> resourceExists(TeachingResource resource) async {
    try {
      final file = await resolveResourceFile(resource);
      return file != null && await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> readResourceBytes(TeachingResource resource) async {
    final file = await resolveResourceFile(resource);
    if (file == null || !await file.exists()) {
      throw FileSystemException(
        'Teaching Planner attachment is missing.',
        resource.externalFilePath ?? resource.localRelativePath,
      );
    }
    final bytes = await file.readAsBytes();
    final expectedSize = resource.fileOwnership ==
            TeachingResourceFileOwnership.managed
        ? resource.sizeBytes
        : null;
    if (expectedSize != null && expectedSize != bytes.length) {
      throw FileSystemException(
        'EduSheet attachment size does not match its saved metadata.',
        file.path,
      );
    }
    final expectedHash = resource.fileOwnership ==
            TeachingResourceFileOwnership.managed
        ? resource.contentSha256?.trim().toLowerCase()
        : null;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = sha256.convert(bytes).toString();
      if (actualHash != expectedHash) {
        throw FileSystemException(
          'EduSheet attachment failed integrity verification.',
          file.path,
        );
      }
    }
    return bytes;
  }

  Future<bool> verifyResourceIntegrity(TeachingResource resource) async {
    try {
      await readResourceBytes(resource);
      return true;
    } catch (_) {
      return false;
    }
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

  /// Backward-compatible cleanup for the pre-Phase-4 resource-id directory
  /// layout. Content-addressed blobs are shared and are never deleted here.
  Future<void> deleteResourceFiles(String resourceId) async {
    final root = await _rootResolver();
    final directory = Directory(p.join(root.path, _safeSegment(resourceId)));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<TeachingResourceStorageAudit> auditManagedStorage(
    TeachingPlannerWorkspace workspace, {
    bool removeOrphanBlobs = false,
  }) async {
    final managed = workspace.resources.where(
      (item) =>
          item.kind == TeachingResourceKind.file &&
          item.fileOwnership == TeachingResourceFileOwnership.managed &&
          item.localRelativePath != null,
    );
    final referenced = managed
        .map((item) => p.normalize(item.localRelativePath!))
        .toSet();
    var missing = 0;
    var corrupt = 0;
    for (final resource in managed) {
      if (!await resourceExists(resource)) {
        missing++;
      } else if (!await verifyResourceIntegrity(resource)) {
        corrupt++;
      }
    }

    final root = await _rootResolver();
    final blobs = Directory(p.join(root.path, _blobDirectoryName));
    var orphanCount = 0;
    var reclaimed = 0;
    if (await blobs.exists()) {
      await for (final entity in blobs.list(recursive: true, followLinks: false)) {
        if (entity is! File || entity.path.contains('.tmp-')) continue;
        final relative = p.normalize(p.relative(entity.path, from: root.path));
        if (referenced.contains(relative)) continue;
        orphanCount++;
        if (removeOrphanBlobs) {
          reclaimed += await entity.length();
          await entity.delete();
        }
      }
    }
    if (removeOrphanBlobs && await blobs.exists()) {
      final directories = <Directory>[];
      await for (final entity in blobs.list(recursive: true, followLinks: false)) {
        if (entity is Directory) directories.add(entity);
      }
      directories.sort((a, b) => b.path.length.compareTo(a.path.length));
      for (final directory in directories) {
        if (await directory.exists() && await directory.list().isEmpty) {
          await directory.delete();
        }
      }
    }

    return TeachingResourceStorageAudit(
      managedReferenceCount: managed.length,
      uniqueReferencedBlobCount: referenced.length,
      orphanBlobCount: orphanCount,
      missingManagedFileCount: missing,
      corruptManagedFileCount: corrupt,
      reclaimedBytes: reclaimed,
    );
  }

  static String _safeSegment(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static String _safeBlobExtension(String fileName) {
    final extension = p.extension(p.basename(fileName)).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)) {
      return extension;
    }
    return '.blob';
  }
}

