import 'dart:convert';

import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import 'teaching_planner_document_codec.dart';

class TeachingPlannerBackupPayload {
  final TeachingPlannerWorkspace workspace;
  final Map<String, List<int>> resourceFiles;

  const TeachingPlannerBackupPayload({
    required this.workspace,
    this.resourceFiles = const {},
  });
}

/// Codec for portable EduSheet Teaching Planner files.
///
/// v2 embeds every Teaching Planner file resource by stable resource id, so
/// lesson and syllabus attachments remain genuinely portable in one `.eds`.
/// v1 (Phase 18) files remain readable.
class TeachingPlannerBackupCodec {
  const TeachingPlannerBackupCodec({
    TeachingPlannerDocumentCodec documentCodec =
        const TeachingPlannerDocumentCodec(),
  }) : _documentCodec = documentCodec;

  final TeachingPlannerDocumentCodec _documentCodec;

  static const String format = 'edusheet.teaching-planner-backup';
  static const int version = 2;
  static const String fileExtension = 'eds';
  static const String magicHeader = 'EDUSHEET-PLANNER/1';

  String encode(
    TeachingPlannerWorkspace workspace, {
    DateTime? exportedAt,
    Map<String, List<int>> resourceFiles = const {},
  }) {
    _validateEmbeddedFileSet(workspace, resourceFiles.keys.toSet());
    final payload = {
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'document': _documentCodec.encode(workspace, updatedAt: exportedAt),
      if (resourceFiles.isNotEmpty)
        'resourceFiles': {
          for (final entry in resourceFiles.entries)
            entry.key: base64Encode(entry.value),
        },
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    return '$magicHeader\n$json';
  }

  TeachingPlannerWorkspace decode(String source) =>
      decodePayload(source).workspace;

  TeachingPlannerBackupPayload decodePayload(String source) {
    final payloadSource = _unwrapPortableContainer(source);
    final decoded = jsonDecode(payloadSource);
    if (decoded is! Map) {
      throw const FormatException(
        'Teaching Planner backup must be a JSON object.',
      );
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['format'] != format) {
      throw const FormatException(
        'This file is not an EduSheet Teaching Planner backup.',
      );
    }
    final fileVersion = _version(json['version']);
    if (fileVersion < 1 || fileVersion > version) {
      throw const FormatException(
        'Unsupported Teaching Planner backup version.',
      );
    }
    final workspace = _documentCodec.decode(
      _normalizeDocument(json['document']),
    );
    final resourceFiles = <String, List<int>>{};
    if (fileVersion >= 2 && json['resourceFiles'] != null) {
      final raw = json['resourceFiles'];
      if (raw is! Map) {
        throw const FormatException('Planner resourceFiles must be an object.');
      }
      for (final entry in raw.entries) {
        final encoded = entry.value;
        if (encoded is! String) {
          throw const FormatException('Planner attachment payload is invalid.');
        }
        resourceFiles[entry.key.toString()] = base64Decode(encoded);
      }
    }
    if (fileVersion >= 2) {
      _validateEmbeddedFileSet(workspace, resourceFiles.keys.toSet());
    }
    return TeachingPlannerBackupPayload(
      workspace: workspace,
      resourceFiles: Map<String, List<int>>.unmodifiable(resourceFiles),
    );
  }

  static void _validateEmbeddedFileSet(
    TeachingPlannerWorkspace workspace,
    Set<String> embeddedIds,
  ) {
    final requiredIds = workspace.resources
        .where((item) => item.kind == TeachingResourceKind.file)
        .map((item) => item.id)
        .toSet();
    final missing = requiredIds.difference(embeddedIds);
    if (missing.isNotEmpty) {
      throw const FormatException(
        'Portable .eds file is missing one or more attached file payloads.',
      );
    }
    final unknown = embeddedIds.difference(requiredIds);
    if (unknown.isNotEmpty) {
      throw const FormatException(
        'Portable .eds file contains attachment payloads with no matching planner resource.',
      );
    }
  }

  int _version(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  Object? _normalizeDocument(Object? value) {
    if (value is! Map) {
      return value;
    }
    final document = Map<String, dynamic>.from(value);
    if (document['workspace'] is Map) {
      return document;
    }

    const workspaceKeys = <String>{
      'classes',
      'subjects',
      'units',
      'chapters',
      'topics',
      'lessonPlans',
      'resources',
    };
    if (!workspaceKeys.any(document.containsKey)) return document;

    final workspace = <String, dynamic>{
      for (final key in workspaceKeys)
        if (document.containsKey(key)) key: document[key],
    };
    return <String, dynamic>{
      'schemaVersion': document['schemaVersion'],
      if (document.containsKey('updatedAt')) 'updatedAt': document['updatedAt'],
      'workspace': workspace,
    };
  }

  String _unwrapPortableContainer(String source) {
    final normalized = source.startsWith('\uFEFF')
        ? source.substring(1)
        : source;
    if (normalized.startsWith('$magicHeader\n')) {
      return normalized.substring(magicHeader.length + 1);
    }
    if (normalized.startsWith('$magicHeader\r\n')) {
      return normalized.substring(magicHeader.length + 2);
    }
    final trimmed = normalized.trimLeft();
    if (trimmed.startsWith('{')) return trimmed;
    throw const FormatException(
      'This file is not an EduSheet Teaching Planner file.',
    );
  }
}
