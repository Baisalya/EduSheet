import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../premium/application/premium_controller.dart';
import '../../application/teaching_planner_entitlement_adapter.dart';
import '../../application/teaching_planner_service.dart';
import '../../application/teaching_resource_attachment_service.dart';
import '../../data/local_teaching_planner_repository.dart';
import '../../data/teaching_resource_file_store.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/teaching_status.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/repositories/teaching_planner_repository.dart';
import '../services/teaching_resource_file_picker.dart';
import '../../../guided_experience/demo/guided_demo_controller.dart';
import '../../../guided_experience/demo/guided_demo_providers.dart';

final productionTeachingPlannerRepositoryProvider =
    Provider<TeachingPlannerRepository>((ref) {
      return LocalTeachingPlannerRepository();
    });

final teachingPlannerRepositoryProvider = Provider<TeachingPlannerRepository>((
  ref,
) {
  final demoSession = ref.watch(guidedDemoControllerProvider);
  if (isSyllabusDemoActive(demoSession)) {
    return ref.watch(demoTeachingPlannerRepositoryProvider);
  }
  return ref.watch(productionTeachingPlannerRepositoryProvider);
});

final teachingResourceFileStoreProvider = Provider<TeachingResourceFileStore>((
  ref,
) {
  return TeachingResourceFileStore();
});

final teachingPlannerServiceProvider = Provider<TeachingPlannerService>((ref) {
  return TeachingPlannerService(ref.watch(teachingPlannerRepositoryProvider));
});

final teachingResourceAttachmentServiceProvider =
    Provider<TeachingResourceAttachmentService>((ref) {
      return TeachingResourceAttachmentService(
        ref.watch(teachingPlannerServiceProvider),
        ref.watch(teachingResourceFileStoreProvider),
      );
    });

final teachingResourceFilePickerProvider = Provider<TeachingResourceFilePicker>(
  (ref) {
    return const TeachingResourceFilePicker();
  },
);

final teachingPlannerCapabilitiesProvider =
    Provider<TeachingPlannerCapabilities>((ref) {
      final premium = ref.watch(premiumProvider);
      return TeachingPlannerEntitlementAdapter.fromPremiumState(premium);
    });

class TeachingPlannerState {
  final TeachingPlannerWorkspace workspace;
  final bool isLoading;
  final String? errorMessage;

  TeachingPlannerState({
    TeachingPlannerWorkspace? workspace,
    this.isLoading = false,
    this.errorMessage,
  }) : workspace = workspace ?? TeachingPlannerWorkspace.empty();

