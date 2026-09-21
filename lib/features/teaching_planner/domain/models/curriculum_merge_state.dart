import 'package:edusheet/shared/portable/eds_unified_container.dart';

/// Device-local mapping between canonical curriculum origins carried by `.eds`
/// packages and this device's replica ids. Local entities that are not listed
/// here remain teacher/local-owned by default.
enum CurriculumReplicaOwnership { officialCurriculum }

class CurriculumReplicaRecord {
  final String entityType;
  final String localId;
  final String originId;
  final int sourceRevision;
  final DateTime sourceUpdatedAt;
  final DateTime importedAt;
  final CurriculumReplicaOwnership ownership;
  final String sourcePackageOriginId;
  final String? sourceFingerprint;
  final String? sourceSchool;
  final String? assignmentId;

  const CurriculumReplicaRecord({
    required this.entityType,
    required this.localId,
    required this.originId,
    required this.sourceRevision,
    required this.sourceUpdatedAt,
    required this.importedAt,
    required this.sourcePackageOriginId,
    this.ownership = CurriculumReplicaOwnership.officialCurriculum,
    this.sourceFingerprint,
    this.sourceSchool,
    this.assignmentId,
  });

  String get key => '$entityType:$originId';

  CurriculumReplicaRecord copyWith({
    String? localId,
    int? sourceRevision,
    DateTime? sourceUpdatedAt,
    DateTime? importedAt,
    String? sourcePackageOriginId,
    Object? sourceFingerprint = _unset,
    Object? sourceSchool = _unset,
    Object? assignmentId = _unset,
  }) {
    return CurriculumReplicaRecord(
      entityType: entityType,
      localId: localId ?? this.localId,
      originId: originId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
      importedAt: importedAt ?? this.importedAt,
      ownership: ownership,
      sourcePackageOriginId:
          sourcePackageOriginId ?? this.sourcePackageOriginId,
      sourceFingerprint: identical(sourceFingerprint, _unset)
          ? this.sourceFingerprint
          : sourceFingerprint as String?,
      sourceSchool: identical(sourceSchool, _unset)
          ? this.sourceSchool
          : sourceSchool as String?,
      assignmentId: identical(assignmentId, _unset)
          ? this.assignmentId
          : assignmentId as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entityType': entityType,
    'localId': localId,
    'originId': originId,
    'sourceRevision': sourceRevision,
    'sourceUpdatedAt': sourceUpdatedAt.toUtc().toIso8601String(),
    'importedAt': importedAt.toUtc().toIso8601String(),
    'ownership': ownership.name,
    'sourcePackageOriginId': sourcePackageOriginId,
    'sourceFingerprint': ?sourceFingerprint,
    'sourceSchool': ?sourceSchool,
    'assignmentId': ?assignmentId,
  };

  factory CurriculumReplicaRecord.fromJson(Map<String, dynamic> json) {
    final entityType = _requiredText(json['entityType']);
    final localId = _requiredText(json['localId']);
    final originId = _requiredText(json['originId']);
    final sourcePackageOriginId = _requiredText(json['sourcePackageOriginId']);
    final sourceRevision = _positiveInt(json['sourceRevision']);
    final sourceUpdatedAt = DateTime.tryParse(
      json['sourceUpdatedAt']?.toString() ?? '',
    );
    final importedAt = DateTime.tryParse(json['importedAt']?.toString() ?? '');
    final ownershipName = json['ownership']?.toString() ?? '';
    final ownership = CurriculumReplicaOwnership.values.firstWhere(
      (item) => item.name == ownershipName,
      orElse: () => throw const FormatException(
        'Curriculum replica record has an unknown ownership layer.',
      ),
    );
    if (entityType.isEmpty ||
        !_curriculumReplicaEntityTypes.contains(entityType) ||
        localId.isEmpty ||
        originId.isEmpty ||
        sourcePackageOriginId.isEmpty ||
        sourceRevision < 1 ||
        sourceUpdatedAt == null ||
        importedAt == null) {
      throw const FormatException('Curriculum replica record is invalid.');
    }
    return CurriculumReplicaRecord(
      entityType: entityType,
      localId: localId,
      originId: originId,
      sourceRevision: sourceRevision,
      sourceUpdatedAt: sourceUpdatedAt,
      importedAt: importedAt,
      ownership: ownership,
      sourcePackageOriginId: sourcePackageOriginId,
      sourceFingerprint: _optionalText(json['sourceFingerprint']),
      sourceSchool: _optionalText(json['sourceSchool']),
      assignmentId: _optionalText(json['assignmentId']),
    );
  }
}

class CurriculumImportReceipt {
  final String packageOriginId;
  final int packageRevision;
  final EdsContentType contentType;
  final DateTime importedAt;
  final int conflictCount;
  final String? sourceSchool;
  final String? assignmentId;

