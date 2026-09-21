import 'planner_json.dart';
import 'planner_priority.dart';
import 'teaching_status.dart';

class PlannerChapter {
  final String id;
  final String subjectId;
  final String? unitId;
  final String title;
  final int sortOrder;
  final int plannedPeriods;
  final PlannerPriority priority;
  final TeachingProgressStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? trashedAt;

  const PlannerChapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.sortOrder,
    required this.plannedPeriods,
    this.priority = PlannerPriority.normal,
    this.status = TeachingProgressStatus.planned,
    required this.createdAt,
    required this.updatedAt,
    this.unitId,
    this.archivedAt,
    this.trashedAt,
  });

  bool get isArchived => archivedAt != null || trashedAt != null;
  bool get isExplicitlyArchived => archivedAt != null;
  bool get isTrashed => trashedAt != null;

  PlannerChapter copyWith({
    String? subjectId,
    Object? unitId = _unset,
    String? title,
    int? sortOrder,
    int? plannedPeriods,
    PlannerPriority? priority,
    TeachingProgressStatus? status,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    Object? trashedAt = _unset,
  }) {
    return PlannerChapter(
      id: id,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _unset) ? this.unitId : unitId as String?,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedPeriods: plannedPeriods ?? this.plannedPeriods,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      trashedAt: identical(trashedAt, _unset)
          ? this.trashedAt
          : trashedAt as DateTime?,
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
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
    if (trashedAt != null) 'trashedAt': trashedAt!.toUtc().toIso8601String(),
  };

  factory PlannerChapter.fromJson(Map<String, dynamic> json) => PlannerChapter(
    id: plannerRequiredString(json, 'id'),
    subjectId: plannerRequiredString(json, 'subjectId'),
    unitId: plannerOptionalString(json, 'unitId'),
    title: plannerRequiredString(json, 'title'),
    sortOrder: plannerInt(json, 'sortOrder'),
    plannedPeriods: plannerInt(json, 'plannedPeriods'),
    priority: plannerPriorityFromJson(json['priority']),
    status: teachingProgressStatusFromJson(json['status']),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
    trashedAt: plannerOptionalDateTime(json, 'trashedAt'),
  );
}

const Object _unset = Object();