  TeachingPlannerState copyWith({
    TeachingPlannerWorkspace? workspace,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return TeachingPlannerState(
      workspace: workspace ?? this.workspace,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class TeachingPlannerNotifier extends StateNotifier<TeachingPlannerState> {
  TeachingPlannerNotifier(this._service, this._attachmentService)
    : super(TeachingPlannerState()) {
    load();
  }

  final TeachingPlannerService _service;
  final TeachingResourceAttachmentService _attachmentService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final workspace = await _service.load();
      state = state.copyWith(
        workspace: workspace,
        isLoading: false,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Teaching Planner data could not be loaded safely. Your existing data was not overwritten.',
      );
    }
  }

  Future<bool> createClass({required String name, String? academicYear}) {
    return _run(
      () => _service.createClass(name: name, academicYear: academicYear),
    );
  }

  Future<bool> updateClass(
    String classId, {
    required String name,
    String? academicYear,
  }) {
    return _run(
      () =>
          _service.updateClass(classId, name: name, academicYear: academicYear),
    );
  }

  Future<bool> createSubject({
    required String classId,
    required String name,
    String? code,
  }) {
    return _run(
      () => _service.createSubject(classId: classId, name: name, code: code),
    );
  }

  Future<bool> updateSubject(
    String subjectId, {
    required String name,
    String? code,
  }) {
    return _run(
      () => _service.updateSubject(subjectId, name: name, code: code),
    );
  }

  Future<bool> createUnit({
    required String subjectId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
  }) {
    return _run(
      () => _service.createUnit(
        subjectId: subjectId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
      ),
    );
  }

  Future<bool> updateUnit(
    String unitId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) {
    return _run(
      () => _service.updateUnit(
        unitId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
      ),
    );
  }

  Future<bool> createChapter({
    required String subjectId,
    String? unitId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
  }) {
    return _run(
      () => _service.createChapter(
        subjectId: subjectId,
        unitId: unitId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
      ),
    );
  }

  Future<bool> updateChapter(
    String chapterId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
    String? unitId,
  }) {
    return _run(
      () => _service.updateChapter(
        chapterId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
        unitId: unitId,
      ),
    );
  }

  Future<bool> createTopic({
    required String chapterId,
    required String title,
    int plannedPeriods = 0,
    PlannerPriority priority = PlannerPriority.normal,
  }) {
    return _run(
      () => _service.createTopic(
        chapterId: chapterId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
      ),
    );
  }

  Future<bool> updateTopic(
    String topicId, {
    required String title,
    required int plannedPeriods,
    required PlannerPriority priority,
  }) {
    return _run(
      () => _service.updateTopic(
        topicId,
        title: title,
        plannedPeriods: plannedPeriods,
        priority: priority,
      ),
    );
  }

  Future<bool> importSyllabus(SyllabusImportPackage package) {
    return _run(() => _service.importSyllabus(package));
  }

  Future<bool> archiveClass(String classId) {
    return _run(() => _service.archiveClass(classId));
  }

  Future<bool> archiveSubject(String subjectId) {
    return _run(() => _service.archiveSubject(subjectId));
  }

  Future<bool> archiveUnit(String unitId) {
    return _run(() => _service.archiveUnit(unitId));
  }

  Future<bool> archiveChapter(String chapterId) {
    return _run(() => _service.archiveChapter(chapterId));
  }

  Future<bool> archiveTopic(String topicId) {
    return _run(() => _service.archiveTopic(topicId));
  }

  Future<bool> reorderSubjects({
    required String classId,
    required List<String> orderedSubjectIds,
  }) {
    return _run(
      () => _service.reorderSubjects(
        classId: classId,
        orderedSubjectIds: orderedSubjectIds,
      ),
    );
  }

  Future<bool> reorderUnits({
    required String subjectId,
    required List<String> orderedUnitIds,
  }) {
    return _run(
      () => _service.reorderUnits(
        subjectId: subjectId,
        orderedUnitIds: orderedUnitIds,
      ),
    );
  }

  Future<bool> reorderChapters({
    required String subjectId,
    String? unitId,
    required List<String> orderedChapterIds,
  }) {
    return _run(
      () => _service.reorderChapters(
        subjectId: subjectId,
        unitId: unitId,
        orderedChapterIds: orderedChapterIds,
      ),
    );
  }

  Future<bool> reorderTopics({
    required String chapterId,
    required List<String> orderedTopicIds,
  }) {
    return _run(
      () => _service.reorderTopics(
        chapterId: chapterId,
        orderedTopicIds: orderedTopicIds,
      ),
    );
  }

  Future<bool> createLessonPlan({
    required String classId,
    required String subjectId,
    required String chapterId,
    List<String> topicIds = const [],
    required String title,
    required DateTime plannedDate,
    required int plannedPeriods,
    required String objective,
    String? materials,
    String? activities,
    String? homework,
    String? notes,
    TeachingProgressStatus status = TeachingProgressStatus.planned,
  }) {
    return _run(
      () => _service.createLessonPlan(
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: topicIds,
        title: title,
        plannedDate: plannedDate,
        plannedPeriods: plannedPeriods,
        objective: objective,
        materials: materials,
        activities: activities,
        homework: homework,
        notes: notes,
        status: status,
      ),
    );
  }

  Future<bool> updateLessonPlan(
    LessonPlan lesson, {
    required String classId,
    required String subjectId,
    required String chapterId,
    List<String> topicIds = const [],
    required String title,
    required DateTime plannedDate,
    required int plannedPeriods,
    required String objective,
    String? materials,
    String? activities,
    String? homework,
    String? notes,
    required TeachingProgressStatus status,
  }) {
    return _run(
      () => _service.updateLessonPlan(
        lesson.id,
        classId: classId,
        subjectId: subjectId,
        chapterId: chapterId,
        topicIds: topicIds,
        title: title,
        plannedDate: plannedDate,
        plannedPeriods: plannedPeriods,
        objective: objective,
        materials: materials,
        activities: activities,
        homework: homework,
        notes: notes,
        status: status,
      ),
    );
  }

  Future<bool> recordLessonProgress(
    String lessonPlanId, {
    required TeachingProgressStatus status,
    required int actualPeriods,
    DateTime? taughtAt,
    String? reflection,
  }) {
    return _run(
      () => _service.recordLessonProgress(
        lessonPlanId,
        status: status,
        actualPeriods: actualPeriods,
        taughtAt: taughtAt,
        reflection: reflection,
      ),
    );
  }

  Future<bool> updateTopicProgress(
    String topicId, {
    required TeachingProgressStatus status,
    required int actualPeriods,
  }) {
    return _run(
      () => _service.updateTopicProgress(
        topicId,
        status: status,
        actualPeriods: actualPeriods,
      ),
    );
  }

  Future<bool> scheduleLessonPlan(
    String lessonPlanId, {
    required DateTime plannedDate,
    int? startPeriod,
  }) {
    return _run(
      () => _service.scheduleLessonPlan(
        lessonPlanId,
        plannedDate: plannedDate,
        startPeriod: startPeriod,
      ),
    );
  }

  Future<bool> archiveLessonPlan(String lessonPlanId) {
    return _run(() => _service.archiveLessonPlan(lessonPlanId));
  }

  Future<bool> createTeachingResource({
    String? resourceId,
    String? lessonPlanId,
    TeachingResourceOwner? owner,
    required TeachingResourceKind kind,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
    required String title,
    String? body,
    String? url,
    String? originalFileName,
    String? mimeType,
    String? localRelativePath,
    int? sizeBytes,
    String? linkedPaperId,
    Map<String, dynamic>? geometryJson,
  }) {
    return _run(
      () => _service.createTeachingResource(
        resourceId: resourceId,
        lessonPlanId: lessonPlanId,
        owner: owner,
        kind: kind,
        role: role,
        title: title,
        body: body,
        url: url,
        originalFileName: originalFileName,
        mimeType: mimeType,
        localRelativePath: localRelativePath,
        sizeBytes: sizeBytes,
        linkedPaperId: linkedPaperId,
        geometryJson: geometryJson,
      ),
    );
  }

  Future<bool> updateTeachingResource(
    String resourceId, {
    required TeachingResourceRole role,
    required String title,
    String? body,
    String? url,
    Map<String, dynamic>? geometryJson,
  }) {
    return _run(
      () => _service.updateTeachingResource(
        resourceId,
        role: role,
        title: title,
        body: body,
        url: url,
        geometryJson: geometryJson,
      ),
    );
  }

  Future<bool> importTeachingResources({
    String? lessonPlanId,
    TeachingResourceOwner? owner,
    required List<TeachingResource> resources,
  }) {
    return _run(
      () => _service.importTeachingResources(
        lessonPlanId: lessonPlanId,
        owner: owner,
        resources: resources,
      ),
    );
  }

  Future<bool> attachTeachingFiles({
    required TeachingResourceOwner owner,
    required List<TeachingAttachmentCandidate> files,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
  }) {
    return _run(
      () => _attachmentService.attachFiles(
        owner: owner,
        files: files,
        role: role,
      ),
    );
  }

  Future<bool> archiveTeachingResource(String resourceId) {
    return _run(() => _service.archiveTeachingResource(resourceId));
  }

  Future<bool> restoreWorkspace(TeachingPlannerWorkspace workspace) {
    return _run(() => _service.restoreWorkspace(workspace));
  }

  Future<bool> _run(
    Future<TeachingPlannerWorkspace> Function() operation,
  ) async {
    try {
      final workspace = await operation();
      state = state.copyWith(workspace: workspace, errorMessage: null);
      return true;
    } catch (error) {
      state = state.copyWith(errorMessage: _friendlyError(error));
      return false;
    }
  }

  String _friendlyError(Object error) {
    if (error is TeachingPlannerOperationException) {
      return error.message;
    }
    return 'Teaching Planner could not save this change. No data was discarded silently.';
  }
}

final teachingPlannerProvider =
    StateNotifierProvider<TeachingPlannerNotifier, TeachingPlannerState>((ref) {
      return TeachingPlannerNotifier(
        ref.watch(teachingPlannerServiceProvider),
        ref.watch(teachingResourceAttachmentServiceProvider),
      );
    });

const Object _unset = Object();
