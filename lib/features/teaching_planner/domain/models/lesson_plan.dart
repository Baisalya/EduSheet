import 'planner_json.dart';
import 'teaching_status.dart';

class LessonPlan {
  final String id;
  final String classId;
  final String subjectId;
  final String chapterId;
  final List<String> topicIds;
  final String title;
  final DateTime plannedDate;
  final int plannedPeriods;
  final int? startPeriod;
  final String objective;
  final String? materials;
  final String? activities;
  final String? homework;
  final String? notes;
  final TeachingProgressStatus status;
  final int actualPeriods;
  final DateTime? taughtAt;
  final String? reflection;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const LessonPlan({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.chapterId,
    this.topicIds = const [],
    required this.title,
    required this.plannedDate,
    required this.plannedPeriods,
    this.startPeriod,
    required this.objective,
    this.materials,
    this.activities,
    this.homework,
    this.notes,
    this.status = TeachingProgressStatus.planned,
    this.actualPeriods = 0,
    this.taughtAt,
    this.reflection,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  LessonPlan copyWith({
    String? classId,
    String? subjectId,
    String? chapterId,
    List<String>? topicIds,
    String? title,
    DateTime? plannedDate,
    int? plannedPeriods,
    Object? startPeriod = _unset,
    String? objective,
    Object? materials = _unset,
    Object? activities = _unset,
    Object? homework = _unset,
    Object? notes = _unset,
    TeachingProgressStatus? status,
    int? actualPeriods,
    Object? taughtAt = _unset,
    Object? reflection = _unset,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
  }) => LessonPlan(
    id: id,
    classId: classId ?? this.classId,
    subjectId: subjectId ?? this.subjectId,
    chapterId: chapterId ?? this.chapterId,
    topicIds: List.unmodifiable(topicIds ?? this.topicIds),
    title: title ?? this.title,
    plannedDate: plannedDate ?? this.plannedDate,
    plannedPeriods: plannedPeriods ?? this.plannedPeriods,
    startPeriod: identical(startPeriod, _unset)
        ? this.startPeriod
        : startPeriod as int?,
    objective: objective ?? this.objective,
    materials: identical(materials, _unset)
        ? this.materials
        : materials as String?,
    activities: identical(activities, _unset)
        ? this.activities
        : activities as String?,
    homework: identical(homework, _unset) ? this.homework : homework as String?,
    notes: identical(notes, _unset) ? this.notes : notes as String?,
    status: status ?? this.status,
    actualPeriods: actualPeriods ?? this.actualPeriods,
    taughtAt: identical(taughtAt, _unset)
        ? this.taughtAt
        : taughtAt as DateTime?,
    reflection: identical(reflection, _unset)
        ? this.reflection
        : reflection as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: identical(archivedAt, _unset)
        ? this.archivedAt
        : archivedAt as DateTime?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'classId': classId,
    'subjectId': subjectId,
    'chapterId': chapterId,
    'topicIds': topicIds,
    'title': title,
    'plannedDate': plannedDate.toUtc().toIso8601String(),
    'plannedPeriods': plannedPeriods,
    if (startPeriod != null) 'startPeriod': startPeriod,
    'objective': objective,
    if (materials != null) 'materials': materials,
    if (activities != null) 'activities': activities,
    if (homework != null) 'homework': homework,
    if (notes != null) 'notes': notes,
    'status': status.name,
    'actualPeriods': actualPeriods,
    if (taughtAt != null) 'taughtAt': taughtAt!.toUtc().toIso8601String(),
    if (reflection != null) 'reflection': reflection,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
  };

  factory LessonPlan.fromJson(Map<String, dynamic> json) => LessonPlan(
    id: plannerRequiredString(json, 'id'),
    classId: plannerRequiredString(json, 'classId'),
    subjectId: plannerRequiredString(json, 'subjectId'),
    chapterId: plannerRequiredString(json, 'chapterId'),
    topicIds: _stringList(json['topicIds']),
    title: plannerRequiredString(json, 'title'),
    plannedDate: plannerRequiredDateTime(json, 'plannedDate'),
    plannedPeriods: plannerInt(json, 'plannedPeriods'),
    startPeriod: _optionalInt(json['startPeriod']),
    objective: plannerRequiredString(json, 'objective'),
    materials: plannerOptionalString(json, 'materials'),
    activities: plannerOptionalString(json, 'activities'),
    homework: plannerOptionalString(json, 'homework'),
    notes: plannerOptionalString(json, 'notes'),
    status: teachingProgressStatusFromJson(json['status']),
    actualPeriods: plannerInt(json, 'actualPeriods'),
    taughtAt: plannerOptionalDateTime(json, 'taughtAt'),
    reflection: plannerOptionalString(json, 'reflection'),
    createdAt: plannerRequiredDateTime(json, 'createdAt'),
    updatedAt: plannerRequiredDateTime(json, 'updatedAt'),
    archivedAt: plannerOptionalDateTime(json, 'archivedAt'),
  );
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('topicIds must be a list.');
  return List.unmodifiable(
    value.map((item) {
      final text = item.toString().trim();
      if (text.isEmpty)
        throw const FormatException('topicIds cannot contain empty ids.');
      return text;
    }),
  );
}

const Object _unset = Object();

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  if (parsed == null) throw const FormatException('Invalid startPeriod.');
  return parsed;
}
