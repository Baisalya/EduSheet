import 'planner_json.dart';
import 'teaching_status.dart';
import 'planner_priority.dart';

class PlannerTopic {
  final String id;
  final String chapterId;
  final String title;
  final int sortOrder;
  final int plannedPeriods;
  final PlannerPriority priority;
  final int actualPeriods;
  final TeachingProgressStatus status;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? trashedAt;

  const PlannerTopic({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.sortOrder,
    required this.plannedPeriods,
    this.priority = PlannerPriority.normal,
    required this.actualPeriods,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.plannedStart,
    this.plannedEnd,
    this.archivedAt,
    this.trashedAt,
  });

  bool get isArchived => archivedAt != null || trashedAt != null;
  bool get isExplicitlyArchived => archivedAt != null;
  bool get isTrashed => trashedAt != null;

  PlannerTopic copyWith({
    String? chapterId,
    String? title,
    int? sortOrder,
    int? plannedPeriods,
    PlannerPriority? priority,
    int? actualPeriods,
    TeachingProgressStatus? status,
    Object? plannedStart = _unset,
    Object? plannedEnd = _unset,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    Object? trashedAt = _unset,
  }) {
    return PlannerTopic(
      id: id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedPeriods: plannedPeriods ?? this.plannedPeriods,
      priority: priority ?? this.priority,
      actualPeriods: actualPeriods ?? this.actualPeriods,
      status: status ?? this.status,
      plannedStart: identical(plannedStart, _unset)
          ? this.plannedStart
          : plannedStart as DateTime?,
      plannedEnd: identical(plannedEnd, _unset)
          ? this.plannedEnd
          : plannedEnd as DateTime?,
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
    'chapterId': chapterId,
    'title': title,
    'sortOrder': sortOrder,
    'plannedPeriods': plannedPeriods,
    'priority': priority.name,
    'actualPeriods': actualPeriods,
    'status': status.name,
    if (plannedStart != null)
      'plannedStart': plannedStart!.toUtc().toIso8601String(),
    if (plannedEnd != null) 'plannedEnd': plannedEnd!.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
    if (trashedAt != null) 'trashedAt': trashedAt!.toUtc().toIso8601String(),
  };

  factory PlannerTopic.fromJson(Map<String, dynamic> json) => PlannerTopic(
    id: plannerRequiredString(json, 'id'),
    chapterId: plannerRequiredString(json, 'chapterId'),
    title: plannerRequiredString(json, 'title'),
    sortOrder: plannerInt(json, 'sortOrder'),
    plannedPeriods: plannerInt(json, 'plannedPeriods'),
    priority: plannerPriorityFromJson(json['priority']),
    actualPeriods: plannerInt(json, 'actualPeriods'),
    status: teachingProgressStatusFromJson(json['status']),
    plannedStart: plannerOptionalDateTime(json, 'plannedStart'),
    plannedEnd: plannerOptionalDateTime(json, 'plannedEnd'),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
    trashedAt: plannerOptionalDateTime(json, 'trashedAt'),
  );
}

const Object _unset = Object();
