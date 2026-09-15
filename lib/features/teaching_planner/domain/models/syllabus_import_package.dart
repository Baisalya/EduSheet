import 'planner_priority.dart';

class SyllabusImportPackage {
  final String className;
  final String? academicYear;
  final List<SyllabusImportSubject> subjects;

  const SyllabusImportPackage({
    required this.className,
    this.academicYear,
    this.subjects = const [],
  });
}

class SyllabusImportSubject {
  final String name;
  final String? code;
  final List<SyllabusImportUnit> units;
  final List<SyllabusImportChapter> chapters;

  const SyllabusImportSubject({
    required this.name,
    this.code,
    this.units = const [],
    this.chapters = const [],
  });
}

class SyllabusImportUnit {
  final String title;
  final int plannedPeriods;
  final PlannerPriority priority;
  final List<SyllabusImportChapter> chapters;

  const SyllabusImportUnit({
    required this.title,
    this.plannedPeriods = 0,
    this.priority = PlannerPriority.normal,
    this.chapters = const [],
  });
}

class SyllabusImportChapter {
  final String title;
  final int plannedPeriods;
  final PlannerPriority priority;
  final List<SyllabusImportTopic> topics;

  const SyllabusImportChapter({
    required this.title,
    this.plannedPeriods = 0,
    this.priority = PlannerPriority.normal,
    this.topics = const [],
  });
}

class SyllabusImportTopic {
  final String title;
  final int plannedPeriods;
  final PlannerPriority priority;

  const SyllabusImportTopic({
    required this.title,
    this.plannedPeriods = 0,
    this.priority = PlannerPriority.normal,
  });
}
