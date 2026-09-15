import 'planner_json.dart';

class PlannerClass {
  final String id;
  final String name;
  final String? academicYear;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const PlannerClass({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.academicYear,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  PlannerClass copyWith({
    String? name,
    Object? academicYear = _unset,
    int? sortOrder,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    return PlannerClass(
      id: id,
      name: name ?? this.name,
      academicYear: identical(academicYear, _unset)
          ? this.academicYear
          : academicYear as String?,
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
    'name': name,
    if (academicYear != null) 'academicYear': academicYear,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory PlannerClass.fromJson(Map<String, dynamic> json) => PlannerClass(
    id: plannerRequiredString(json, 'id'),
    name: plannerRequiredString(json, 'name'),
    academicYear: plannerOptionalString(json, 'academicYear'),
    sortOrder: plannerInt(json, 'sortOrder'),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
  );
}

const Object _unset = Object();
