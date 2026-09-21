import 'dart:convert';

import 'curriculum_merge_state.dart';
import 'teaching_planner_workspace.dart';

enum OfflineSyncOperation { upsert, delete }

enum OfflineSyncDirection { outbound, inbound }

enum OfflineSyncEntryState { pending, acknowledged, applied, conflict }

enum OfflineSyncLayer { teacherLocal, teacherWorking, officialMaster }

class OfflineSyncEntityClock {
  final String entityType;
  final String originId;
  final String? localId;
  final int revision;
  final String fingerprint;
  final bool isDeleted;
  final DateTime changedAt;

  const OfflineSyncEntityClock({
    required this.entityType,
    required this.originId,
    required this.localId,
    required this.revision,
    required this.fingerprint,
    required this.isDeleted,
    required this.changedAt,
  });

  String get key => '$entityType:$originId';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entityType': entityType,
    'originId': originId,
    'localId': ?localId,
    'revision': revision,
    'fingerprint': fingerprint,
    'isDeleted': isDeleted,
    'changedAt': changedAt.toUtc().toIso8601String(),
  };

  factory OfflineSyncEntityClock.fromJson(Map<String, dynamic> json) {
    final entityType = _requiredText(json['entityType']);
    final originId = _requiredText(json['originId']);
    final localId = _optionalText(json['localId']);
    final revision = _positiveInt(json['revision']);
    final fingerprint = _requiredText(json['fingerprint']);
    final isDeleted = json['isDeleted'];
    final changedAt = DateTime.tryParse(json['changedAt']?.toString() ?? '');
    if (!_syncEntityTypes.contains(entityType) ||
        originId.isEmpty ||
        revision < 1 ||
        fingerprint.isEmpty ||
        isDeleted is! bool ||
        changedAt == null ||
        (!isDeleted && localId == null)) {
      throw const FormatException('Offline sync entity clock is invalid.');
    }
    return OfflineSyncEntityClock(
      entityType: entityType,
      originId: originId,
      localId: localId,
      revision: revision,
      fingerprint: fingerprint,
      isDeleted: isDeleted,
      changedAt: changedAt,
    );
  }
}

class OfflineSyncJournalEntry {
  final String changeId;
  final String sourceReplicaId;
  final int sequence;
  final OfflineSyncDirection direction;
  final OfflineSyncEntryState state;
  final String entityType;
  final String originId;
  final String? localId;
  final int entityRevision;
  final OfflineSyncOperation operation;
  final OfflineSyncLayer layer;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;
  final String? conflictReason;

  OfflineSyncJournalEntry({
    required this.changeId,
    required this.sourceReplicaId,
    required this.sequence,
    required this.direction,
    required this.state,
    required this.entityType,
    required this.originId,
    required this.localId,
    required this.entityRevision,
    required this.operation,
    required this.layer,
    required this.occurredAt,
    Map<String, dynamic>? payload,
    this.conflictReason,
  }) : payload = payload == null
           ? null
           : Map<String, dynamic>.unmodifiable(_deepCopyMap(payload));

  OfflineSyncJournalEntry copyWith({
    OfflineSyncEntryState? state,
    String? conflictReason,
  }) => OfflineSyncJournalEntry(
    changeId: changeId,
    sourceReplicaId: sourceReplicaId,
    sequence: sequence,
    direction: direction,
    state: state ?? this.state,
    entityType: entityType,
    originId: originId,
    localId: localId,
    entityRevision: entityRevision,
    operation: operation,
    layer: layer,
    occurredAt: occurredAt,
    payload: payload,
    conflictReason: conflictReason ?? this.conflictReason,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'changeId': changeId,
    'sourceReplicaId': sourceReplicaId,
    'sequence': sequence,
    'direction': direction.name,
    'state': state.name,
    'entityType': entityType,
    'originId': originId,
    'localId': ?localId,
    'entityRevision': entityRevision,
    'operation': operation.name,
    'layer': layer.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payload': ?payload,
    'conflictReason': ?conflictReason,
  };

