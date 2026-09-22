import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../premium/application/premium_controller.dart';
import '../../../premium/domain/freemium_policy.dart';
import '../../application/offline_sync_contract_service.dart';
import '../../application/teaching_planner_entitlement_adapter.dart';
import '../../application/teaching_planner_service.dart';
import '../../application/teaching_resource_attachment_service.dart';
import '../../data/local_teaching_planner_repository.dart';
import '../../data/teaching_resource_file_store.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/offline_sync_state.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/teaching_status.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/repositories/curriculum_merge_repository.dart';
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

final curriculumMergeStateProvider = FutureProvider<CurriculumMergeState>((
  ref,
) async {
  final repository = ref.watch(teachingPlannerRepositoryProvider);
  final mergeRepository = switch (repository) {
    CurriculumMergeRepository value => value,
    _ => null,
  };
  if (mergeRepository == null) return CurriculumMergeState.empty();
  return (await mergeRepository.loadCurriculumMergeSnapshot()).mergeState;
});

final teachingPlannerServiceProvider = Provider<TeachingPlannerService>((ref) {
  return TeachingPlannerService(ref.watch(teachingPlannerRepositoryProvider));
});

final offlineSyncContractServiceProvider = Provider<OfflineSyncContractService>(
  (ref) {
    return OfflineSyncContractService(
      ref.watch(teachingPlannerRepositoryProvider),
    );
  },
);

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
  TeachingPlannerNotifier(
    this._service,
    this._attachmentService, {
    bool Function()? hasPremiumAccess,
  }) : _hasPremiumAccess = hasPremiumAccess ?? _alwaysAllow,
       super(TeachingPlannerState()) {
    load();
  }

  final TeachingPlannerService _service;
  final TeachingResourceAttachmentService _attachmentService;
  final bool Function() _hasPremiumAccess;

  static bool _alwaysAllow() => true;

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
    if (!_canCreateClass()) return Future<bool>.value(false);
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

  Future<bool> moveSubject({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _run(
      () => _service.moveSubject(
        subjectId: subjectId,
        destinationClassId: destinationClassId,
      ),
    );
  }

  Future<bool> moveUnit({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _run(
      () => _service.moveUnit(
        unitId: unitId,
        destinationSubjectId: destinationSubjectId,
      ),
    );
  }

  Future<bool> moveChapter({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _run(
      () => _service.moveChapter(
        chapterId: chapterId,
        destinationSubjectId: destinationSubjectId,
        destinationUnitId: destinationUnitId,
      ),
    );
  }

  Future<bool> moveTopic({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _run(
      () => _service.moveTopic(
        topicId: topicId,
        destinationChapterId: destinationChapterId,
      ),
    );
  }

  Future<bool> duplicateSubjectStructure({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _run(
      () => _service.duplicateSubjectStructure(
        subjectId: subjectId,
        destinationClassId: destinationClassId,
      ),
    );
  }

  Future<bool> duplicateUnitStructure({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _run(
      () => _service.duplicateUnitStructure(
        unitId: unitId,
        destinationSubjectId: destinationSubjectId,
      ),
    );
  }

  Future<bool> duplicateChapterStructure({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _run(
      () => _service.duplicateChapterStructure(
        chapterId: chapterId,
        destinationSubjectId: destinationSubjectId,
        destinationUnitId: destinationUnitId,
      ),
    );
  }

  Future<bool> duplicateTopicStructure({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _run(
      () => _service.duplicateTopicStructure(
        topicId: topicId,
        destinationChapterId: destinationChapterId,
      ),
    );
  }

  Future<bool> importSyllabus(SyllabusImportPackage package) {
    if (!_canCreateClass()) return Future<bool>.value(false);
    return _run(() => _service.importSyllabus(package));
  }

  bool _canCreateClass() {
    if (_hasPremiumAccess() ||
        state.workspace.activeClasses.length <
            FreemiumPolicy.freeActiveClassLimit) {
      return true;
    }
    state = state.copyWith(
      errorMessage:
          'Free includes ${FreemiumPolicy.freeActiveClassLimit} active classes. Existing classes remain editable; Premium adds unlimited new classes.',
    );
    return false;
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


  Future<bool> trashClass(String classId) {
    return _run(() => _service.trashClass(classId));
  }

  Future<bool> trashSubject(String subjectId) {
    return _run(() => _service.trashSubject(subjectId));
  }

  Future<bool> trashUnit(String unitId) {
    return _run(() => _service.trashUnit(unitId));
  }

  Future<bool> trashChapter(String chapterId) {
    return _run(() => _service.trashChapter(chapterId));
  }

  Future<bool> trashTopic(String topicId) {
    return _run(() => _service.trashTopic(topicId));
  }

  Future<bool> restoreTrashedClass(String classId) {
    return _run(() => _service.restoreTrashedClass(classId));
  }

  Future<bool> restoreTrashedSubject(String subjectId) {
    return _run(() => _service.restoreTrashedSubject(subjectId));
  }

  Future<bool> restoreTrashedUnit(String unitId) {
    return _run(() => _service.restoreTrashedUnit(unitId));
  }

  Future<bool> restoreTrashedChapter(String chapterId) {
    return _run(() => _service.restoreTrashedChapter(chapterId));
  }

  Future<bool> restoreTrashedTopic(String topicId) {
    return _run(() => _service.restoreTrashedTopic(topicId));
  }

  Future<bool> restoreTrashedSubjectToClass({
    required String subjectId,
    required String destinationClassId,
  }) {
    return _run(
      () => _service.restoreTrashedSubjectToClass(
        subjectId: subjectId,
        destinationClassId: destinationClassId,
      ),
    );
  }

  Future<bool> restoreTrashedUnitToSubject({
    required String unitId,
    required String destinationSubjectId,
  }) {
    return _run(
      () => _service.restoreTrashedUnitToSubject(
        unitId: unitId,
        destinationSubjectId: destinationSubjectId,
      ),
    );
  }

  Future<bool> restoreTrashedChapterToLocation({
    required String chapterId,
    required String destinationSubjectId,
    String? destinationUnitId,
  }) {
    return _run(
      () => _service.restoreTrashedChapterToLocation(
        chapterId: chapterId,
        destinationSubjectId: destinationSubjectId,
        destinationUnitId: destinationUnitId,
      ),
    );
  }

  Future<bool> restoreTrashedTopicToChapter({
    required String topicId,
    required String destinationChapterId,
  }) {
    return _run(
      () => _service.restoreTrashedTopicToChapter(
        topicId: topicId,
        destinationChapterId: destinationChapterId,
      ),
    );
  }

  Future<bool> deleteClassPermanently(String classId) {
    return _run(() => _service.deleteClassPermanently(classId));
  }

  Future<bool> deleteSubjectPermanently(String subjectId) {
    return _run(() => _service.deleteSubjectPermanently(subjectId));
  }

  Future<bool> deleteUnitPermanently(String unitId) {
    return _run(() => _service.deleteUnitPermanently(unitId));
  }

  Future<bool> deleteChapterPermanently(String chapterId) {
    return _run(() => _service.deleteChapterPermanently(chapterId));
  }

  Future<bool> deleteTopicPermanently(String topicId) {
    return _run(() => _service.deleteTopicPermanently(topicId));
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
    TeachingProgressStatus? chapterStatus,
  }) {
    return _run(
      () => _service.recordLessonProgress(
        lessonPlanId,
        status: status,
        actualPeriods: actualPeriods,
        taughtAt: taughtAt,
        reflection: reflection,
        chapterStatus: chapterStatus,
      ),
    );
  }

  Future<bool> updateChapterProgress(
    String chapterId, {
    required TeachingProgressStatus status,
  }) {
    return _run(
      () => _service.updateChapterProgress(chapterId, status: status),
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
    String? linkedSmartDocumentId,
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
        linkedSmartDocumentId: linkedSmartDocumentId,
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

  Future<bool> attachLinkedTeachingFiles({
    required TeachingResourceOwner owner,
    required List<TeachingAttachmentCandidate> files,
    TeachingResourceRole role = TeachingResourceRole.teachInClass,
  }) {
    return _run(
      () => _attachmentService.attachLinkedFiles(
        owner: owner,
        files: files,
        role: role,
      ),
    );
  }

  Future<bool> replaceTeachingFileWithManagedCopy({
    required TeachingResource resource,
    required TeachingAttachmentCandidate file,
  }) {
    return _run(
      () => _attachmentService.replaceWithManagedCopy(
        resource: resource,
        file: file,
      ),
    );
  }

  Future<bool> relinkTeachingFile({
    required TeachingResource resource,
    required TeachingAttachmentCandidate file,
  }) {
    return _run(
      () => _attachmentService.relinkExternalFile(
        resource: resource,
        file: file,
      ),
    );
  }

  Future<bool> archiveTeachingResource(String resourceId) {
    return _run(() => _service.archiveTeachingResource(resourceId));
  }

  Future<bool> restoreWorkspace(TeachingPlannerWorkspace workspace) {
    return _run(() => _service.restoreWorkspace(workspace));
  }

  Future<bool> restoreWorkspaceWithMergeState(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
  ) {
    return _run(
      () => _service.restoreWorkspaceWithMergeState(workspace, mergeState),
    );
  }

  Future<bool> restoreWorkspaceWithSyncMetadata(
    TeachingPlannerWorkspace workspace,
    CurriculumMergeState mergeState,
    OfflineSyncState syncState,
  ) {
    return _run(
      () => _service.restoreWorkspaceWithSyncMetadata(
        workspace,
        mergeState,
        syncState,
      ),
    );
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
        hasPremiumAccess: () => ref.read(premiumProvider).hasPremiumAccess,
      );
    });

const Object _unset = Object();
