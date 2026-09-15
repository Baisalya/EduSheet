import 'planner_json.dart';
import 'planner_priority.dart';

class PlannerUnit {
  final String id;
  final String subjectId;
  final String title;
  final int sortOrder;
  final int plannedPeriods;
  final PlannerPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const PlannerUnit({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.sortOrder,
    required this.plannedPeriods,
    this.priority = PlannerPriority.normal,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  PlannerUnit copyWith({
    String? title,
    int? sortOrder,
    int? plannedPeriods,
    PlannerPriority? priority,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    return PlannerUnit(
      id: id,
      subjectId: subjectId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedPeriods: plannedPeriods ?? this.plannedPeriods,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'title': title,
    'sortOrder': sortOrder,
    'plannedPeriods': plannedPeriods,
    'priority': priority.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory PlannerUnit.fromJson(Map<String, dynamic> json) => PlannerUnit(
    id: plannerRequiredString(json, 'id'),
    subjectId: plannerRequiredString(json, 'subjectId'),
    title: plannerRequiredString(json, 'title'),
    sortOrder: plannerInt(json, 'sortOrder'),
    plannedPeriods: plannerInt(json, 'plannedPeriods'),
    priority: plannerPriorityFromJson(json['priority']),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
  );
}

const Object _unset = Object();