  factory OfflineSyncJournalEntry.fromJson(Map<String, dynamic> json) {
    final changeId = _requiredText(json['changeId']);
    final sourceReplicaId = _requiredText(json['sourceReplicaId']);
    final sequence = _positiveInt(json['sequence']);
    final entityType = _requiredText(json['entityType']);
    final originId = _requiredText(json['originId']);
    final localId = _optionalText(json['localId']);
    final entityRevision = _positiveInt(json['entityRevision']);
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final direction = _enumByName(
      OfflineSyncDirection.values,
      json['direction'],
      'Offline sync entry has an unknown direction.',
    );
    final state = _enumByName(
      OfflineSyncEntryState.values,
      json['state'],
      'Offline sync entry has an unknown state.',
    );
    final operation = _enumByName(
      OfflineSyncOperation.values,
      json['operation'],
      'Offline sync entry has an unknown operation.',
    );
    final layer = _enumByName(
      OfflineSyncLayer.values,
      json['layer'],
      'Offline sync entry has an unknown ownership layer.',
    );
    final rawPayload = json['payload'];
    if (changeId.isEmpty ||
        sourceReplicaId.isEmpty ||
        sequence < 1 ||
        !_syncEntityTypes.contains(entityType) ||
        originId.isEmpty ||
        entityRevision < 1 ||
        occurredAt == null ||
        (operation == OfflineSyncOperation.upsert && rawPayload is! Map) ||
        (operation == OfflineSyncOperation.delete && rawPayload != null)) {
      throw const FormatException('Offline sync journal entry is invalid.');
    }
    return OfflineSyncJournalEntry(
      changeId: changeId,
      sourceReplicaId: sourceReplicaId,
      sequence: sequence,
      direction: direction,
      state: state,
      entityType: entityType,
      originId: originId,
      localId: localId,
      entityRevision: entityRevision,
      operation: operation,
      layer: layer,
      occurredAt: occurredAt,
      payload: rawPayload == null
          ? null
          : Map<String, dynamic>.from(rawPayload as Map),
      conflictReason: _optionalText(json['conflictReason']),
    );
  }
}

class OfflineSyncState {
  final String replicaId;
  final int nextSequence;
  final List<OfflineSyncEntityClock> entityClocks;
  final List<OfflineSyncJournalEntry> journal;
  final List<String> appliedInboundChangeIds;

  OfflineSyncState({
    required this.replicaId,
    this.nextSequence = 1,
    List<OfflineSyncEntityClock> entityClocks = const [],
    List<OfflineSyncJournalEntry> journal = const [],
    List<String> appliedInboundChangeIds = const [],
  }) : entityClocks = List.unmodifiable(entityClocks),
       journal = List.unmodifiable(journal),
       appliedInboundChangeIds = List.unmodifiable(appliedInboundChangeIds) {
    if (nextSequence < 1) {
      throw const FormatException('Offline sync sequence must be positive.');
    }
    if (replicaId.trim().isEmpty &&
        (this.entityClocks.isNotEmpty ||
            this.journal.isNotEmpty ||
            this.appliedInboundChangeIds.isNotEmpty)) {
      throw const FormatException(
        'Uninitialized offline sync state cannot contain sync history.',
      );
    }
    final clockKeys = <String>{};
    for (final clock in this.entityClocks) {
      if (!clockKeys.add(clock.key)) {
        throw const FormatException(
          'Offline sync state contains duplicate entity clocks.',
        );
      }
    }
    final changeIds = <String>{};
    var maxSequence = 0;
    for (final entry in this.journal) {
      if (!changeIds.add(entry.changeId)) {
        throw const FormatException(
          'Offline sync state contains duplicate change ids.',
        );
      }
      if (entry.sourceReplicaId == replicaId) {
        if (entry.changeId != '$replicaId:${entry.sequence}') {
          throw const FormatException(
            'Local offline sync change id does not match its sequence.',
          );
        }
        if (entry.sequence > maxSequence) maxSequence = entry.sequence;
      }
    }
    if (replicaId.isNotEmpty && nextSequence <= maxSequence) {
      throw const FormatException(
        'Offline sync sequence does not advance past its journal.',
      );
    }
    if (this.appliedInboundChangeIds.toSet().length !=
        this.appliedInboundChangeIds.length) {
      throw const FormatException(
        'Offline sync state contains duplicate applied change ids.',
      );
    }
  }

  factory OfflineSyncState.uninitialized() => OfflineSyncState(replicaId: '');

  bool get isInitialized => replicaId.trim().isNotEmpty;

  List<OfflineSyncJournalEntry> get pendingOutbound => journal
      .where(
        (entry) =>
            entry.direction == OfflineSyncDirection.outbound &&
            entry.state == OfflineSyncEntryState.pending,
      )
      .toList(growable: false);

  List<OfflineSyncJournalEntry> get conflicts => journal
      .where((entry) => entry.state == OfflineSyncEntryState.conflict)
      .toList(growable: false);

