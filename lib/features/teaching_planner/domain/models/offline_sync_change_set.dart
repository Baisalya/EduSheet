import 'offline_sync_state.dart';

class OfflineSyncChange {
  final String changeId;
  final String sourceReplicaId;
  final int sequence;
  final String entityType;
  final String originId;
  final String? localId;
  final int entityRevision;
  final OfflineSyncOperation operation;
  final OfflineSyncLayer layer;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;

  OfflineSyncChange({
    required this.changeId,
    required this.sourceReplicaId,
    required this.sequence,
    required this.entityType,
    required this.originId,
    required this.localId,
    required this.entityRevision,
    required this.operation,
    required this.layer,
    required this.occurredAt,
    this.payload,
  });

  factory OfflineSyncChange.fromJournal(OfflineSyncJournalEntry entry) {
    return OfflineSyncChange(
      changeId: entry.changeId,
      sourceReplicaId: entry.sourceReplicaId,
      sequence: entry.sequence,
      entityType: entry.entityType,
      originId: entry.originId,
      localId: entry.localId,
      entityRevision: entry.entityRevision,
      operation: entry.operation,
      layer: entry.layer,
      occurredAt: entry.occurredAt,
      payload: entry.payload,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'changeId': changeId,
    'sourceReplicaId': sourceReplicaId,
    'sequence': sequence,
    'entityType': entityType,
    'originId': originId,
    'localId': ?localId,
    'entityRevision': entityRevision,
    'operation': operation.name,
    'layer': layer.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payload': ?payload,
  };

  factory OfflineSyncChange.fromJson(Map<String, dynamic> json) {
    final entry = OfflineSyncJournalEntry.fromJson(<String, dynamic>{
      ...json,
      'direction': OfflineSyncDirection.outbound.name,
      'state': OfflineSyncEntryState.pending.name,
    });
    return OfflineSyncChange.fromJournal(entry);
  }
}

class OfflineSyncChangeSet {
  static const int schemaVersion = 1;

  final String changeSetId;
  final String sourceReplicaId;
  final DateTime createdAt;
  final List<OfflineSyncChange> changes;

  OfflineSyncChangeSet({
    required this.changeSetId,
    required this.sourceReplicaId,
    required this.createdAt,
    required List<OfflineSyncChange> changes,
  }) : changes = List.unmodifiable(changes) {
    if (changeSetId.trim().isEmpty ||
        sourceReplicaId.trim().isEmpty ||
        this.changes.isEmpty) {
      throw const FormatException(
        'Offline sync change-set identity is invalid.',
      );
    }
    final ids = <String>{};
    var lastSequence = 0;
    for (final change in this.changes) {
      if (change.sourceReplicaId != sourceReplicaId ||
          !ids.add(change.changeId) ||
          change.sequence <= lastSequence) {
        throw const FormatException(
          'Offline sync change-set contains inconsistent changes.',
        );
      }
      lastSequence = change.sequence;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': 'edusheet.offline-sync-change-set',
    'schemaVersion': schemaVersion,
    'changeSetId': changeSetId,
    'sourceReplicaId': sourceReplicaId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'changes': changes.map((item) => item.toJson()).toList(),
  };

  factory OfflineSyncChangeSet.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'edusheet.offline-sync-change-set') {
      throw const FormatException('This is not an EduSheet sync change-set.');
    }
    final version = _positiveInt(json['schemaVersion']);
    if (version != schemaVersion) {
      throw const FormatException(
        'Unsupported EduSheet sync change-set schema.',
      );
    }
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final rawChanges = json['changes'];
    if (createdAt == null || rawChanges is! List) {
      throw const FormatException('Offline sync change-set is invalid.');
    }
    return OfflineSyncChangeSet(
      changeSetId: json['changeSetId']?.toString().trim() ?? '',
      sourceReplicaId: json['sourceReplicaId']?.toString().trim() ?? '',
      createdAt: createdAt,
      changes: rawChanges.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Offline sync change payload is invalid.',
          );
        }
        return OfflineSyncChange.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
    );
  }
}

int _positiveInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}
