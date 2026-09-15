import 'planner_json.dart';

enum TeachingResourceOwnerType {
  plannerClass,
  subject,
  unit,
  chapter,
  topic,
  lessonPlan,
}

TeachingResourceOwnerType teachingResourceOwnerTypeFromJson(Object? value) {
  final name = value?.toString();
  return TeachingResourceOwnerType.values.firstWhere(
    (item) => item.name == name,
    orElse: () =>
        throw FormatException('Unknown teaching resource owner type: $name'),
  );
}

class TeachingResourceOwner {
  final TeachingResourceOwnerType type;
  final String id;

  const TeachingResourceOwner({required this.type, required this.id});

  const TeachingResourceOwner.plannerClass(String id)
    : this(type: TeachingResourceOwnerType.plannerClass, id: id);

  const TeachingResourceOwner.subject(String id)
    : this(type: TeachingResourceOwnerType.subject, id: id);

  const TeachingResourceOwner.unit(String id)
    : this(type: TeachingResourceOwnerType.unit, id: id);

  const TeachingResourceOwner.chapter(String id)
    : this(type: TeachingResourceOwnerType.chapter, id: id);

  const TeachingResourceOwner.topic(String id)
    : this(type: TeachingResourceOwnerType.topic, id: id);

  const TeachingResourceOwner.lessonPlan(String id)
    : this(type: TeachingResourceOwnerType.lessonPlan, id: id);

  bool get isLessonPlan => type == TeachingResourceOwnerType.lessonPlan;

  Map<String, dynamic> toJson() => {'type': type.name, 'id': id};

  factory TeachingResourceOwner.fromJson(Map<String, dynamic> json) {
    return TeachingResourceOwner(
      type: teachingResourceOwnerTypeFromJson(json['type']),
      id: plannerRequiredString(json, 'id'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TeachingResourceOwner &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => '${type.name}:$id';
}