  const CurriculumImportReceipt({
    required this.packageOriginId,
    required this.packageRevision,
    required this.contentType,
    required this.importedAt,
    required this.conflictCount,
    this.sourceSchool,
    this.assignmentId,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'packageOriginId': packageOriginId,
    'packageRevision': packageRevision,
    'contentType': contentType.name,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'conflictCount': conflictCount,
    'sourceSchool': ?sourceSchool,
    'assignmentId': ?assignmentId,
  };

  factory CurriculumImportReceipt.fromJson(Map<String, dynamic> json) {
    final packageOriginId = _requiredText(json['packageOriginId']);
    final packageRevision = _positiveInt(json['packageRevision']);
    final contentTypeName = json['contentType']?.toString() ?? '';
    final contentType = EdsContentType.values.firstWhere(
      (item) => item.name == contentTypeName,
      orElse: () => throw const FormatException(
        'Curriculum import receipt has an unknown content type.',
      ),
    );
    final importedAt = DateTime.tryParse(json['importedAt']?.toString() ?? '');
    final conflictCount = _nonNegativeInt(json['conflictCount']);
    if (packageOriginId.isEmpty ||
        packageRevision < 1 ||
        !_curriculumImportContentTypes.contains(contentType) ||
        importedAt == null ||
        conflictCount < 0) {
      throw const FormatException('Curriculum import receipt is invalid.');
    }
    return CurriculumImportReceipt(
      packageOriginId: packageOriginId,
      packageRevision: packageRevision,
      contentType: contentType,
      importedAt: importedAt,
      conflictCount: conflictCount,
      sourceSchool: _optionalText(json['sourceSchool']),
      assignmentId: _optionalText(json['assignmentId']),
    );
  }
}

class CurriculumMergeState {
  final List<CurriculumReplicaRecord> replicas;
  final List<CurriculumImportReceipt> receipts;

  CurriculumMergeState({
    List<CurriculumReplicaRecord> replicas = const [],
    List<CurriculumImportReceipt> receipts = const [],
  }) : replicas = List.unmodifiable(replicas),
       receipts = List.unmodifiable(receipts) {
    final keys = <String>{};
    final localKeys = <String>{};
    for (final record in this.replicas) {
      if (!_curriculumReplicaEntityTypes.contains(record.entityType)) {
        throw const FormatException(
          'Curriculum merge state contains an unsupported entity type.',
        );
      }
      if (!keys.add(record.key)) {
        throw const FormatException(
          'Curriculum merge state contains duplicate origin mappings.',
        );
      }
      if (!localKeys.add('${record.entityType}:${record.localId}')) {
        throw const FormatException(
          'Curriculum merge state maps multiple origins to one local replica.',
        );
      }
    }
    final receiptKeys = <String>{};
    for (final receipt in this.receipts) {
      if (!receiptKeys.add(receipt.packageOriginId)) {
        throw const FormatException(
          'Curriculum merge state contains duplicate package receipts.',
        );
      }
    }
  }

  factory CurriculumMergeState.empty() => CurriculumMergeState();

  CurriculumReplicaRecord? replicaFor(String entityType, String originId) {
    for (final record in replicas) {
      if (record.entityType == entityType && record.originId == originId) {
        return record;
      }
    }
    return null;
  }

  CurriculumReplicaRecord? replicaForLocalId(
    String entityType,
    String localId,
  ) {
    for (final record in replicas) {
      if (record.entityType == entityType && record.localId == localId) {
        return record;
      }
    }
    return null;
  }

  bool isOfficialLocalId(String entityType, String localId) => replicas.any(
    (record) => record.entityType == entityType && record.localId == localId,
  );

  CurriculumMergeState copyWith({
    List<CurriculumReplicaRecord>? replicas,
    List<CurriculumImportReceipt>? receipts,
  }) => CurriculumMergeState(
    replicas: replicas ?? this.replicas,
    receipts: receipts ?? this.receipts,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'replicas': replicas.map((item) => item.toJson()).toList(),
    'receipts': receipts.map((item) => item.toJson()).toList(),
  };

  factory CurriculumMergeState.fromJson(Object? value) {
    if (value == null) return CurriculumMergeState.empty();
    if (value is! Map) {
      throw const FormatException('Curriculum merge state must be an object.');
    }
    final json = Map<String, dynamic>.from(value);
    return CurriculumMergeState(
      replicas: _maps(
        json['replicas'],
      ).map(CurriculumReplicaRecord.fromJson).toList(),
      receipts: _maps(
        json['receipts'],
      ).map(CurriculumImportReceipt.fromJson).toList(),
    );
  }
}

const Set<EdsContentType> _curriculumImportContentTypes = <EdsContentType>{
  EdsContentType.chapterPack,
  EdsContentType.subjectPack,
  EdsContentType.syllabus,
  EdsContentType.teacherPack,
  EdsContentType.schoolCurriculum,
};

const Set<String> _curriculumReplicaEntityTypes = <String>{
  'class',
  'subject',
  'unit',
  'chapter',
  'topic',
  'lessonPlan',
  'resource',
  'paper',
};

const Object _unset = Object();

Iterable<Map<String, dynamic>> _maps(Object? value) sync* {
  if (value == null) return;
  if (value is! List) {
    throw const FormatException('Curriculum merge collection must be a list.');
  }
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Curriculum merge item must be an object.');
    }
    yield Map<String, dynamic>.from(item);
  }
}

String _requiredText(Object? value) => value?.toString().trim() ?? '';

String? _optionalText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _positiveInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}

int _nonNegativeInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? -1;
}