  OfflineSyncEntityClock? clockFor(String entityType, String originId) {
    for (final clock in entityClocks) {
      if (clock.entityType == entityType && clock.originId == originId) {
        return clock;
      }
    }
    return null;
  }

  OfflineSyncEntityClock? clockForLocalId(String entityType, String localId) {
    for (final clock in entityClocks) {
      if (clock.entityType == entityType &&
          clock.localId == localId &&
          !clock.isDeleted) {
        return clock;
      }
    }
    return null;
  }

  OfflineSyncState copyWith({
    String? replicaId,
    int? nextSequence,
    List<OfflineSyncEntityClock>? entityClocks,
    List<OfflineSyncJournalEntry>? journal,
    List<String>? appliedInboundChangeIds,
  }) => OfflineSyncState(
    replicaId: replicaId ?? this.replicaId,
    nextSequence: nextSequence ?? this.nextSequence,
    entityClocks: entityClocks ?? this.entityClocks,
    journal: journal ?? this.journal,
    appliedInboundChangeIds:
        appliedInboundChangeIds ?? this.appliedInboundChangeIds,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'replicaId': replicaId,
    'nextSequence': nextSequence,
    'entityClocks': entityClocks.map((item) => item.toJson()).toList(),
    'journal': journal.map((item) => item.toJson()).toList(),
    'appliedInboundChangeIds': appliedInboundChangeIds,
  };

  factory OfflineSyncState.fromJson(Object? value) {
    if (value == null) return OfflineSyncState.uninitialized();
    if (value is! Map) {
      throw const FormatException('Offline sync state must be an object.');
    }
    final json = Map<String, dynamic>.from(value);
    return OfflineSyncState(
      replicaId: _requiredText(json['replicaId']),
      nextSequence: _positiveInt(json['nextSequence']),
      entityClocks: _maps(
        json['entityClocks'],
      ).map(OfflineSyncEntityClock.fromJson).toList(),
      journal: _maps(
        json['journal'],
      ).map(OfflineSyncJournalEntry.fromJson).toList(),
      appliedInboundChangeIds: _strings(json['appliedInboundChangeIds']),
    );
  }
}

class OfflineSyncTracker {
  const OfflineSyncTracker();

  OfflineSyncState initialize({
    required OfflineSyncState state,
    required String replicaId,
  }) {
    final clean = replicaId.trim();
    if (state.isInitialized) return state;
    if (clean.isEmpty) {
      throw const FormatException('Offline sync replica id cannot be empty.');
    }
    return state.copyWith(replicaId: clean);
  }

  OfflineSyncState recordLocalDiff({
    required TeachingPlannerWorkspace before,
    required TeachingPlannerWorkspace after,
    required CurriculumMergeState beforeMergeState,
    required CurriculumMergeState afterMergeState,
    required OfflineSyncState state,
    required DateTime changedAt,
  }) {
    if (!state.isInitialized) {
      throw StateError('Offline sync state must be initialized first.');
    }
    final beforeEntities = _entities(before);
    final afterEntities = _entities(after);
    final clocks = <String, OfflineSyncEntityClock>{
      for (final item in state.entityClocks) item.key: item,
    };
    final journal = <OfflineSyncJournalEntry>[...state.journal];
    var nextSequence = state.nextSequence;

    final localKeys = <String>{
      ...beforeEntities.keys,
      ...afterEntities.keys,
    }.toList()..sort();
    for (final localKey in localKeys) {
      final previous = beforeEntities[localKey];
      final current = afterEntities[localKey];
      if (previous != null &&
          current != null &&
          previous.fingerprint == current.fingerprint) {
        continue;
      }
      final entity = current ?? previous;
      if (entity == null) continue;
      final entityType = entity.entityType;
      final localId = entity.localId;
      final originId = _originFor(
        entityType: entityType,
        localId: localId,
        beforeMergeState: beforeMergeState,
        afterMergeState: afterMergeState,
        state: state,
      );
      final clockKey = '$entityType:$originId';
      final existingClock = clocks[clockKey];
      final revision = (existingClock?.revision ?? 0) + 1;
      final isDelete = current == null;
      final fingerprint = isDelete
          ? _deletedFingerprint(originId, revision)
          : current.fingerprint;
      final layer = _layerFor(
        entityType: entityType,
        localId: localId,
        mergeState: afterMergeState,
      );
      final changeId = '${state.replicaId}:$nextSequence';
      final entry = OfflineSyncJournalEntry(
        changeId: changeId,
        sourceReplicaId: state.replicaId,
        sequence: nextSequence,
        direction: OfflineSyncDirection.outbound,
        state: OfflineSyncEntryState.pending,
        entityType: entityType,
        originId: originId,
        localId: isDelete ? existingClock?.localId ?? localId : localId,
        entityRevision: revision,
        operation: isDelete
            ? OfflineSyncOperation.delete
            : OfflineSyncOperation.upsert,
        layer: layer,
        occurredAt: changedAt,
        payload: current?.payload,
      );
      journal.add(entry);
      clocks[clockKey] = OfflineSyncEntityClock(
        entityType: entityType,
        originId: originId,
        localId: isDelete ? null : localId,
        revision: revision,
        fingerprint: fingerprint,
        isDeleted: isDelete,
        changedAt: changedAt,
      );
      nextSequence += 1;
    }

    return state.copyWith(
      nextSequence: nextSequence,
      entityClocks: clocks.values.toList(growable: false),
      journal: journal,
    );
  }

