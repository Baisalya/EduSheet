import '../domain/models/teaching_planner_workspace.dart';
import '../domain/services/teaching_planner_integrity.dart';

class TeachingPlannerSchemaException implements Exception {
  final String message;

  const TeachingPlannerSchemaException(this.message);

  @override
  String toString() => 'TeachingPlannerSchemaException: $message';
}

class TeachingPlannerDocumentCodec {
  const TeachingPlannerDocumentCodec();

  static const int currentSchemaVersion = 8;

  Map<String, dynamic> encode(
    TeachingPlannerWorkspace workspace, {
    DateTime? updatedAt,
  }) {
    TeachingPlannerIntegrity.validateOrThrow(workspace);
    return {
      'schemaVersion': currentSchemaVersion,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'workspace': workspace.toJson(),
    };
  }

  Map<String, dynamic> emptyDocument() => encode(
    TeachingPlannerWorkspace.empty(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  TeachingPlannerWorkspace decode(Object? value) {
    if (value is! Map) {
      throw const TeachingPlannerSchemaException(
        'Planner document must be a JSON object.',
      );
    }
    final json = Map<String, dynamic>.from(value);
    final version = _schemaVersion(json['schemaVersion']);
    if (version > currentSchemaVersion) {
      throw TeachingPlannerSchemaException(
        'Planner data schema $version is newer than supported schema '
        '$currentSchemaVersion.',
      );
    }

    final migrated = _migrate(json, fromVersion: version);
    final workspaceJson = migrated['workspace'];
    if (workspaceJson is! Map) {
      throw const TeachingPlannerSchemaException(
        'Planner document is missing its workspace object.',
      );
    }
    final workspace = TeachingPlannerWorkspace.fromJson(
      Map<String, dynamic>.from(workspaceJson),
    );
    TeachingPlannerIntegrity.validateOrThrow(workspace);
    return workspace;
  }

  int _schemaVersion(Object? value) {
    if (value is int && value >= 1) return value;
    if (value is num && value.toInt() >= 1) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed >= 1) return parsed;
    throw const TeachingPlannerSchemaException(
      'Planner data has no supported schemaVersion.',
    );
  }

  Map<String, dynamic> _migrate(
    Map<String, dynamic> source, {
    required int fromVersion,
  }) {
    if (fromVersion == currentSchemaVersion) {
      return Map<String, dynamic>.from(source);
    }
    if (fromVersion == 7) {
      final migrated = _deepCopyMap(source);
      migrated['schemaVersion'] = currentSchemaVersion;
      return migrated;
    }
    if (fromVersion == 6) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        final resources = workspace['resources'];
        if (resources is List) {
          workspace['resources'] = resources.map((item) {
            if (item is! Map) return item;
            final copy = Map<String, dynamic>.from(item);
            if (copy['owner'] == null) {
              final lessonPlanId =
                  copy['lessonPlanId']?.toString().trim() ?? '';
              if (lessonPlanId.isNotEmpty) {
                copy['owner'] = <String, dynamic>{
                  'type': 'lessonPlan',
                  'id': lessonPlanId,
                };
              }
            }
            return copy;
          }).toList();
        }
      }
      migrated['schemaVersion'] = 7;
      return _migrate(migrated, fromVersion: 7);
    }
    if (fromVersion == 5) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        workspace.putIfAbsent('resources', () => <dynamic>[]);
      }
      migrated['schemaVersion'] = 6;
      return _migrate(migrated, fromVersion: 6);
    }
    if (fromVersion == 4) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        final lessons = workspace['lessonPlans'];
        if (lessons is List) {
          workspace['lessonPlans'] = lessons.map((item) {
            if (item is! Map) return item;
            final copy = Map<String, dynamic>.from(item);
            copy.putIfAbsent('startPeriod', () => null);
            return copy;
          }).toList();
        }
      }
      migrated['schemaVersion'] = 5;
      return _migrate(migrated, fromVersion: 5);
    }
    if (fromVersion == 3) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        final lessons = workspace['lessonPlans'];
        if (lessons is List) {
          workspace['lessonPlans'] = lessons.map((item) {
            if (item is! Map) return item;
            final copy = Map<String, dynamic>.from(item);
            copy.putIfAbsent('actualPeriods', () => 0);
            return copy;
          }).toList();
        }
      }
      migrated['schemaVersion'] = 4;
      return _migrate(migrated, fromVersion: 4);
    }
    if (fromVersion == 2) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        workspace.putIfAbsent('lessonPlans', () => <dynamic>[]);
      }
      migrated['schemaVersion'] = 3;
      return _migrate(migrated, fromVersion: 3);
    }
    if (fromVersion == 1) {
      final migrated = _deepCopyMap(source);
      final workspace = migrated['workspace'];
      if (workspace is Map) {
        for (final collection in const ['units', 'chapters', 'topics']) {
          final items = workspace[collection];
          if (items is List) {
            workspace[collection] = items.map((item) {
              if (item is! Map) return item;
              final copy = Map<String, dynamic>.from(item);
              copy.putIfAbsent('priority', () => 'normal');
              return copy;
            }).toList();
          }
        }
      }
      migrated['schemaVersion'] = 2;
      return _migrate(migrated, fromVersion: 2);
    }
    throw TeachingPlannerSchemaException(
      'No migration path exists from planner schema $fromVersion.',
    );
  }

  static Map<String, dynamic> _deepCopyMap(Map source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), _deepCopyValue(value)),
    );
  }

  static dynamic _deepCopyValue(dynamic value) {
    if (value is Map) return _deepCopyMap(value);
    if (value is List) return value.map(_deepCopyValue).toList();
    return value;
  }
}
