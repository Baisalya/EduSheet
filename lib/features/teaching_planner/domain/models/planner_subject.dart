import 'planner_json.dart';

class PlannerSubject {
  final String id;
  final String classId;
  final String name;
  final String? code;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const PlannerSubject({
    required this.id,
    required this.classId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.code,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  PlannerSubject copyWith({
    String? name,
    Object? code = _unset,
    int? sortOrder,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    return PlannerSubject(
      id: id,
      classId: classId,
      name: name ?? this.name,
      code: identical(code, _unset) ? this.code : code as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'classId': classId,
    'name': name,
    if (code != null) 'code': code,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory PlannerSubject.fromJson(Map<String, dynamic> json) => PlannerSubject(
    id: plannerRequiredString(json, 'id'),
    classId: plannerRequiredString(json, 'classId'),
    name: plannerRequiredString(json, 'name'),
    code: plannerOptionalString(json, 'code'),
    sortOrder: plannerInt(json, 'sortOrder'),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
  );
}

const Object _unset = Object();
