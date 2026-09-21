import 'package:crypto/crypto.dart';

import '../domain/models/teaching_resource.dart';

class PortableAttachmentManifestEntry {
  final int sizeBytes;
  final String sha256Hex;
  final String? fileName;

  const PortableAttachmentManifestEntry({
    required this.sizeBytes,
    required this.sha256Hex,
    this.fileName,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sizeBytes': sizeBytes,
    'sha256': sha256Hex,
    if (fileName != null) 'fileName': fileName,
  };

  factory PortableAttachmentManifestEntry.fromJson(Map<String, dynamic> json) {
    final size = json['sizeBytes'];
    final parsedSize = size is int
        ? size
        : size is num
        ? size.toInt()
        : int.tryParse(size?.toString() ?? '');
    final hash = json['sha256']?.toString().trim().toLowerCase() ?? '';
    if (parsedSize == null || parsedSize < 0 || !_isSha256(hash)) {
      throw const FormatException('Portable attachment manifest is invalid.');
    }
    final fileName = json['fileName']?.toString().trim();
    return PortableAttachmentManifestEntry(
      sizeBytes: parsedSize,
      sha256Hex: hash,
      fileName: fileName == null || fileName.isEmpty ? null : fileName,
    );
  }
}

Map<String, dynamic> buildPortableAttachmentManifest(
  Iterable<TeachingResource> resources,
  Map<String, List<int>> files,
) {
  final byId = <String, TeachingResource>{for (final item in resources) item.id: item};
  return <String, dynamic>{
    for (final entry in files.entries)
      entry.key: PortableAttachmentManifestEntry(
        sizeBytes: entry.value.length,
        sha256Hex: sha256.convert(entry.value).toString(),
        fileName: byId[entry.key]?.originalFileName ?? byId[entry.key]?.title,
      ).toJson(),
  };
}

void verifyPortableAttachmentManifest({
  required Iterable<TeachingResource> resources,
  required Map<String, List<int>> files,
  required Object? rawManifest,
}) {
  final resourcesById = <String, TeachingResource>{
    for (final item in resources.where((item) => item.kind == TeachingResourceKind.file))
      item.id: item,
  };
  if (rawManifest == null) {
    // Legacy portable files did not carry a dedicated attachment manifest.
    // When resource metadata has a Phase-4 hash, still verify it.
    for (final entry in files.entries) {
      final expected = resourcesById[entry.key]?.contentSha256?.trim().toLowerCase();
      if (expected != null && expected.isNotEmpty) {
        final actual = sha256.convert(entry.value).toString();
        if (actual != expected) {
          throw const FormatException(
            'Portable attachment failed integrity verification.',
          );
        }
      }
    }
    return;
  }
  if (rawManifest is! Map) {
    throw const FormatException('Portable attachment manifest must be an object.');
  }
  final manifest = <String, PortableAttachmentManifestEntry>{};
  for (final entry in rawManifest.entries) {
    if (entry.value is! Map) {
      throw const FormatException('Portable attachment manifest entry is invalid.');
    }
    manifest[entry.key.toString()] = PortableAttachmentManifestEntry.fromJson(
      Map<String, dynamic>.from(entry.value as Map),
    );
  }
  if (manifest.keys.toSet().difference(files.keys.toSet()).isNotEmpty ||
      files.keys.toSet().difference(manifest.keys.toSet()).isNotEmpty) {
    throw const FormatException(
      'Portable attachment manifest does not match embedded files.',
    );
  }
  for (final entry in files.entries) {
    final expected = manifest[entry.key]!;
    if (expected.sizeBytes != entry.value.length ||
        expected.sha256Hex != sha256.convert(entry.value).toString()) {
      throw const FormatException(
        'Portable attachment is corrupt or was modified after export.',
      );
    }
    final resourceHash = resourcesById[entry.key]?.contentSha256?.trim().toLowerCase();
    if (resourceHash != null &&
        resourceHash.isNotEmpty &&
        resourceHash != expected.sha256Hex) {
      throw const FormatException(
        'Portable attachment metadata does not match its embedded file.',
      );
    }
  }
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
