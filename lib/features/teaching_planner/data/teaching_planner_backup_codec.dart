import 'dart:convert';

import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';
import 'portable_paper_snapshot.dart';
import 'teaching_planner_document_codec.dart';

class TeachingPlannerBackupPayload {
  final TeachingPlannerWorkspace workspace;
  final Map<String, List<int>> resourceFiles;
  final Map<String, PortablePaperSnapshot> paperSnapshots;
  final int version;

  const TeachingPlannerBackupPayload({
    required this.workspace,
    this.resourceFiles = const {},
    this.paperSnapshots = const {},
    required this.version,
  });
}

/// Codec for portable EduSheet Teaching Planner files.
///
/// v3 embeds linked native EduSheet papers and every local file referenced by
/// those papers, in addition to the planner attachment bytes introduced in v2.
/// v2 and v1 remain readable for backward compatibility.
class TeachingPlannerBackupCodec {
  const TeachingPlannerBackupCodec({
    TeachingPlannerDocumentCodec documentCodec =
        const TeachingPlannerDocumentCodec(),
  }) : _documentCodec = documentCodec;

  final TeachingPlannerDocumentCodec _documentCodec;

  static const String format = 'edusheet.teaching-planner-backup';
  static const int version = 3;
  static const String fileExtension = 'eds';
  static const String magicHeader = 'EDUSHEET-PLANNER/1';

  String encode(
    TeachingPlannerWorkspace workspace, {
    DateTime? exportedAt,
    Map<String, List<int>> resourceFiles = const {},
    Map<String, PortablePaperSnapshot> paperSnapshots = const {},
    int targetVersion = version,
  }) {
    if (targetVersion != 2 && targetVersion != 3) {
      throw const FormatException(
        'EduSheet can export only portable planner versions 2 or 3.',
      );
    }
    _validateEmbeddedFileSet(workspace, resourceFiles.keys.toSet());
    if (targetVersion >= 3) {
      _validatePaperSnapshotSet(workspace, paperSnapshots);
    } else if (paperSnapshots.isNotEmpty) {
      throw const FormatException(
        'Planner v2 cannot contain native paper snapshots.',
      );
    }

    final payload = {
      'format': format,
      'version': targetVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'document': _documentCodec.encode(workspace, updatedAt: exportedAt),
      if (resourceFiles.isNotEmpty)
        'resourceFiles': {
          for (final entry in resourceFiles.entries)
            entry.key: base64Encode(entry.value),
        },
      if (targetVersion >= 3 && paperSnapshots.isNotEmpty)
        'paperSnapshots': {
          for (final entry in paperSnapshots.entries)
            entry.key: entry.value.toJson(),
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

    final paperSnapshots = <String, PortablePaperSnapshot>{};
    if (fileVersion >= 3) {
      final raw = json['paperSnapshots'];
      if (raw != null) {
        if (raw is! Map) {
          throw const FormatException(
            'Planner paperSnapshots must be an object.',
          );
        }
        for (final entry in raw.entries) {
          if (entry.value is! Map) {
            throw const FormatException(
              'Portable paper snapshot payload is invalid.',
            );
          }
          paperSnapshots[entry.key.toString()] = PortablePaperSnapshot.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      _validatePaperSnapshotSet(workspace, paperSnapshots);
    }

    return TeachingPlannerBackupPayload(
      workspace: workspace,
      resourceFiles: Map<String, List<int>>.unmodifiable(resourceFiles),
      paperSnapshots:
          Map<String, PortablePaperSnapshot>.unmodifiable(paperSnapshots),
      version: fileVersion,
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

  static void _validatePaperSnapshotSet(
    TeachingPlannerWorkspace workspace,
    Map<String, PortablePaperSnapshot> snapshots,
  ) {
    final requiredIds = <String>{};
    for (final resource in workspace.resources) {
      if (resource.kind != TeachingResourceKind.paper) continue;
      final linkedId = resource.linkedPaperId?.trim() ?? '';
      if (linkedId.isEmpty) {
        throw const FormatException(
          'Portable .eds contains a paper resource without a saved-paper id.',
        );
      }
      requiredIds.add(linkedId);
    }

    final embeddedIds = snapshots.keys.toSet();
    if (requiredIds.difference(embeddedIds).isNotEmpty) {
      throw const FormatException(
        'Portable .eds file is missing one or more linked paper snapshots.',
      );
    }
    if (embeddedIds.difference(requiredIds).isNotEmpty) {
      throw const FormatException(
        'Portable .eds contains paper snapshots that are not linked by the planner.',
      );
    }
    for (final entry in snapshots.entries) {
      if (entry.value.paper.id != entry.key) {
        throw const FormatException(
          'Portable paper snapshot id does not match its planner link.',
        );
      }
    }
  }

  int _version(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  Object? _normalizeDocument(Object? value) {
    if (value is! Map) return value;
    final document = Map<String, dynamic>.from(value);
    if (document['workspace'] is Map) return document;

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
