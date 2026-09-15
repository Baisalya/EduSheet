import 'planner_json.dart';
import 'teaching_resource_owner.dart';

enum TeachingResourceKind { note, file, link, geometry }

enum TeachingResourceRole {
  teachInClass,
  homework,
  worksheet,
  reference,
  teacherOnly,
}

TeachingResourceKind teachingResourceKindFromJson(Object? value) {
  final name = value?.toString();
  return TeachingResourceKind.values.firstWhere(
    (item) => item.name == name,
    orElse: () =>
        throw FormatException('Unknown teaching resource kind: $name'),
  );
}

TeachingResourceRole teachingResourceRoleFromJson(Object? value) {
  final name = value?.toString();
  return TeachingResourceRole.values.firstWhere(
    (item) => item.name == name,
    orElse: () => TeachingResourceRole.teachInClass,
  );
}

class TeachingResource {
  final String id;
  final TeachingResourceOwner owner;
  final TeachingResourceKind kind;
  final TeachingResourceRole role;
  final String title;
  final String? body;
  final String? url;
  final String? originalFileName;
  final String? mimeType;
  final String? localRelativePath;
  final int? sizeBytes;
  final Map<String, dynamic>? geometryJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  TeachingResource({
    required this.id,
    String? lessonPlanId,
    TeachingResourceOwner? owner,
    required this.kind,
    this.role = TeachingResourceRole.teachInClass,
    required this.title,
    this.body,
    this.url,
    this.originalFileName,
    this.mimeType,
    this.localRelativePath,
    this.sizeBytes,
    this.geometryJson,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  }) : assert(
         owner != null || lessonPlanId != null,
         'TeachingResource requires an owner or legacy lessonPlanId.',
       ),
       assert(
         owner == null ||
             lessonPlanId == null ||
             (owner.type == TeachingResourceOwnerType.lessonPlan &&
                 owner.id == lessonPlanId),
         'owner and lessonPlanId must reference the same lesson when both are supplied.',
       ),
       owner = owner ?? TeachingResourceOwner.lessonPlan(lessonPlanId ?? '');

  bool get isArchived => archivedAt != null;

  /// Backward-compatible accessor for existing lesson-only Teaching Workspace
  /// code and old Teaching Pack tests. Syllabus-owned resources return null.
  String? get lessonPlanId =>
      owner.type == TeachingResourceOwnerType.lessonPlan ? owner.id : null;

  TeachingResource copyWith({
    TeachingResourceOwner? owner,
    String? lessonPlanId,
    TeachingResourceKind? kind,
    TeachingResourceRole? role,
    String? title,
    Object? body = _unset,
    Object? url = _unset,
    Object? originalFileName = _unset,
    Object? mimeType = _unset,
    Object? localRelativePath = _unset,
    Object? sizeBytes = _unset,
    Object? geometryJson = _unset,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    final nextOwner =
        owner ??
        (lessonPlanId == null
            ? this.owner
            : TeachingResourceOwner.lessonPlan(lessonPlanId));
    return TeachingResource(
      id: id,
      owner: nextOwner,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      title: title ?? this.title,
      body: identical(body, _unset) ? this.body : body as String?,
      url: identical(url, _unset) ? this.url : url as String?,
      originalFileName: identical(originalFileName, _unset)
          ? this.originalFileName
          : originalFileName as String?,
      mimeType: identical(mimeType, _unset)
          ? this.mimeType
          : mimeType as String?,
      localRelativePath: identical(localRelativePath, _unset)
          ? this.localRelativePath
          : localRelativePath as String?,
      sizeBytes: identical(sizeBytes, _unset)
          ? this.sizeBytes
          : sizeBytes as int?,
      geometryJson: identical(geometryJson, _unset)
          ? this.geometryJson
          : geometryJson as Map<String, dynamic>?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner': owner.toJson(),
    if (lessonPlanId != null) 'lessonPlanId': lessonPlanId,
    'kind': kind.name,
    'role': role.name,
    'title': title,
    if (body != null) 'body': body,
    if (url != null) 'url': url,
    if (originalFileName != null) 'originalFileName': originalFileName,
    if (mimeType != null) 'mimeType': mimeType,
    if (localRelativePath != null) 'localRelativePath': localRelativePath,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (geometryJson != null) 'geometryJson': geometryJson,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory TeachingResource.fromJson(Map<String, dynamic> json) =>
      TeachingResource(
        id: plannerRequiredString(json, 'id'),
        owner: _ownerFromJson(json),
        kind: teachingResourceKindFromJson(json['kind']),
        role: teachingResourceRoleFromJson(json['role']),
        title: plannerRequiredString(json, 'title'),
        body: plannerOptionalString(json, 'body'),
        url: plannerOptionalString(json, 'url'),
        originalFileName: plannerOptionalString(json, 'originalFileName'),
        mimeType: plannerOptionalString(json, 'mimeType'),
        localRelativePath: plannerOptionalString(json, 'localRelativePath'),
        sizeBytes: _optionalInt(json['sizeBytes']),
        geometryJson: json['geometryJson'] is Map
            ? Map<String, dynamic>.from(json['geometryJson'] as Map)
            : null,
        createdAt: plannerRequiredDateTime(json, 'createdAt'),
        updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
        archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
      );
}

TeachingResourceOwner _ownerFromJson(Map<String, dynamic> json) {
  final legacyLessonPlanId = plannerOptionalString(json, 'lessonPlanId');
  final ownerJson = json['owner'];
  if (ownerJson is Map) {
    final owner = TeachingResourceOwner.fromJson(
      Map<String, dynamic>.from(ownerJson),
    );
    _validateLegacyLessonOwner(owner, legacyLessonPlanId);
    return owner;
  }

  final ownerType = json['ownerType'];
  final ownerId = plannerOptionalString(json, 'ownerId');
  if (ownerType != null && ownerId != null) {
    final owner = TeachingResourceOwner(
      type: teachingResourceOwnerTypeFromJson(ownerType),
      id: ownerId,
    );
    _validateLegacyLessonOwner(owner, legacyLessonPlanId);
    return owner;
  }

  if (legacyLessonPlanId != null) {
    return TeachingResourceOwner.lessonPlan(legacyLessonPlanId);
  }

  throw const FormatException('Teaching resource owner is missing.');
}

void _validateLegacyLessonOwner(
  TeachingResourceOwner owner,
  String? legacyLessonPlanId,
) {
  if (legacyLessonPlanId == null) return;
  if (owner.type != TeachingResourceOwnerType.lessonPlan ||
      owner.id != legacyLessonPlanId) {
    throw const FormatException(
      'Teaching resource owner conflicts with legacy lessonPlanId.',
    );
  }
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

const Object _unset = Object();
