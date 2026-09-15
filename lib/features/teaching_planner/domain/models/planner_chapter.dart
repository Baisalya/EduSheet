import 'planner_json.dart';
import 'planner_priority.dart';

class PlannerChapter {
  final String id;
  final String subjectId;
  final String? unitId;
  final String title;
  final int sortOrder;
  final int plannedPeriods;
  final PlannerPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const PlannerChapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.sortOrder,
    required this.plannedPeriods,
    this.priority = PlannerPriority.normal,
    required this.createdAt,
    required this.updatedAt,
    this.unitId,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  PlannerChapter copyWith({
    Object? unitId = _unset,
    String? title,
    int? sortOrder,
    int? plannedPeriods,
    PlannerPriority? priority,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) {
    return PlannerChapter(
      id: id,
      subjectId: subjectId,
      unitId: identical(unitId, _unset) ? this.unitId : unitId as String?,
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
    if (unitId != null) 'unitId': unitId,
    'title': title,
    'sortOrder': sortOrder,
    'plannedPeriods': plannedPeriods,
    'priority': priority.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory PlannerChapter.fromJson(Map<String, dynamic> json) => PlannerChapter(
    id: plannerRequiredString(json, 'id'),
    subjectId: plannerRequiredString(json, 'subjectId'),
    unitId: plannerOptionalString(json, 'unitId'),
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
