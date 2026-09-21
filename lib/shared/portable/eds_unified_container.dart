import 'dart:convert';

/// Canonical package kinds carried by the single user-facing `.eds` extension.
///
/// Not every kind needs to be implemented by the UI at once. The container
/// contract is intentionally stable so later curriculum/assignment packages
/// can reuse the same transport, identity and merge metadata.
enum EdsContentType {
  paper,
  chapterPack,
  subjectPack,
  syllabus,
  teacherPack,
  schoolCurriculum,
  plannerBackup,
}

EdsContentType _contentTypeFromJson(Object? value) {
  final name = value?.toString().trim() ?? '';
  for (final type in EdsContentType.values) {
    if (type.name == name) return type;
  }
  throw FormatException('Unsupported EduSheet content type: $name');
}

class EdsPackageManifest {
  final String packageId;
  final EdsContentType contentType;
  final int schemaVersion;
  final String entityId;
  final String originId;
  final int revision;
  final String title;
  final DateTime exportedAt;
  final String sourceApp;
  final Map<String, dynamic> metadata;

  EdsPackageManifest({
    required this.packageId,
    required this.contentType,
    required this.schemaVersion,
    required this.entityId,
    required this.originId,
    required this.revision,
    required this.title,
    required this.exportedAt,
    this.sourceApp = 'EduSheet',
    this.metadata = const {},
  }) {
    if (packageId.trim().isEmpty) {
      throw const FormatException('EduSheet package id cannot be empty.');
    }
    if (entityId.trim().isEmpty) {
      throw const FormatException('EduSheet entity id cannot be empty.');
    }
    if (originId.trim().isEmpty) {
      throw const FormatException('EduSheet origin id cannot be empty.');
    }
    if (schemaVersion < 1) {
      throw const FormatException('EduSheet schema version must be positive.');
    }
    if (revision < 1) {
      throw const FormatException('EduSheet revision must be positive.');
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'packageId': packageId,
        'contentType': contentType.name,
        'schemaVersion': schemaVersion,
        'entityId': entityId,
        'originId': originId,
        'revision': revision,
        'title': title,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'sourceApp': sourceApp,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory EdsPackageManifest.fromJson(Map<String, dynamic> json) {
    final exportedAt = DateTime.tryParse(
      json['exportedAt']?.toString() ?? '',
    );
    if (exportedAt == null) {
      throw const FormatException('EduSheet package export date is invalid.');
    }
    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map) {
      throw const FormatException('EduSheet package metadata must be an object.');
    }
    return EdsPackageManifest(
      packageId: json['packageId']?.toString().trim() ?? '',
      contentType: _contentTypeFromJson(json['contentType']),
      schemaVersion: _positiveInt(json['schemaVersion'], fallback: -1),
      entityId: json['entityId']?.toString().trim() ?? '',
      originId: json['originId']?.toString().trim() ?? '',
      revision: _positiveInt(json['revision'], fallback: -1),
      title: json['title']?.toString() ?? '',
      exportedAt: exportedAt,
      sourceApp: json['sourceApp']?.toString().trim().isNotEmpty == true
          ? json['sourceApp'].toString().trim()
          : 'EduSheet',
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
    );
  }
}

class EdsUnifiedPackage {
  final EdsPackageManifest manifest;
  final Map<String, dynamic> payload;

  const EdsUnifiedPackage({
    required this.manifest,
    required this.payload,
  });
}

/// Versioned universal EduSheet portable container.
///
/// The user sees one `.eds` extension. [manifest.contentType] tells EduSheet
/// which feature owns the payload. Version 4 is the first generic container;
/// older feature-specific `.eds` files remain decoded by their legacy codecs.
class EdsUnifiedContainer {
  const EdsUnifiedContainer();

  static const String format = 'edusheet.portable-package';
  static const int containerVersion = 4;
  static const String magicHeader = 'EDUSHEET/4';
  static const String fileExtension = 'eds';

  String encode({
    required EdsPackageManifest manifest,
    required Map<String, dynamic> payload,
  }) {
    final root = <String, dynamic>{
      'format': format,
      'containerVersion': containerVersion,
      'manifest': manifest.toJson(),
      'payload': payload,
    };
    return '$magicHeader\n${const JsonEncoder.withIndent('  ').convert(root)}';
  }

  EdsUnifiedPackage decode(String source) {
    final jsonSource = _unwrap(source);
    final decoded = jsonDecode(jsonSource);
    if (decoded is! Map) {
      throw const FormatException('EduSheet package must be a JSON object.');
    }
    final root = Map<String, dynamic>.from(decoded);
    if (root['format'] != format) {
      throw const FormatException('This is not an EduSheet v4 package.');
    }
    final version = _positiveInt(root['containerVersion'], fallback: -1);
    if (version != containerVersion) {
      throw const FormatException('Unsupported EduSheet container version.');
    }
    final rawManifest = root['manifest'];
    final rawPayload = root['payload'];
    if (rawManifest is! Map || rawPayload is! Map) {
      throw const FormatException(
        'EduSheet package manifest or payload is missing.',
      );
    }
    return EdsUnifiedPackage(
      manifest: EdsPackageManifest.fromJson(
        Map<String, dynamic>.from(rawManifest),
      ),
      payload: Map<String, dynamic>.from(rawPayload),
    );
  }

  bool canDecode(String source) {
    try {
      decode(source);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool looksLikeUnified(String source) {
    final normalized = source.startsWith('\uFEFF') ? source.substring(1) : source;
    if (normalized.startsWith(magicHeader)) return true;
    final trimmed = normalized.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map && decoded['format'] == format;
    } catch (_) {
      return false;
    }
  }

  String _unwrap(String source) {
    var normalized = source.startsWith('\uFEFF') ? source.substring(1) : source;
    if (normalized.startsWith('$magicHeader\r\n')) {
      normalized = normalized.substring(magicHeader.length + 2);
    } else if (normalized.startsWith('$magicHeader\n')) {
      normalized = normalized.substring(magicHeader.length + 1);
    }
    final trimmed = normalized.trimLeft();
    if (!trimmed.startsWith('{')) {
      throw const FormatException('This is not an EduSheet v4 package.');
    }
    return trimmed;
  }
}

int _positiveInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
