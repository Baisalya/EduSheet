import 'lesson_plan.dart';
import 'planner_chapter.dart';
import 'planner_class.dart';
import 'planner_subject.dart';
import 'planner_topic.dart';
import 'planner_unit.dart';
import 'teaching_resource.dart';
import 'teaching_resource_owner.dart';

class TeachingPlannerWorkspace {
  final List<PlannerClass> classes;
  final List<PlannerSubject> subjects;
  final List<PlannerUnit> units;
  final List<PlannerChapter> chapters;
  final List<PlannerTopic> topics;
  final List<LessonPlan> lessonPlans;
  final List<TeachingResource> resources;

  TeachingPlannerWorkspace({
    List<PlannerClass> classes = const [],
    List<PlannerSubject> subjects = const [],
    List<PlannerUnit> units = const [],
    List<PlannerChapter> chapters = const [],
    List<PlannerTopic> topics = const [],
    List<LessonPlan> lessonPlans = const [],
    List<TeachingResource> resources = const [],
  }) : classes = List.unmodifiable(classes),
       subjects = List.unmodifiable(subjects),
       units = List.unmodifiable(units),
       chapters = List.unmodifiable(chapters),
       topics = List.unmodifiable(topics),
       lessonPlans = List.unmodifiable(lessonPlans),
       resources = List.unmodifiable(resources);

  factory TeachingPlannerWorkspace.empty() => TeachingPlannerWorkspace();

  bool get isEmpty =>
      classes.isEmpty &&
      subjects.isEmpty &&
      units.isEmpty &&
      chapters.isEmpty &&
      topics.isEmpty &&
      lessonPlans.isEmpty &&
      resources.isEmpty;

  List<PlannerClass> get activeClasses => _sorted(
    classes.where((item) => !item.isArchived),
    (item) => item.sortOrder,
  );

  List<PlannerSubject> activeSubjectsForClass(String classId) => _sorted(
    subjects.where((item) => item.classId == classId && !item.isArchived),
    (item) => item.sortOrder,
  );

  List<PlannerUnit> activeUnitsForSubject(String subjectId) => _sorted(
    units.where((item) => item.subjectId == subjectId && !item.isArchived),
    (item) => item.sortOrder,
  );

  List<PlannerChapter> activeChaptersForSubject(
    String subjectId, {
    String? unitId,
  }) => _sorted(
    chapters.where(
      (item) =>
          item.subjectId == subjectId &&
          item.unitId == unitId &&
          !item.isArchived,
    ),
    (item) => item.sortOrder,
  );

  List<PlannerTopic> activeTopicsForChapter(String chapterId) => _sorted(
    topics.where((item) => item.chapterId == chapterId && !item.isArchived),
    (item) => item.sortOrder,
  );

  PlannerClass? classById(String id) => _firstWhereOrNull(classes, id);
  PlannerSubject? subjectById(String id) => _firstWhereOrNull(subjects, id);
  PlannerUnit? unitById(String id) => _firstWhereOrNull(units, id);
  PlannerChapter? chapterById(String id) => _firstWhereOrNull(chapters, id);
  PlannerTopic? topicById(String id) => _firstWhereOrNull(topics, id);
  LessonPlan? lessonPlanById(String id) => _firstWhereOrNull(lessonPlans, id);
  TeachingResource? resourceById(String id) => _firstWhereOrNull(resources, id);

  List<TeachingResource> activeResourcesForOwner(TeachingResourceOwner owner) {
    final result = resources
        .where((item) => item.owner == owner && !item.isArchived)
        .toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  List<TeachingResource> activeResourcesForLesson(String lessonPlanId) =>
      activeResourcesForOwner(TeachingResourceOwner.lessonPlan(lessonPlanId));

  List<TeachingResource> activeResourcesForClass(String classId) =>
      activeResourcesForOwner(TeachingResourceOwner.plannerClass(classId));

  List<TeachingResource> activeResourcesForSubject(String subjectId) =>
      activeResourcesForOwner(TeachingResourceOwner.subject(subjectId));

  List<TeachingResource> activeResourcesForUnit(String unitId) =>
      activeResourcesForOwner(TeachingResourceOwner.unit(unitId));

  List<TeachingResource> activeResourcesForChapter(String chapterId) =>
      activeResourcesForOwner(TeachingResourceOwner.chapter(chapterId));

  List<TeachingResource> activeResourcesForTopic(String topicId) =>
      activeResourcesForOwner(TeachingResourceOwner.topic(topicId));

  List<LessonPlan> get activeLessonPlans {
    final result = lessonPlans.where((item) => !item.isArchived).toList();
    result.sort((a, b) {
      final byDate = a.plannedDate.compareTo(b.plannedDate);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });
    return result;
  }

  List<LessonPlan> activeLessonPlansForClass(String classId) =>
      activeLessonPlans.where((item) => item.classId == classId).toList();

  int get activeClassCount => activeClasses.length;
  int get activeSubjectCount =>
      subjects.where((item) => !item.isArchived).length;
  int get activeTopicCount => topics.where((item) => !item.isArchived).length;

  TeachingPlannerWorkspace copyWith({
    List<PlannerClass>? classes,
    List<PlannerSubject>? subjects,
    List<PlannerUnit>? units,
    List<PlannerChapter>? chapters,
    List<PlannerTopic>? topics,
    List<LessonPlan>? lessonPlans,
    List<TeachingResource>? resources,
  }) {
    return TeachingPlannerWorkspace(
      classes: classes ?? this.classes,
      subjects: subjects ?? this.subjects,
      units: units ?? this.units,
      chapters: chapters ?? this.chapters,
      topics: topics ?? this.topics,
      lessonPlans: lessonPlans ?? this.lessonPlans,
      resources: resources ?? this.resources,
    );
  }

  Map<String, dynamic> toJson() => {
    'classes': classes.map((item) => item.toJson()).toList(),
    'subjects': subjects.map((item) => item.toJson()).toList(),
    'units': units.map((item) => item.toJson()).toList(),
    'chapters': chapters.map((item) => item.toJson()).toList(),
    'topics': topics.map((item) => item.toJson()).toList(),
    'lessonPlans': lessonPlans.map((item) => item.toJson()).toList(),
    'resources': resources.map((item) => item.toJson()).toList(),
  };

  factory TeachingPlannerWorkspace.fromJson(Map<String, dynamic> json) {
    return TeachingPlannerWorkspace(
      classes: _maps(json['classes']).map(PlannerClass.fromJson).toList(),
      subjects: _maps(json['subjects']).map(PlannerSubject.fromJson).toList(),
      units: _maps(json['units']).map(PlannerUnit.fromJson).toList(),
      chapters: _maps(json['chapters']).map(PlannerChapter.fromJson).toList(),
      topics: _maps(json['topics']).map(PlannerTopic.fromJson).toList(),
      lessonPlans: _maps(json['lessonPlans']).map(LessonPlan.fromJson).toList(),
      resources: _maps(
        json['resources'],
      ).map(TeachingResource.fromJson).toList(),
    );
  }
}

List<T> _sorted<T>(Iterable<T> values, int Function(T value) orderOf) {
  final result = values.toList();
  result.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
  return result;
}

T? _firstWhereOrNull<T>(Iterable<T> values, String id) {
  for (final value in values) {
    final dynamic entity = value;
    if (entity.id == id) return value;
  }
  return null;
}

Iterable<Map<String, dynamic>> _maps(Object? value) sync* {
  if (value == null) return;
  if (value is! List) {
    throw const FormatException('Planner collection must be a list.');
  }
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Planner collection item must be an object.');
    }
    yield Map<String, dynamic>.from(item);
  }
}