  Map<String, _SyncEntity> _entities(TeachingPlannerWorkspace workspace) {
    final result = <String, _SyncEntity>{};
    void addAll(String type, Iterable<dynamic> values) {
      for (final value in values) {
        final String localId = value.id as String;
        final Map<String, dynamic> payload = Map<String, dynamic>.from(
          value.toJson() as Map,
        );
        result['$type:$localId'] = _SyncEntity(
          entityType: type,
          localId: localId,
          payload: payload,
          fingerprint: canonicalJsonFingerprint(payload),
        );
      }
    }

    addAll('class', workspace.classes);
    addAll('subject', workspace.subjects);
    addAll('unit', workspace.units);
    addAll('chapter', workspace.chapters);
    addAll('topic', workspace.topics);
    addAll('lessonPlan', workspace.lessonPlans);
    addAll('resource', workspace.resources);
    return result;
  }

  String _originFor({
    required String entityType,
    required String localId,
    required CurriculumMergeState beforeMergeState,
    required CurriculumMergeState afterMergeState,
    required OfflineSyncState state,
  }) {
    final official =
        afterMergeState.replicaForLocalId(entityType, localId) ??
        beforeMergeState.replicaForLocalId(entityType, localId);
    if (official != null) return official.originId;
    final clock = state.clockForLocalId(entityType, localId);
    if (clock != null) return clock.originId;
    return 'local:${state.replicaId}:$entityType:$localId';
  }

  OfflineSyncLayer _layerFor({
    required String entityType,
    required String localId,
    required CurriculumMergeState mergeState,
  }) {
    if (!mergeState.isOfficialLocalId(entityType, localId)) {
      return OfflineSyncLayer.teacherLocal;
    }
    if (entityType == 'lessonPlan') {
      return OfflineSyncLayer.teacherWorking;
    }
    return OfflineSyncLayer.officialMaster;
  }
}

String canonicalJsonFingerprint(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((item) => item.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}

String _deletedFingerprint(String originId, int revision) =>
    'deleted:$originId:$revision';

class _SyncEntity {
  final String entityType;
  final String localId;
  final Map<String, dynamic> payload;
  final String fingerprint;

  const _SyncEntity({
    required this.entityType,
    required this.localId,
    required this.payload,
    required this.fingerprint,
  });
}

const Set<String> _syncEntityTypes = <String>{
  'class',
  'subject',
  'unit',
  'chapter',
  'topic',
  'lessonPlan',
  'resource',
  'paper',
};

Map<String, dynamic> _deepCopyMap(Map source) =>
    source.map((key, value) => MapEntry(key.toString(), _deepCopyValue(value)));

Object? _deepCopyValue(Object? value) {
  if (value is Map) return _deepCopyMap(value);
  if (value is List) return value.map(_deepCopyValue).toList();
  return value;
}

Iterable<Map<String, dynamic>> _maps(Object? value) sync* {
  if (value == null) return;
  if (value is! List) {
    throw const FormatException('Offline sync collection must be a list.');
  }
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Offline sync collection item is invalid.');
    }
    yield Map<String, dynamic>.from(item);
  }
}

List<String> _strings(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Offline sync id collection must be a list.');
  }
  final result = <String>[];
  for (final item in value) {
    final text = _requiredText(item);
    if (text.isEmpty) {
      throw const FormatException('Offline sync id cannot be empty.');
    }
    result.add(text);
  }
  return result;
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String message) {
  final name = raw?.toString() ?? '';
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException(message);
}

String _requiredText(Object? value) => value?.toString().trim() ?? '';

String? _optionalText(Object? value) {
  final text = _requiredText(value);
  return text.isEmpty ? null : text;
}

int _positiveInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}
