import 'curriculum_merge_state.dart';
import 'teaching_planner_workspace.dart';

/// Presentation/domain view of the two logical Teaching Planner layers.
///
/// Imported curriculum replicas belong to the official master layer. Anything
/// not present in the merge sidecar belongs to the teacher/local working layer.
enum CurriculumWorkspaceLayer { officialMaster, teacherWorkspace }

class CurriculumLayerDescriptor {
  final CurriculumWorkspaceLayer layer;
  final String entityType;
  final String localId;
  final String? originId;
  final int? sourceRevision;
  final String? sourceSchool;
  final String? assignmentId;

  const CurriculumLayerDescriptor({
    required this.layer,
    required this.entityType,
    required this.localId,
    this.originId,
    this.sourceRevision,
    this.sourceSchool,
    this.assignmentId,
  });

  bool get isOfficial => layer == CurriculumWorkspaceLayer.officialMaster;
  bool get isTeacherOwned => !isOfficial;

  String get label => isOfficial ? 'Official curriculum' : 'Teacher workspace';
}

class CurriculumLayerPolicy {
  final CurriculumMergeState mergeState;

  const CurriculumLayerPolicy(this.mergeState);

  CurriculumLayerDescriptor describe(String entityType, String localId) {
    final record = mergeState.replicaForLocalId(entityType, localId);
    if (record == null) {
      return CurriculumLayerDescriptor(
        layer: CurriculumWorkspaceLayer.teacherWorkspace,
        entityType: entityType,
        localId: localId,
      );
    }
    return CurriculumLayerDescriptor(
      layer: CurriculumWorkspaceLayer.officialMaster,
      entityType: entityType,
      localId: localId,
      originId: record.originId,
      sourceRevision: record.sourceRevision,
      sourceSchool: record.sourceSchool,
      assignmentId: record.assignmentId,
    );
  }

  bool isOfficial(String entityType, String localId) =>
      mergeState.isOfficialLocalId(entityType, localId);

  bool canEditMasterStructure(String entityType, String localId) =>
      !isOfficial(entityType, localId);

  bool canRemoveResource(String resourceId) =>
      !isOfficial('resource', resourceId);

  /// Teacher execution is deliberately writable even when the lesson/topic
  /// definition itself came from the official curriculum layer.
  bool canRecordTeacherExecution(String entityType, String localId) =>
      localId.trim().isNotEmpty &&
      (entityType == 'lessonPlan' || entityType == 'topic');

  int get officialReplicaCount => mergeState.replicas.length;

  int teacherOwnedEntityCount(TeachingPlannerWorkspace workspace) {
    var count = 0;
    void add(String type, Iterable<String> ids) {
      for (final id in ids) {
        if (!isOfficial(type, id)) count++;
      }
    }

    add('class', workspace.classes.map((item) => item.id));
    add('subject', workspace.subjects.map((item) => item.id));
    add('unit', workspace.units.map((item) => item.id));
    add('chapter', workspace.chapters.map((item) => item.id));
    add('topic', workspace.topics.map((item) => item.id));
    add('lessonPlan', workspace.lessonPlans.map((item) => item.id));
    add('resource', workspace.resources.map((item) => item.id));
    return count;
  }
}
