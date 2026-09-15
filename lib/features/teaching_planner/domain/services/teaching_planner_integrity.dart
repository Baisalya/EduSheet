import '../models/teaching_planner_workspace.dart';
import '../models/teaching_resource.dart';
import '../models/teaching_resource_owner.dart';

class TeachingPlannerIntegrityIssue {
  final String code;
  final String entityId;
  final String message;

  const TeachingPlannerIntegrityIssue({
    required this.code,
    required this.entityId,
    required this.message,
  });

  @override
  String toString() => '$code($entityId): $message';
}

class TeachingPlannerIntegrityException implements Exception {
  final List<TeachingPlannerIntegrityIssue> issues;

  const TeachingPlannerIntegrityException(this.issues);

  @override
  String toString() =>
      'TeachingPlannerIntegrityException: ${issues.join('; ')}';
}

class TeachingPlannerIntegrity {
  const TeachingPlannerIntegrity._();

  static List<TeachingPlannerIntegrityIssue> validate(
    TeachingPlannerWorkspace workspace,
  ) {
    final issues = <TeachingPlannerIntegrityIssue>[];
    final ids = <String>{};

    void checkIdentity(String id, String label) {
      if (id.trim().isEmpty) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'empty_id',
            entityId: id,
            message: '$label has an empty stable id.',
          ),
        );
      } else if (!ids.add(id)) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'duplicate_id',
            entityId: id,
            message: 'Stable ids must be unique across the planner workspace.',
          ),
        );
      }
    }

    for (final item in workspace.classes) {
      checkIdentity(item.id, 'Class');
      _checkCommon(
        issues,
        id: item.id,
        name: item.name,
        sortOrder: item.sortOrder,
      );
    }
    for (final item in workspace.subjects) {
      checkIdentity(item.id, 'Subject');
      _checkCommon(
        issues,
        id: item.id,
        name: item.name,
        sortOrder: item.sortOrder,
      );
      final parent = workspace.classById(item.classId);
      if (parent == null) {
        _missingParent(issues, item.id, 'class', item.classId);
      } else if (parent.isArchived && !item.isArchived) {
        _archivedParent(issues, item.id, parent.id);
      }
    }
    for (final item in workspace.units) {
      checkIdentity(item.id, 'Unit');
      _checkCommon(
        issues,
        id: item.id,
        name: item.title,
        sortOrder: item.sortOrder,
        plannedPeriods: item.plannedPeriods,
      );
      final parent = workspace.subjectById(item.subjectId);
      if (parent == null) {
        _missingParent(issues, item.id, 'subject', item.subjectId);
      } else if (parent.isArchived && !item.isArchived) {
        _archivedParent(issues, item.id, parent.id);
      }
    }
    for (final item in workspace.chapters) {
      checkIdentity(item.id, 'Chapter');
      _checkCommon(
        issues,
        id: item.id,
        name: item.title,
        sortOrder: item.sortOrder,
        plannedPeriods: item.plannedPeriods,
      );
      final subject = workspace.subjectById(item.subjectId);
      if (subject == null) {
        _missingParent(issues, item.id, 'subject', item.subjectId);
      } else if (subject.isArchived && !item.isArchived) {
        _archivedParent(issues, item.id, subject.id);
      }
      if (item.unitId != null) {
        final unit = workspace.unitById(item.unitId!);
        if (unit == null) {
          _missingParent(issues, item.id, 'unit', item.unitId!);
        } else {
          if (unit.subjectId != item.subjectId) {
            issues.add(
              TeachingPlannerIntegrityIssue(
                code: 'cross_subject_unit',
                entityId: item.id,
                message: 'Chapter unit belongs to a different subject.',
              ),
            );
          }
          if (unit.isArchived && !item.isArchived) {
            _archivedParent(issues, item.id, unit.id);
          }
        }
      }
    }
    for (final item in workspace.topics) {
      checkIdentity(item.id, 'Topic');
      _checkCommon(
        issues,
        id: item.id,
        name: item.title,
        sortOrder: item.sortOrder,
        plannedPeriods: item.plannedPeriods,
      );
      if (item.actualPeriods < 0) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'negative_actual_periods',
            entityId: item.id,
            message: 'Actual periods cannot be negative.',
          ),
        );
      }
      if (item.plannedStart != null &&
          item.plannedEnd != null &&
          item.plannedEnd!.isBefore(item.plannedStart!)) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'invalid_date_range',
            entityId: item.id,
            message: 'Topic planned end cannot be before planned start.',
          ),
        );
      }
      final parent = workspace.chapterById(item.chapterId);
      if (parent == null) {
        _missingParent(issues, item.id, 'chapter', item.chapterId);
      } else if (parent.isArchived && !item.isArchived) {
        _archivedParent(issues, item.id, parent.id);
      }
    }

    for (final item in workspace.lessonPlans) {
      checkIdentity(item.id, 'Lesson plan');
      _checkCommon(
        issues,
        id: item.id,
        name: item.title,
        sortOrder: 0,
        plannedPeriods: item.plannedPeriods,
      );
      if (item.startPeriod != null && item.startPeriod! < 1) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'invalid_lesson_start_period',
            entityId: item.id,
            message: 'Lesson start period must be 1 or greater.',
          ),
        );
      }
      if (item.actualPeriods < 0) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'negative_lesson_actual_periods',
            entityId: item.id,
            message: 'Lesson actual periods cannot be negative.',
          ),
        );
      }
      if (item.objective.trim().isEmpty) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'empty_lesson_objective',
            entityId: item.id,
            message: 'Lesson objective cannot be empty.',
          ),
        );
      }
      final plannerClass = workspace.classById(item.classId);
      final subject = workspace.subjectById(item.subjectId);
      final chapter = workspace.chapterById(item.chapterId);
      if (plannerClass == null) {
        _missingParent(issues, item.id, 'class', item.classId);
      }
      if (subject == null) {
        _missingParent(issues, item.id, 'subject', item.subjectId);
      } else if (subject.classId != item.classId) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'lesson_cross_class_subject',
            entityId: item.id,
            message: 'Lesson subject does not belong to its class.',
          ),
        );
      }
      if (chapter == null) {
        _missingParent(issues, item.id, 'chapter', item.chapterId);
      } else if (chapter.subjectId != item.subjectId) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'lesson_cross_subject_chapter',
            entityId: item.id,
            message: 'Lesson chapter does not belong to its subject.',
          ),
        );
      }
      final seenTopics = <String>{};
      for (final topicId in item.topicIds) {
        if (!seenTopics.add(topicId)) {
          issues.add(
            TeachingPlannerIntegrityIssue(
              code: 'duplicate_lesson_topic',
              entityId: item.id,
              message: 'A lesson cannot reference the same topic twice.',
            ),
          );
          continue;
        }
        final topic = workspace.topicById(topicId);
        if (topic == null) {
          _missingParent(issues, item.id, 'topic', topicId);
        } else if (topic.chapterId != item.chapterId) {
          issues.add(
            TeachingPlannerIntegrityIssue(
              code: 'lesson_cross_chapter_topic',
              entityId: item.id,
              message: 'Lesson topic does not belong to its chapter.',
            ),
          );
        } else if (topic.isArchived && !item.isArchived) {
          issues.add(
            TeachingPlannerIntegrityIssue(
              code: 'active_lesson_of_archived_topic',
              entityId: item.id,
              message: 'Active lesson cannot reference an archived topic.',
            ),
          );
        }
      }
      if (!item.isArchived &&
          ((plannerClass?.isArchived ?? false) ||
              (subject?.isArchived ?? false) ||
              (chapter?.isArchived ?? false))) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'active_lesson_of_archived_syllabus',
            entityId: item.id,
            message: 'Active lesson cannot reference archived syllabus items.',
          ),
        );
      }
    }

    for (final item in workspace.resources) {
      checkIdentity(item.id, 'Teaching resource');
      _checkCommon(issues, id: item.id, name: item.title, sortOrder: 0);
      _validateResourceOwner(issues, workspace, item);
      if (item.sizeBytes != null && item.sizeBytes! < 0) {
        issues.add(
          TeachingPlannerIntegrityIssue(
            code: 'negative_resource_size',
            entityId: item.id,
            message: 'Teaching resource size cannot be negative.',
          ),
        );
      }
      switch (item.kind) {
        case TeachingResourceKind.note:
          if ((item.body ?? '').trim().isEmpty) {
            issues.add(
              TeachingPlannerIntegrityIssue(
                code: 'empty_resource_note',
                entityId: item.id,
                message: 'Teaching note cannot be empty.',
              ),
            );
          }
          break;
        case TeachingResourceKind.link:
          final url = Uri.tryParse(item.url ?? '');
          if (url == null || !(url.isScheme('http') || url.isScheme('https'))) {
            issues.add(
              TeachingPlannerIntegrityIssue(
                code: 'invalid_resource_url',
                entityId: item.id,
                message: 'Teaching resource link must use http or https.',
              ),
            );
          }
          break;
        case TeachingResourceKind.file:
          if ((item.localRelativePath ?? '').trim().isEmpty ||
              (item.originalFileName ?? '').trim().isEmpty) {
            issues.add(
              TeachingPlannerIntegrityIssue(
                code: 'invalid_resource_file',
                entityId: item.id,
                message:
                    'Teaching file resource is missing local file metadata.',
              ),
            );
          }
          break;
        case TeachingResourceKind.geometry:
          if (item.geometryJson == null) {
            issues.add(
              TeachingPlannerIntegrityIssue(
                code: 'missing_resource_geometry',
                entityId: item.id,
                message: 'Geometry resource is missing its diagram data.',
              ),
            );
          }
          break;
      }
    }

    return issues;
  }

  static void validateOrThrow(TeachingPlannerWorkspace workspace) {
    final issues = validate(workspace);
    if (issues.isNotEmpty) {
      throw TeachingPlannerIntegrityException(List.unmodifiable(issues));
    }
  }

  static void _validateResourceOwner(
    List<TeachingPlannerIntegrityIssue> issues,
    TeachingPlannerWorkspace workspace,
    TeachingResource resource,
  ) {
    final owner = resource.owner;
    if (owner.id.trim().isEmpty) {
      issues.add(
        TeachingPlannerIntegrityIssue(
          code: 'empty_resource_owner',
          entityId: resource.id,
          message: 'Teaching resource owner id cannot be empty.',
        ),
      );
      return;
    }

    switch (owner.type) {
      case TeachingResourceOwnerType.plannerClass:
        if (workspace.classById(owner.id) == null) {
          _missingParent(issues, resource.id, 'class', owner.id);
        }
        break;
      case TeachingResourceOwnerType.subject:
        if (workspace.subjectById(owner.id) == null) {
          _missingParent(issues, resource.id, 'subject', owner.id);
        }
        break;
      case TeachingResourceOwnerType.unit:
        if (workspace.unitById(owner.id) == null) {
          _missingParent(issues, resource.id, 'unit', owner.id);
        }
        break;
      case TeachingResourceOwnerType.chapter:
        if (workspace.chapterById(owner.id) == null) {
          _missingParent(issues, resource.id, 'chapter', owner.id);
        }
        break;
      case TeachingResourceOwnerType.topic:
        if (workspace.topicById(owner.id) == null) {
          _missingParent(issues, resource.id, 'topic', owner.id);
        }
        break;
      case TeachingResourceOwnerType.lessonPlan:
        if (workspace.lessonPlanById(owner.id) == null) {
          _missingParent(issues, resource.id, 'lesson plan', owner.id);
        }
        break;
    }
  }

  static void _checkCommon(
    List<TeachingPlannerIntegrityIssue> issues, {
    required String id,
    required String name,
    required int sortOrder,
    int? plannedPeriods,
  }) {
    if (name.trim().isEmpty) {
      issues.add(
        TeachingPlannerIntegrityIssue(
          code: 'empty_name',
          entityId: id,
          message: 'Name/title cannot be empty.',
        ),
      );
    }
    if (sortOrder < 0) {
      issues.add(
        TeachingPlannerIntegrityIssue(
          code: 'negative_sort_order',
          entityId: id,
          message: 'Sort order cannot be negative.',
        ),
      );
    }
    if (plannedPeriods != null && plannedPeriods < 0) {
      issues.add(
        TeachingPlannerIntegrityIssue(
          code: 'negative_planned_periods',
          entityId: id,
          message: 'Planned periods cannot be negative.',
        ),
      );
    }
  }

  static void _missingParent(
    List<TeachingPlannerIntegrityIssue> issues,
    String entityId,
    String parentType,
    String parentId,
  ) {
    issues.add(
      TeachingPlannerIntegrityIssue(
        code: 'missing_parent',
        entityId: entityId,
        message: 'Missing $parentType parent $parentId.',
      ),
    );
  }

  static void _archivedParent(
    List<TeachingPlannerIntegrityIssue> issues,
    String entityId,
    String parentId,
  ) {
    issues.add(
      TeachingPlannerIntegrityIssue(
        code: 'active_child_of_archived_parent',
        entityId: entityId,
        message: 'Active item cannot belong to archived parent $parentId.',
      ),
    );
  }
}
