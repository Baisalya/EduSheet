import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../../eds_import/presentation/screens/eds_import_center_screen.dart';
import '../../../editor/domain/models/paper_model.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../../editor/presentation/screens/create_paper_screen.dart';
import 'package:edusheet/features/document_reader/presentation/providers/document_provider.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';

import '../../../guided_experience/application/guided_experience_providers.dart';
import '../../../guided_experience/domain/contextual_help.dart';
import '../../../guided_experience/domain/guide_ids.dart';
import '../../../guided_experience/domain/guide_progress.dart';
import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/contextual_help_prompt.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../../data/syllabus_import_codec.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_class.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../../domain/models/teaching_resource.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../models/syllabus_filter.dart';
import '../models/teaching_planner_smart_assistant.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../models/syllabus_node_ref.dart';
import '../providers/teaching_planner_provider.dart';
import '../services/syllabus_attachment_controller.dart';
import '../services/teaching_attachment_open_coordinator.dart';
import '../services/syllabus_manager_controller.dart';
import '../services/syllabus_navigation_policy.dart';
import 'curriculum_package_builder_screen.dart';
import 'teaching_attachment_image_preview_screen.dart';
import 'teaching_workspace_screen.dart';
import '../widgets/syllabus_adaptive_shell.dart';
import '../widgets/syllabus_hierarchy_cards.dart';
import '../widgets/syllabus_detail_panel.dart';
import '../widgets/syllabus_entity_sheet.dart';
import '../widgets/syllabus_outline.dart';
import '../widgets/saved_paper_picker_sheet.dart';
import '../widgets/syllabus_start_sheet.dart';
import '../widgets/teaching_planner_page_shell.dart';

class SyllabusManagerScreen extends ConsumerStatefulWidget {
  const SyllabusManagerScreen({
    super.key,
    this.initialClassId,
    this.guidedSetup = false,
  });

  final String? initialClassId;
  final bool guidedSetup;

  @override
  ConsumerState<SyllabusManagerScreen> createState() =>
      _SyllabusManagerScreenState();
}

class _SyllabusManagerScreenState extends ConsumerState<SyllabusManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  SyllabusNodeRef? _selected;
  String _query = '';
  SyllabusFilter _filter = SyllabusFilter.all;
  bool _guideReconcileScheduled = false;

  @override
  void initState() {
    super.initState();
    final classId = widget.initialClassId;
    if (classId != null) {
      _selected = SyllabusNodeRef.classValue(classId);
    }
  }

  bool get _canReorder =>
      _query.trim().isEmpty && _filter == SyllabusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final guidedExperience = ref.watch(guidedExperienceControllerProvider);
    final workspace = state.workspace;
    final selected = SyllabusNavigationPolicy.validatedSelection(
      workspace,
      _selected,
    );
    if (guidedExperience.activeSession?.guideId == GuideId.createSyllabus) {
      _scheduleSyllabusGuideReconciliation();
    }

    final smartRecommendation = widget.guidedSetup || !_canReorder
        ? null
        : const TeachingPlannerSmartAssistantService().recommendForSyllabus(
            workspace: workspace,
            selected: selected,
          );

    final pageBody = SafeArea(
      child: Column(
        children: [
          _SyllabusReferenceHeader(
            selected: selected,
            guidedSetup: widget.guidedSetup,
            isLoading: state.isLoading,
            onBack: widget.guidedSetup
                ? () => Navigator.of(context).maybePop()
                : null,
            onCreateSyllabus: _createSyllabus,
            onImportSyllabus: _importSyllabus,
            onShareCurriculum: () => _openCurriculumPackageBuilder(selected),
            trashCount: _managerController.trashEntries().length,
            onOpenTrash: _openTrash,
            onShowGuide: _showSyllabusGuide,
            onRefresh: () => ref.read(teachingPlannerProvider.notifier).load(),
          ),
          if (widget.guidedSetup)
            _GuidedSyllabusSetupBanner(
              workspace: workspace,
              classId: widget.initialClassId,
              onContinue: _continueGuidedSetup,
            ),
          SyllabusAdaptiveToolbar(
            filter: _filter,
            searchController: _searchController,
            onQueryChanged: (value) => setState(() => _query = value),
            onFilterChanged: (value) => setState(() => _filter = value),
            onCreateSyllabus: _createSyllabus,
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Semantics(
                liveRegion: true,
                child: MaterialBanner(
                  content: Text(state.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.read(teachingPlannerProvider.notifier).load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useWideEditor =
                    constraints.maxWidth >=
                        TeachingPlannerBreakpoints.syllabusWide &&
                    constraints.maxHeight >= 500;
                if (useWideEditor) {
                  return _buildWideEditor(workspace, selected);
                }
                final hasActiveSearch =
                    _query.trim().isNotEmpty || _filter != SyllabusFilter.all;
                return PopScope<Object?>(
                  canPop: selected == null && !hasActiveSearch,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    if (hasActiveSearch) {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _filter = SyllabusFilter.all;
                      });
                      return;
                    }
                    if (selected == null) return;
                    setState(
                      () => _selected = SyllabusNavigationPolicy.parentOf(
                        workspace,
                        selected,
                      ),
                    );
                  },
                  child: _buildCompactEditor(workspace, selected),
                );
              },
            ),
          ),
        ],
      ),
    );

    final assistantBody = smartRecommendation == null
        ? pageBody
        : ContextualHelpOffer(
            suggestion: smartRecommendation.suggestion,
            signals: ContextualHelpSignals(
              currentScreen: GuidedScreenContext.syllabus,
              hasIncompleteAction:
                  smartRecommendation.suggestion.requiresIncompleteAction,
              hasActiveGuide: guidedExperience.activeSession != null,
            ),
            onShowMe: () => _runSmartAssistantAction(smartRecommendation),
            child: pageBody,
          );

    return TeachingPlannerPageShell(
      title: 'Syllabus',
      showAppBar: false,
      currentDestination: TeachingPlannerDestination.syllabus,
      showGlobalNavigation: !widget.guidedSetup,
      body: assistantBody,
    );
  }

  Widget _buildWideEditor(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef? selected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: SyllabusOutline(
              workspace: workspace,
              selected: selected,
              query: _query,
              filter: _filter,
              onSelected: _select,
              onCreateSyllabus: _createSyllabus,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: selected == null
                ? SyllabusSelectionPlaceholder(
                    onCreateSyllabus: _createSyllabus,
                  )
                : _detailPanel(workspace, selected),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEditor(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef? selected,
  ) {
    final searching = _query.trim().isNotEmpty || _filter != SyllabusFilter.all;
    if (searching) {
      return SyllabusSearchResults(
        workspace: workspace,
        query: _query,
        filter: _filter,
        onSelected: _selectFromSearch,
      );
    }

    if (selected == null) {
      return SyllabusClassBrowser(
        workspace: workspace,
        onSelected: _select,
        onCreateSyllabus: _createSyllabus,
        onImportSyllabus: _importSyllabus,
        actionsForNode: (node) {
          final mergeState =
              ref.read(curriculumMergeStateProvider).asData?.value ??
              CurriculumMergeState.empty();
          if (mergeState.isOfficialLocalId('class', node.id)) {
            return const <SyllabusCardAction>[];
          }
          return [
            SyllabusCardAction(
              id: 'edit',
              label: 'Edit',
              icon: Icons.edit_outlined,
              onSelected: () => _editNode(node),
            ),
            SyllabusCardAction(
              id: 'archive',
              label: 'Archive',
              icon: Icons.archive_outlined,
              onSelected: () => _archiveNode(node),
            ),
            SyllabusCardAction(
              id: 'trash',
              label: 'Move to Trash',
              icon: Icons.delete_outline_rounded,
              onSelected: () => _trashNode(node),
            ),
          ];
        },
      );
    }

    return Column(
      children: [
        SyllabusBreadcrumb(
          workspace: workspace,
          selected: selected,
          onSelected: _select,
          onHome: () => setState(() => _selected = null),
        ),
        const Divider(height: 1),
        Expanded(child: _detailPanel(workspace, selected)),
      ],
    );
  }

  Widget _detailPanel(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef selected,
  ) {
    final mergeState =
        ref.watch(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    return GuideAnchor(
      targetId: CreateSyllabusGuideTargets.manageSyllabus,
      child: SyllabusDetailPanel(
        workspace: workspace,
        mergeState: mergeState,
        selected: selected,
        query: _query,
        filter: _filter,
        reorderEnabled: _canReorder,
        onSelected: _select,
        onEdit: _editNode,
        onArchive: _archiveNode,
        onMove: _moveNode,
        onDuplicate: _duplicateNode,
        onDelete: _trashNode,
        onCreatePaper: _createPaperForNode,
        onAttachSavedPaper: _attachSavedPaper,
        onAddAttachments: _addAttachments,
        onLinkAttachments: Platform.isWindows ? _linkAttachments : null,
        onOpenAttachment: _openResource,
        onRemoveAttachment: _removeResource,
        onCreateSubject: _createSubject,
        onCreateUnit: _createUnit,
        onCreateChapter: _createChapter,
        onCreateTopic: _createTopic,
        onPlanChapterLesson: _planChapterLesson,
        onToggleChapterComplete: _toggleChapterComplete,
        onReorderSubjects: (classId, ids) => _reorderSubjects(classId, ids),
        onReorderUnits: (subjectId, ids) => _reorderUnits(subjectId, ids),
        onReorderChapters: (subjectId, unitId, ids) =>
            _reorderChapters(subjectId, unitId, ids),
        onReorderTopics: (chapterId, ids) => _reorderTopics(chapterId, ids),
      ),
    );
  }

  SyllabusManagerController get _managerController {
    final notifier = ref.read(teachingPlannerProvider.notifier);
    return SyllabusManagerController(
      notifier: notifier,
      readWorkspace: () => ref.read(teachingPlannerProvider).workspace,
    );
  }

  SyllabusAttachmentController get _attachmentController {
    final notifier = ref.read(teachingPlannerProvider.notifier);
    return SyllabusAttachmentController(
      picker: ref.read(teachingResourceFilePickerProvider),
      openCoordinator: TeachingAttachmentOpenCoordinator(
        fileStore: ref.read(teachingResourceFileStoreProvider),
        documentRepository: ref.read(documentRepositoryProvider),
      ),
      attachFiles: ({required owner, required files}) =>
          notifier.attachTeachingFiles(owner: owner, files: files),
      attachLinkedFiles: ({required owner, required files}) =>
          notifier.attachLinkedTeachingFiles(owner: owner, files: files),
      archiveResource: notifier.archiveTeachingResource,
      replaceManagedResource: ({required resource, required file}) =>
          notifier.replaceTeachingFileWithManagedCopy(
            resource: resource,
            file: file,
          ),
      relinkResource: ({required resource, required file}) =>
          notifier.relinkTeachingFile(resource: resource, file: file),
    );
  }

  Future<void> _planChapterLesson(SyllabusNodeRef node) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    final chapterId = node.chapterId ?? node.id;
    final chapter = workspace.chapterById(chapterId);
    final subject = chapter == null
        ? null
        : workspace.subjectById(chapter.subjectId);
    if (chapter == null || subject == null || chapter.isArchived) {
      _showMessage('This chapter is no longer available.');
      return;
    }
    await TeachingPlannerNavigation.openLessons(
      context,
      createImmediately: true,
      initialClassId: subject.classId,
      initialSubjectId: subject.id,
      initialChapterId: chapter.id,
    );
  }

  Future<void> _toggleChapterComplete(PlannerChapter chapter) async {
    final target = chapter.status == TeachingProgressStatus.completed
        ? TeachingProgressStatus.inProgress
        : TeachingProgressStatus.completed;
    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .updateChapterProgress(chapter.id, status: target);
    if (!mounted) return;
    if (!saved) {
      _showError();
      return;
    }
    _showMessage(
      target == TeachingProgressStatus.completed
          ? '${chapter.title} marked complete.'
          : '${chapter.title} reopened and kept in progress.',
    );
  }

  Future<void> _createPaperForNode(SyllabusNodeRef node) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    final paperContext = _paperContextForNode(workspace, node);
    if (paperContext == null) {
      _showMessage('This syllabus item is no longer available.');
      return;
    }

    final editor = ref.read(editorStateProvider.notifier);
    final paperId = await editor.startNewPaperForSyllabus(
      className: paperContext.className,
      subjectName: paperContext.subjectName,
    );
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const CreatePaperScreen()));
    if (!mounted) return;

    await editor.flushPendingAutosave();
    if (!editor.isPaperPersisted(paperId)) {
      _showMessage(
        'Paper was not saved, so nothing was added to the syllabus.',
      );
      return;
    }

    final savedPapers = await ref.read(paperRepositoryProvider).getAllPapers();
    Paper? savedPaper;
    for (final paper in savedPapers) {
      if (paper.id == paperId) {
        savedPaper = paper;
        break;
      }
    }
    if (savedPaper == null) {
      _showMessage('The saved paper could not be found. Nothing was linked.');
      return;
    }
    await _linkPaper(node, savedPaper);
  }

  Future<void> _attachSavedPaper(SyllabusNodeRef node) async {
    List<Paper> allPapers;
    try {
      allPapers = await ref.read(paperRepositoryProvider).getAllPapers();
    } catch (_) {
      if (mounted) _showMessage('Saved papers could not be loaded.');
      return;
    }
    if (!mounted) return;
    final owner = SyllabusAttachmentController.ownerForNode(node);
    final linkedPaperIds = ref
        .read(teachingPlannerProvider)
        .workspace
        .activeResourcesForOwner(owner)
        .where((item) => item.kind == TeachingResourceKind.paper)
        .map((item) => item.linkedPaperId)
        .whereType<String>()
        .toSet();
    final papers = allPapers
        .where((paper) => !linkedPaperIds.contains(paper.id))
        .toList(growable: false);
    if (allPapers.isNotEmpty && papers.isEmpty) {
      _showMessage('All saved papers are already linked here.');
      return;
    }
    final selectedPaper = await SavedPaperPickerSheet.show(
      context,
      papers: papers,
    );
    if (selectedPaper == null || !mounted) return;
    await _linkPaper(node, selectedPaper);
  }

  Future<void> _linkPaper(SyllabusNodeRef node, Paper paper) async {
    final notifier = ref.read(teachingPlannerProvider.notifier);
    final saved = await notifier.createTeachingResource(
      owner: SyllabusAttachmentController.ownerForNode(node),
      kind: TeachingResourceKind.paper,
      role: TeachingResourceRole.reference,
      title: paper.title.trim().isEmpty ? 'Untitled Paper' : paper.title.trim(),
      linkedPaperId: paper.id,
    );
    if (!mounted) return;
    if (saved) {
      _showMessage('Paper added to this syllabus.');
      return;
    }
    _showMessage(
      ref.read(teachingPlannerProvider).errorMessage ??
          'The paper could not be added to this syllabus.',
    );
  }

  Future<void> _openResource(TeachingResource resource) async {
    if (resource.kind == TeachingResourceKind.paper) {
      await _openLinkedPaper(resource);
      return;
    }
    await _openAttachment(resource);
  }

  Future<void> _openLinkedPaper(TeachingResource resource) async {
    final paperId = resource.linkedPaperId;
    if (paperId == null || paperId.trim().isEmpty) {
      _showMessage('This syllabus paper link is incomplete.');
      return;
    }
    List<Paper> papers;
    try {
      papers = await ref.read(paperRepositoryProvider).getAllPapers();
    } catch (_) {
      if (mounted) _showMessage('Saved papers could not be loaded.');
      return;
    }
    Paper? paper;
    for (final candidate in papers) {
      if (candidate.id == paperId) {
        paper = candidate;
        break;
      }
    }
    if (!mounted) return;
    if (paper == null) {
      _showMessage(
        'This linked paper is not in Saved Papers on this device. The syllabus link is still kept.',
      );
      return;
    }

    final mergeState = await ref.read(curriculumMergeStateProvider.future);
    if (!mounted) return;
    if (mergeState.isOfficialLocalId('paper', paper.id)) {
      final createCopy = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: const Text('Official paper is protected'),
          content: const Text(
            'This paper came from the official curriculum. Create a teacher copy to edit it; the official version will stay unchanged and can still receive future updates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep official'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Create teacher copy'),
            ),
          ],
        ),
      );
      if (createCopy != true || !mounted) return;
      await _openTeacherPaperCopy(resource, paper);
      return;
    }

    ref.read(editorStateProvider.notifier).loadPaper(paper);
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const CreatePaperScreen()));
    if (!mounted) return;

    List<Paper> refreshedPapers;
    try {
      refreshedPapers = await ref.read(paperRepositoryProvider).getAllPapers();
    } catch (_) {
      return;
    }
    Paper? refreshed;
    for (final candidate in refreshedPapers) {
      if (candidate.id == paperId) {
        refreshed = candidate;
        break;
      }
    }
    final refreshedTitle = refreshed?.title.trim();
    if (refreshedTitle != null &&
        refreshedTitle.isNotEmpty &&
        refreshedTitle != resource.title) {
      await ref
          .read(teachingPlannerProvider.notifier)
          .updateTeachingResource(
            resource.id,
            role: resource.role,
            title: refreshedTitle,
          );
    }
  }

  Future<void> _openTeacherPaperCopy(
    TeachingResource officialResource,
    Paper officialPaper,
  ) async {
    final now = DateTime.now().toUtc();
    final copyId = const Uuid().v4();
    final linkId = const Uuid().v4();
    final teacherCopy = officialPaper.copyWith(
      id: copyId,
      originId: copyId,
      revision: 1,
      updatedAt: now,
      createdAt: now,
      title: '${officialPaper.title} — Teacher Copy',
    );

    try {
      await ref.read(paperRepositoryProvider).savePaper(teacherCopy);
    } catch (_) {
      if (mounted) {
        _showMessage('The teacher copy could not be created safely.');
      }
      return;
    }
    if (!mounted) return;

    final linked = await ref
        .read(teachingPlannerProvider.notifier)
        .createTeachingResource(
          resourceId: linkId,
          owner: officialResource.owner,
          kind: TeachingResourceKind.paper,
          role: officialResource.role,
          title: teacherCopy.title,
          linkedPaperId: teacherCopy.id,
        );
    if (!linked) {
      try {
        await ref.read(paperRepositoryProvider).deletePaper(copyId);
      } catch (_) {
        // Best-effort cleanup. Never alter the protected official paper.
      }
      if (mounted) {
        _showMessage(
          ref.read(teachingPlannerProvider).errorMessage ??
              'The teacher copy could not be linked safely.',
        );
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(savedPapersProvider);
    ref.read(editorStateProvider.notifier).loadPaper(teacherCopy);
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const CreatePaperScreen()));
    if (!mounted) return;

    try {
      final refreshedPapers = await ref
          .read(paperRepositoryProvider)
          .getAllPapers();
      Paper? refreshed;
      for (final candidate in refreshedPapers) {
        if (candidate.id == copyId) {
          refreshed = candidate;
          break;
        }
      }
      final title = refreshed?.title.trim();
      if (title != null && title.isNotEmpty && title != teacherCopy.title) {
        await ref
            .read(teachingPlannerProvider.notifier)
            .updateTeachingResource(
              linkId,
              role: officialResource.role,
              title: title,
            );
      }
    } catch (_) {
      // The editable copy is already safe. A display-title refresh failure
      // must not imply that the copy or official paper was lost.
    }
  }

  Future<void> _removeResource(TeachingResource resource) async {
    final isPaper = resource.kind == TeachingResourceKind.paper;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPaper ? 'Remove paper from syllabus?' : 'Remove file?'),
        content: Text(
          isPaper
              ? 'This only removes the syllabus link. The original paper stays safely in Saved Papers.'
              : '${resource.originalFileName ?? resource.title} will disappear from this syllabus. EduSheet keeps archived resource data safely for recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .archiveTeachingResource(resource.id);
    if (!mounted) return;
    _showMessage(
      saved
          ? (isPaper
                ? 'Paper removed from this syllabus. Saved Papers is unchanged.'
                : 'File removed from syllabus.')
          : (ref.read(teachingPlannerProvider).errorMessage ??
                'The item could not be removed from this syllabus.'),
    );
  }

  _SyllabusPaperContext? _paperContextForNode(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef node,
  ) {
    final plannerClass = workspace.classById(node.classId);
    if (plannerClass == null || plannerClass.isArchived) return null;
    PlannerSubject? subject;
    final subjectId = node.subjectId;
    if (subjectId != null) {
      final candidate = workspace.subjectById(subjectId);
      if (candidate == null || candidate.isArchived) return null;
      subject = candidate;
    }
    return _SyllabusPaperContext(
      className: plannerClass.name,
      subjectName: subject?.name,
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addAttachments(SyllabusNodeRef node) async {
    final result = await _attachmentController.addFiles(node);
    if (!mounted || result.cancelled) return;
    _showAttachmentResult(result);
  }

  Future<void> _linkAttachments(SyllabusNodeRef node) async {
    final result = await _attachmentController.linkFiles(node);
    if (!mounted || result.cancelled) return;
    _showAttachmentResult(result);
  }

  Future<void> _openAttachment(TeachingResource resource) async {
    final result = await _attachmentController.resolveOpen(resource);
    if (!mounted) return;
    switch (result.kind) {
      case TeachingAttachmentOpenKind.document:
        final document = result.document;
        if (document == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => FilePreviewScreen(document: document),
          ),
        );
        return;
      case TeachingAttachmentOpenKind.image:
        final file = result.file;
        if (file == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TeachingAttachmentImagePreviewScreen(
              file: file,
              title: resource.originalFileName ?? resource.title,
            ),
          ),
        );
        return;
      case TeachingAttachmentOpenKind.eds:
        final file = result.file;
        if (file == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => EdsImportCenterScreen(
              initialFilePath: file.path,
              initialDisplayName: resource.originalFileName ?? resource.title,
            ),
          ),
        );
        return;
      case TeachingAttachmentOpenKind.edtp:
        final file = result.file;
        if (file == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TeachingWorkspaceScreen(
              initialTeachingPackPath: file.path,
            ),
          ),
        );
        return;
      case TeachingAttachmentOpenKind.external:
        final file = result.file;
        if (file == null) return;
        final external = await OpenFilex.open(file.path);
        if (!mounted || external.type == ResultType.done) return;
        _showMessage(
          external.message.isEmpty
              ? 'No compatible app was found for this file.'
              : external.message,
        );
        return;
      case TeachingAttachmentOpenKind.missing:
        await _showMissingAttachmentRecovery(
          resource,
          result.message ?? 'This attachment is missing.',
        );
        return;
      case TeachingAttachmentOpenKind.invalid:
        _showMessage(result.message ?? 'This attachment could not be opened.');
        return;
    }
  }

  Future<void> _showMissingAttachmentRecovery(
    TeachingResource resource,
    String message,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attachment not found'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'locate'),
            child: const Text('Locate'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeResource(resource);
      return;
    }
    final result = action == 'locate'
        ? await _attachmentController.locate(resource)
        : await _attachmentController.replace(resource);
    if (!mounted || result.cancelled) return;
    _showAttachmentResult(result);
  }

  void _showAttachmentResult(SyllabusAttachmentActionResult result) {
    final message = result.message;
    if (message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(SyllabusNodeRef node) {
    setState(() => _selected = node);
  }

  void _selectFromSearch(SyllabusNodeRef node) {
    _searchController.clear();
    setState(() {
      _selected = node;
      _query = '';
      _filter = SyllabusFilter.all;
    });
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    _query = '';
    _filter = SyllabusFilter.all;
  }

  void _runSmartAssistantAction(
    TeachingPlannerSmartAssistantRecommendation recommendation,
  ) {
    switch (recommendation.action) {
      case TeachingPlannerSmartAssistantAction.createSyllabus:
        unawaited(_createSyllabus());
        return;
      case TeachingPlannerSmartAssistantAction.createSubject:
        final classId = recommendation.classId;
        if (classId != null) unawaited(_createSubject(classId));
        return;
      case TeachingPlannerSmartAssistantAction.createChapter:
        final subjectId = recommendation.subjectId;
        if (subjectId != null) {
          unawaited(_createChapter(subjectId, recommendation.unitId));
        }
        return;
      case TeachingPlannerSmartAssistantAction.planChapterLesson:
        final classId = recommendation.classId;
        final subjectId = recommendation.subjectId;
        final chapterId = recommendation.chapterId;
        if (classId == null || subjectId == null || chapterId == null) return;
        unawaited(
          TeachingPlannerNavigation.openLessons(
            context,
            createImmediately: true,
            initialClassId: classId,
            initialSubjectId: subjectId,
            initialChapterId: chapterId,
          ),
        );
        return;
      case TeachingPlannerSmartAssistantAction.addChapterMaterial:
        final classId = recommendation.classId;
        final subjectId = recommendation.subjectId;
        final chapterId = recommendation.chapterId;
        if (classId == null || subjectId == null || chapterId == null) return;
        unawaited(
          _addAttachments(
            SyllabusNodeRef.chapter(
              classId: classId,
              subjectId: subjectId,
              unitId: recommendation.unitId,
              chapterId: chapterId,
            ),
          ),
        );
        return;
    }
  }

  void _showSyllabusGuide() {
    final guideState = ref.read(guidedExperienceControllerProvider);
    final progress = guideState.progressFor(createSyllabusGuideDefinition.id);
    final controller = ref.read(guidedExperienceControllerProvider.notifier);
    if (progress?.status == GuideProgressStatus.completed) {
      unawaited(
        controller.replayGuide(
          createSyllabusGuideDefinition,
          startAtStepId: CreateSyllabusGuideSteps.openCreateSyllabus,
        ),
      );
      return;
    }
    unawaited(
      controller.startGuide(
        createSyllabusGuideDefinition,
        restart: true,
        startAtStepId: CreateSyllabusGuideSteps.openCreateSyllabus,
      ),
    );
  }

  void _scheduleSyllabusGuideReconciliation() {
    if (_guideReconcileScheduled) return;
    _guideReconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guideReconcileScheduled = false;
      if (!mounted) return;
      final workspace = ref.read(teachingPlannerProvider).workspace;
      final selected = SyllabusNavigationPolicy.validatedSelection(
        workspace,
        _selected,
      );
      _reconcileSyllabusGuide(workspace, selected);
    });
  }

  void _reconcileSyllabusGuide(
    TeachingPlannerWorkspace workspace,
    SyllabusNodeRef? selected,
  ) {
    final guide = ref.read(guidedExperienceControllerProvider);
    if (guide.activeSession?.guideId != GuideId.createSyllabus) return;
    final stepId = guide.activeStep?.id;
    final controller = ref.read(guidedExperienceControllerProvider.notifier);

    String? classId = selected?.classId ?? widget.initialClassId;
    final activeClasses = workspace.activeClasses;
    classId ??= activeClasses.isEmpty ? null : activeClasses.first.id;

    if (stepId == CreateSyllabusGuideSteps.openCreateSyllabus) {
      if (classId == null) return;
      if (selected == null || selected.kind != SyllabusNodeKind.classValue) {
        setState(() => _selected = SyllabusNodeRef.classValue(classId!));
      }
      unawaited(controller.advance());
      return;
    }

    if (stepId == CreateSyllabusGuideSteps.saveCreateSyllabus) {
      if (classId == null) return;
      if (selected == null || selected.kind != SyllabusNodeKind.classValue) {
        setState(() => _selected = SyllabusNodeRef.classValue(classId!));
      }
      unawaited(
        controller.notifyConditionSatisfied(
          CreateSyllabusGuideSteps.saveCreateSyllabus,
        ),
      );
      return;
    }

    if (stepId == CreateSyllabusGuideSteps.openSubject ||
        stepId == CreateSyllabusGuideSteps.saveSubject) {
      if (classId == null) return;
      final subjects = workspace.activeSubjectsForClass(classId);
      if (subjects.isEmpty) {
        if (selected?.kind != SyllabusNodeKind.classValue ||
            selected?.id != classId) {
          setState(() => _selected = SyllabusNodeRef.classValue(classId!));
        }
        return;
      }

      final subject = subjects.first;
      if (stepId == CreateSyllabusGuideSteps.openSubject) {
        unawaited(controller.advance());
        return;
      }

      if (selected?.id != subject.id) {
        setState(
          () => _selected = SyllabusNodeRef.subject(
            classId: classId!,
            subjectId: subject.id,
          ),
        );
      }
      unawaited(
        controller.notifyConditionSatisfied(
          CreateSyllabusGuideSteps.saveSubject,
        ),
      );
      return;
    }

    if (stepId == CreateSyllabusGuideSteps.openChapter ||
        stepId == CreateSyllabusGuideSteps.saveChapter ||
        stepId == CreateSyllabusGuideSteps.optionalStructure) {
      if (classId == null) return;
      final subjects = workspace.activeSubjectsForClass(classId);
      if (subjects.isEmpty) return;
      final subject = subjects.first;
      final chapters = workspace.chapters
          .where((item) => !item.isArchived && item.subjectId == subject.id)
          .toList(growable: false);

      if (chapters.isEmpty) {
        if (selected?.id != subject.id) {
          setState(
            () => _selected = SyllabusNodeRef.subject(
              classId: classId!,
              subjectId: subject.id,
            ),
          );
        }
        return;
      }

      if (stepId == CreateSyllabusGuideSteps.openChapter) {
        unawaited(controller.advance());
        return;
      }

      final chapter = chapters.first;
      if (selected?.id != chapter.id) {
        setState(
          () => _selected = SyllabusNodeRef.chapter(
            classId: classId!,
            subjectId: subject.id,
            unitId: chapter.unitId,
            chapterId: chapter.id,
          ),
        );
      }
      if (stepId == CreateSyllabusGuideSteps.saveChapter) {
        unawaited(
          controller.notifyConditionSatisfied(
            CreateSyllabusGuideSteps.saveChapter,
          ),
        );
      }
      return;
    }

    if (stepId == CreateSyllabusGuideSteps.finishSetup && !widget.guidedSetup) {
      unawaited(
        controller.notifyConditionSatisfied(
          CreateSyllabusGuideSteps.finishSetup,
        ),
      );
    }
  }

  Future<void> _continueGuidedSetup() async {
    await ref
        .read(guidedExperienceControllerProvider.notifier)
        .notifyConditionSatisfied(CreateSyllabusGuideSteps.finishSetup);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createSyllabus() async {
    final draft = await showAdaptiveModalBottomSheet<SyllabusStartDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      maximumSheetWidth: 620,
      builder: (_) => const SyllabusStartSheet(),
    );
    if (draft == null || !mounted) return;

    final outcome = await _managerController.createClass(
      name: draft.name,
      academicYear: draft.academicYear,
    );
    _applyMutationOutcome(
      outcome,
      completedGuideStep: CreateSyllabusGuideSteps.saveCreateSyllabus,
    );
  }

  Future<void> _createSubject(String classId) async {
    final draft = await _showEditor(
      const SyllabusEntitySheet(requestedKind: SyllabusEntityKind.subject),
    );
    if (draft == null || !mounted) return;
    final outcome = await _managerController.createSubject(
      classId: classId,
      name: draft.name,
      code: draft.code,
    );
    _applyMutationOutcome(
      outcome,
      completedGuideStep: CreateSyllabusGuideSteps.saveSubject,
    );
  }

  Future<void> _createUnit(String subjectId) async {
    final draft = await _showEditor(
      const SyllabusEntitySheet(requestedKind: SyllabusEntityKind.unit),
    );
    if (draft == null || !mounted) return;
    final outcome = await _managerController.createUnit(
      subjectId: subjectId,
      title: draft.name,
      plannedPeriods: draft.plannedPeriods,
      priority: draft.priority,
    );
    _applyMutationOutcome(outcome);
  }

  Future<void> _createChapter(String subjectId, String? unitId) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    if (workspace.subjectById(subjectId) == null) return;
    final draft = await _showEditor(
      SyllabusEntitySheet(
        requestedKind: SyllabusEntityKind.chapter,
        subjectId: subjectId,
        unitId: unitId,
        units: workspace.activeUnitsForSubject(subjectId),
      ),
    );
    if (draft == null || !mounted) return;
    final outcome = await _managerController.createChapter(
      subjectId: subjectId,
      unitId: draft.unitId,
      title: draft.name,
      plannedPeriods: draft.plannedPeriods,
      priority: draft.priority,
    );
    _applyMutationOutcome(
      outcome,
      completedGuideStep: CreateSyllabusGuideSteps.saveChapter,
    );
  }

  Future<void> _createTopic(String chapterId) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    if (workspace.chapterById(chapterId) == null) return;
    final draft = await _showEditor(
      const SyllabusEntitySheet(requestedKind: SyllabusEntityKind.topic),
    );
    if (draft == null || !mounted) return;
    final outcome = await _managerController.createTopic(
      chapterId: chapterId,
      title: draft.name,
      plannedPeriods: draft.plannedPeriods,
      priority: draft.priority,
    );
    _applyMutationOutcome(outcome);
    if (outcome.success &&
        ref.read(guidedExperienceControllerProvider).activeStep?.id ==
            CreateSyllabusGuideSteps.optionalStructure) {
      unawaited(
        ref.read(guidedExperienceControllerProvider.notifier).advance(),
      );
    }
  }

  void _applyMutationOutcome(
    SyllabusMutationOutcome outcome, {
    GuideStepId? completedGuideStep,
  }) {
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    final selection = outcome.selection;
    if (selection != null) {
      setState(() {
        _clearSearchAndFilters();
        _selected = selection;
      });
    }
    if (completedGuideStep != null) {
      unawaited(
        ref
            .read(guidedExperienceControllerProvider.notifier)
            .notifyConditionSatisfied(completedGuideStep),
      );
    }
  }

  Future<void> _editNode(SyllabusNodeRef node) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        final value = workspace.classById(node.id);
        if (value == null) return;
        await _editClass(value);
        return;
      case SyllabusNodeKind.subject:
        final value = workspace.subjectById(node.id);
        if (value == null) return;
        await _editSubject(value);
        return;
      case SyllabusNodeKind.unit:
        final value = workspace.unitById(node.id);
        if (value == null) return;
        await _editUnit(value);
        return;
      case SyllabusNodeKind.chapter:
        final value = workspace.chapterById(node.id);
        if (value == null) return;
        await _editChapter(value);
        return;
      case SyllabusNodeKind.topic:
        final value = workspace.topicById(node.id);
        if (value == null) return;
        await _editTopic(value);
        return;
    }
  }

  Future<void> _editClass(PlannerClass value) async {
    final draft = await _showEditor(SyllabusEntitySheet(classValue: value));
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateClass(
          value.id,
          name: draft.name,
          academicYear: draft.academicYear,
        );
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _editSubject(PlannerSubject value) async {
    final draft = await _showEditor(SyllabusEntitySheet(subjectValue: value));
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateSubject(value.id, name: draft.name, code: draft.code);
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _editUnit(PlannerUnit value) async {
    final draft = await _showEditor(SyllabusEntitySheet(unitValue: value));
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateUnit(
          value.id,
          title: draft.name,
          plannedPeriods: draft.plannedPeriods,
          priority: draft.priority,
        );
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _editChapter(PlannerChapter value) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    final draft = await _showEditor(
      SyllabusEntitySheet(
        chapterValue: value,
        subjectId: value.subjectId,
        unitId: value.unitId,
        units: workspace.activeUnitsForSubject(value.subjectId),
      ),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateChapter(
          value.id,
          title: draft.name,
          plannedPeriods: draft.plannedPeriods,
          priority: draft.priority,
          unitId: draft.unitId,
        );
    if (!mounted) return;
    if (!ok) {
      _showError();
      return;
    }
    final updated = ref
        .read(teachingPlannerProvider)
        .workspace
        .chapterById(value.id);
    if (updated != null && _selected?.id == value.id) {
      setState(() {
        _selected = SyllabusNodeRef.chapter(
          classId: _selected!.classId,
          subjectId: value.subjectId,
          unitId: updated.unitId,
          chapterId: value.id,
        );
      });
    }
  }

  Future<void> _editTopic(PlannerTopic value) async {
    final draft = await _showEditor(SyllabusEntitySheet(topicValue: value));
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateTopic(
          value.id,
          title: draft.name,
          plannedPeriods: draft.plannedPeriods,
          priority: draft.priority,
        );
    if (!mounted || ok) return;
    _showError();
  }

  Future<SyllabusEntityDraft?> _showEditor(SyllabusEntitySheet sheet) {
    return showAdaptiveModalBottomSheet<SyllabusEntityDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      maximumSheetWidth: 720,
      builder: (_) => sheet,
    );
  }


  Future<void> _moveNode(SyllabusNodeRef node) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    late SyllabusMutationOutcome outcome;
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        return;
      case SyllabusNodeKind.subject:
        final subject = workspace.subjectById(node.id);
        if (subject == null) return;
        final classId = await _chooseClassDestination(
          workspace,
          title: 'Move ${subject.name}',
          helper: 'Choose the class that should own this subject.',
          selectedId: subject.classId,
          excludeSelected: true,
        );
        if (classId == null || !mounted) return;
        outcome = await _managerController.moveSubject(
          subjectId: subject.id,
          destinationClassId: classId,
        );
        break;
      case SyllabusNodeKind.unit:
        final unit = workspace.unitById(node.id);
        if (unit == null) return;
        final subjectId = await _chooseSubjectDestination(
          workspace,
          title: 'Move ${unit.title}',
          helper: 'Choose the subject that should own this unit.',
          selectedId: unit.subjectId,
          excludeSelected: true,
        );
        if (subjectId == null || !mounted) return;
        outcome = await _managerController.moveUnit(
          unitId: unit.id,
          destinationSubjectId: subjectId,
        );
        break;
      case SyllabusNodeKind.chapter:
        final chapter = workspace.chapterById(node.id);
        if (chapter == null) return;
        final destination = await _chooseChapterDestination(
          workspace,
          title: 'Move ${chapter.title}',
          initialSubjectId: chapter.subjectId,
          initialUnitId: chapter.unitId,
          actionLabel: 'Move',
        );
        if (destination == null || !mounted) return;
        if (destination.subjectId == chapter.subjectId &&
            destination.unitId == chapter.unitId) {
          _showMessage('Choose a different chapter location.');
          return;
        }
        outcome = await _managerController.moveChapter(
          chapterId: chapter.id,
          destinationSubjectId: destination.subjectId,
          destinationUnitId: destination.unitId,
        );
        break;
      case SyllabusNodeKind.topic:
        final topic = workspace.topicById(node.id);
        if (topic == null) return;
        final chapterId = await _chooseChapterForTopic(
          workspace,
          title: 'Move ${topic.title}',
          selectedId: topic.chapterId,
          excludeSelected: true,
        );
        if (chapterId == null || !mounted) return;
        outcome = await _managerController.moveTopic(
          topicId: topic.id,
          destinationChapterId: chapterId,
        );
        break;
    }
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    _applyMutationOutcome(outcome);
    _showMessage('Moved successfully. Existing teaching links were kept consistent.');
  }

  Future<void> _duplicateNode(SyllabusNodeRef node) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    late SyllabusMutationOutcome outcome;
    switch (node.kind) {
      case SyllabusNodeKind.classValue:
        return;
      case SyllabusNodeKind.subject:
        final subject = workspace.subjectById(node.id);
        if (subject == null) return;
        final classId = await _chooseClassDestination(
          workspace,
          title: 'Duplicate ${subject.name}',
          helper: 'Choose where the copied subject structure should be created.',
          selectedId: subject.classId,
        );
        if (classId == null || !mounted) return;
        outcome = await _managerController.duplicateSubject(
          subjectId: subject.id,
          destinationClassId: classId,
        );
        break;
      case SyllabusNodeKind.unit:
        final unit = workspace.unitById(node.id);
        if (unit == null) return;
        final subjectId = await _chooseSubjectDestination(
          workspace,
          title: 'Duplicate ${unit.title}',
          helper: 'Choose where the copied unit structure should be created.',
          selectedId: unit.subjectId,
        );
        if (subjectId == null || !mounted) return;
        outcome = await _managerController.duplicateUnit(
          unitId: unit.id,
          destinationSubjectId: subjectId,
        );
        break;
      case SyllabusNodeKind.chapter:
        final chapter = workspace.chapterById(node.id);
        if (chapter == null) return;
        final destination = await _chooseChapterDestination(
          workspace,
          title: 'Duplicate ${chapter.title}',
          initialSubjectId: chapter.subjectId,
          initialUnitId: chapter.unitId,
          actionLabel: 'Duplicate',
        );
        if (destination == null || !mounted) return;
        outcome = await _managerController.duplicateChapter(
          chapterId: chapter.id,
          destinationSubjectId: destination.subjectId,
          destinationUnitId: destination.unitId,
        );
        break;
      case SyllabusNodeKind.topic:
        final topic = workspace.topicById(node.id);
        if (topic == null) return;
        final chapterId = await _chooseChapterForTopic(
          workspace,
          title: 'Duplicate ${topic.title}',
          selectedId: topic.chapterId,
        );
        if (chapterId == null || !mounted) return;
        outcome = await _managerController.duplicateTopic(
          topicId: topic.id,
          destinationChapterId: chapterId,
        );
        break;
    }
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    _applyMutationOutcome(outcome);
    _showMessage(
      'Structure duplicated. Teaching history, completion progress and attachments were not copied.',
    );
  }

  Future<String?> _chooseClassDestination(
    TeachingPlannerWorkspace workspace, {
    required String title,
    required String helper,
    String? selectedId,
    bool excludeSelected = false,
  }) {
    final mergeState =
        ref.read(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    final values = workspace.activeClasses
        .where(
          (item) =>
              !mergeState.isOfficialLocalId('class', item.id) &&
              (!excludeSelected || item.id != selectedId),
        )
        .toList(growable: false);
    return _chooseDestinationId(
      title: title,
      helper: helper,
      emptyMessage: 'No other class is available.',
      entries: [
        for (final item in values)
          _DestinationEntry(
            id: item.id,
            title: item.name,
            subtitle: item.academicYear ?? 'Academic year not set',
          ),
      ],
    );
  }

  Future<String?> _chooseSubjectDestination(
    TeachingPlannerWorkspace workspace, {
    required String title,
    required String helper,
    String? selectedId,
    bool excludeSelected = false,
  }) {
    final mergeState =
        ref.read(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    final values = workspace.subjects
        .where(
          (item) =>
              !item.isArchived &&
              !mergeState.isOfficialLocalId('subject', item.id) &&
              (!excludeSelected || item.id != selectedId),
        )
        .toList(growable: false);
    return _chooseDestinationId(
      title: title,
      helper: helper,
      emptyMessage: 'No other subject is available.',
      entries: [
        for (final item in values)
          _DestinationEntry(
            id: item.id,
            title: item.name,
            subtitle: workspace.classById(item.classId)?.name ?? 'Unknown class',
          ),
      ],
    );
  }

  Future<String?> _chooseChapterForTopic(
    TeachingPlannerWorkspace workspace, {
    required String title,
    String? selectedId,
    bool excludeSelected = false,
  }) {
    final mergeState =
        ref.read(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    final values = workspace.chapters
        .where(
          (item) =>
              !item.isArchived &&
              !mergeState.isOfficialLocalId('chapter', item.id) &&
              (!excludeSelected || item.id != selectedId),
        )
        .toList(growable: false);
    return _chooseDestinationId(
      title: title,
      helper: 'Choose the destination chapter.',
      emptyMessage: 'No other chapter is available.',
      entries: [
        for (final item in values)
          _DestinationEntry(
            id: item.id,
            title: item.title,
            subtitle: _chapterDestinationSubtitle(workspace, item),
          ),
      ],
    );
  }

  Future<String?> _chooseDestinationId({
    required String title,
    required String helper,
    required String emptyMessage,
    required List<_DestinationEntry> entries,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(helper),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Text(emptyMessage)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        title: Text(entry.title),
                        subtitle: entry.subtitle == null
                            ? null
                            : Text(entry.subtitle!),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, entry.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<_ChapterDestinationChoice?> _chooseChapterDestination(
    TeachingPlannerWorkspace workspace, {
    required String title,
    required String initialSubjectId,
    required String? initialUnitId,
    required String actionLabel,
  }) {
    final mergeState =
        ref.read(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    final subjects = workspace.subjects
        .where(
          (item) =>
              !item.isArchived &&
              !mergeState.isOfficialLocalId('subject', item.id),
        )
        .toList(growable: false);
    return showDialog<_ChapterDestinationChoice>(
      context: context,
      builder: (context) {
        var subjectId = initialSubjectId;
        var unitId = initialUnitId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!subjects.any((item) => item.id == subjectId) && subjects.isNotEmpty) {
              subjectId = subjects.first.id;
              unitId = null;
            }
            final units = workspace
                .activeUnitsForSubject(subjectId)
                .where(
                  (item) =>
                      !mergeState.isOfficialLocalId('unit', item.id),
                )
                .toList(growable: false);
            if (unitId != null && !units.any((item) => item.id == unitId)) {
              unitId = null;
            }
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey('phase1b-chapter-subject-$subjectId'),
                      initialValue: subjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: [
                        for (final subject in subjects)
                          DropdownMenuItem(
                            value: subject.id,
                            child: Text(
                              "${workspace.classById(subject.classId)?.name ?? 'Class'} · ${subject.name}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          subjectId = value;
                          unitId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      key: ValueKey("phase1b-chapter-unit-$subjectId-${unitId ?? 'root'}"),
                      initialValue: unitId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No unit / subject root'),
                        ),
                        for (final unit in units)
                          DropdownMenuItem<String?>(
                            value: unit.id,
                            child: Text(unit.title, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setDialogState(() => unitId = value),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Existing lesson history stays linked when moving. Duplicating copies only the syllabus structure.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: subjects.isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            _ChapterDestinationChoice(
                              subjectId: subjectId,
                              unitId: unitId,
                            ),
                          ),
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _chapterDestinationSubtitle(
    TeachingPlannerWorkspace workspace,
    PlannerChapter chapter,
  ) {
    final subject = workspace.subjectById(chapter.subjectId);
    final plannerClass = subject == null ? null : workspace.classById(subject.classId);
    final unit = chapter.unitId == null ? null : workspace.unitById(chapter.unitId!);
    return [
      if (plannerClass != null) plannerClass.name,
      if (subject != null) subject.name,
      if (unit != null) unit.title,
    ].join(' · ');
  }

  Future<void> _trashNode(SyllabusNodeRef node) async {
    final prompt = _managerController.trashPrompt(node);
    if (prompt == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(prompt.title),
        content: Text(prompt.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await _managerController.moveToTrash(node);
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    setState(() => _selected = outcome.selection);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Moved to Trash.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final restored = await _managerController.restoreFromTrash(node);
            if (!mounted) return;
            if (!restored) {
              _showError();
              return;
            }
            setState(() => _selected = node);
          },
        ),
      ),
    );
  }

  Future<void> _openTrash() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'teaching-planner/syllabus-trash'),
        builder: (_) => const _SyllabusTrashScreen(),
      ),
    );
  }

  Future<void> _archiveNode(SyllabusNodeRef node) async {
    final prompt = _managerController.archivePrompt(node);
    if (prompt == null) return;
    final confirmed = await _confirmArchive(prompt);
    if (!confirmed || !mounted) return;

    final outcome = await _managerController.archive(node);
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    setState(() => _selected = outcome.selection);
  }

  Future<bool> _confirmArchive(SyllabusArchivePrompt prompt) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prompt.title),
        content: Text(prompt.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _reorderSubjects(String classId, List<String> ids) async {
    final ok = await _managerController.reorderSubjects(classId, ids);
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _reorderUnits(String subjectId, List<String> ids) async {
    final ok = await _managerController.reorderUnits(subjectId, ids);
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _reorderChapters(
    String subjectId,
    String? unitId,
    List<String> ids,
  ) async {
    final ok = await _managerController.reorderChapters(subjectId, unitId, ids);
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _reorderTopics(String chapterId, List<String> ids) async {
    final ok = await _managerController.reorderTopics(chapterId, ids);
    if (!mounted || ok) return;
    _showError();
  }

  Future<void> _openCurriculumPackageBuilder(SyllabusNodeRef? selected) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'teaching-planner/curriculum-package-builder',
        ),
        builder: (_) => CurriculumPackageBuilderScreen(
          initialClassId: selected?.classId,
          initialSubjectId: selected?.subjectId,
          initialUnitId: selected?.unitId,
          initialChapterId: selected?.chapterId,
        ),
      ),
    );
  }

  Future<void> _importSyllabus() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    final pickedFile = picked?.files.single;
    if (pickedFile == null || !mounted) return;

    try {
      final source = pickedFile.path != null
          ? await File(pickedFile.path!).readAsString()
          : pickedFile.bytes == null
          ? null
          : utf8.decode(pickedFile.bytes!);
      if (source == null) {
        throw const SyllabusImportException(
          'The selected file could not be accessed on this device.',
        );
      }
      final package = const SyllabusImportCodec().decodeString(source);
      if (!mounted) return;
      final summary = _importSummary(package);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import syllabus?'),
          content: Text(
            '$summary\n\nEduSheet will create this as a new syllabus. Existing classes and planning data will not be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final outcome = await _managerController.importSyllabus(package);
      if (!mounted) return;
      if (!outcome.success) {
        _showError();
        return;
      }
      final selection = outcome.selection;
      if (selection != null) {
        setState(() {
          _clearSearchAndFilters();
          _selected = selection;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syllabus imported as a new class.')),
      );
    } catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Syllabus import failed'),
          content: Text(
            error is SyllabusImportException
                ? error.message
                : 'The selected file could not be imported safely.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _importSummary(SyllabusImportPackage package) {
    var units = 0;
    var chapters = 0;
    var topics = 0;
    for (final subject in package.subjects) {
      units += subject.units.length;
      chapters += subject.chapters.length;
      topics += subject.chapters.fold<int>(
        0,
        (sum, chapter) => sum + chapter.topics.length,
      );
      for (final unit in subject.units) {
        chapters += unit.chapters.length;
        topics += unit.chapters.fold<int>(
          0,
          (sum, chapter) => sum + chapter.topics.length,
        );
      }
    }
    return '${package.className}\n${package.subjects.length} subject(s) • $units unit(s) • $chapters chapter(s) • $topics topic(s)';
  }

  void _showError() {
    final message =
        ref.read(teachingPlannerProvider).errorMessage ??
        'The syllabus change could not be saved.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SyllabusPaperContext {
  const _SyllabusPaperContext({
    required this.className,
    required this.subjectName,
  });

  final String className;
  final String? subjectName;
}

class _SyllabusReferenceHeader extends StatelessWidget {
  const _SyllabusReferenceHeader({
    required this.selected,
    required this.guidedSetup,
    required this.isLoading,
    required this.onBack,
    required this.onCreateSyllabus,
    required this.onImportSyllabus,
    required this.onShareCurriculum,
    required this.trashCount,
    required this.onOpenTrash,
    required this.onRefresh,
    required this.onShowGuide,
  });

  final SyllabusNodeRef? selected;
  final bool guidedSetup;
  final bool isLoading;
  final VoidCallback? onBack;
  final VoidCallback onCreateSyllabus;
  final VoidCallback onImportSyllabus;
  final VoidCallback? onShareCurriculum;
  final int trashCount;
  final VoidCallback onOpenTrash;
  final VoidCallback onRefresh;
  final VoidCallback onShowGuide;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final veryCompact = constraints.maxWidth < 420;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (guidedSetup) ...[
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Syllabus',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected == null ? 'Add Syllabus' : 'Manage Syllabus',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected == null
                          ? 'Create or import the syllabus you actually teach.'
                          : 'Edit the selected syllabus without changing its planning logic.',
                      maxLines: compact && selected != null ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              if (compact && selected != null) ...[
                const SizedBox(width: 8),
                if (onShareCurriculum != null)
                  IconButton(
                    tooltip: 'Share or assign curriculum',
                    onPressed: isLoading ? null : onShareCurriculum,
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                IconButton(
                  tooltip: trashCount == 0 ? 'Trash' : 'Trash ($trashCount)',
                  onPressed: onOpenTrash,
                  icon: Badge(
                    isLabelVisible: trashCount > 0,
                    label: Text('$trashCount'),
                    child: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'Show Create Syllabus guide',
                  onPressed: onShowGuide,
                  icon: const Icon(Icons.help_outline_rounded),
                ),
                IconButton(
                  tooltip: 'Refresh syllabus',
                  onPressed: isLoading ? null : onRefresh,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.inkMuted,
                    side: BorderSide(color: colors.border),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (selected == null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onImportSyllabus,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import JSON'),
                ),
              if (selected == null)
                GuideAnchor(
                  targetId: CreateSyllabusGuideTargets.openCreateSyllabus,
                  reportPointerActivation: true,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onCreateSyllabus,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create syllabus'),
                  ),
                ),
              if (onShareCurriculum != null)
                if (veryCompact)
                  IconButton(
                    tooltip: 'Share or assign curriculum',
                    onPressed: isLoading ? null : onShareCurriculum,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.inkMuted,
                      side: BorderSide(color: colors.border),
                    ),
                    icon: const Icon(Icons.ios_share_rounded),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onShareCurriculum,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share / assign'),
                  ),
              IconButton(
                tooltip: trashCount == 0 ? 'Trash' : 'Trash ($trashCount)',
                onPressed: onOpenTrash,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.inkMuted,
                  side: BorderSide(color: colors.border),
                ),
                icon: Badge(
                  isLabelVisible: trashCount > 0,
                  label: Text('$trashCount'),
                  child: const Icon(Icons.delete_outline_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Show Create Syllabus guide',
                onPressed: onShowGuide,
                icon: const Icon(Icons.help_outline_rounded),
              ),
              if (!(compact && selected != null))
                IconButton(
                  tooltip: 'Refresh syllabus',
                  onPressed: isLoading ? null : onRefresh,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.inkMuted,
                    side: BorderSide(color: colors.border),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          );

          if (compact) {
            if (selected != null) {
              return title;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}


class _SyllabusTrashScreen extends ConsumerStatefulWidget {
  const _SyllabusTrashScreen();

  @override
  ConsumerState<_SyllabusTrashScreen> createState() => _SyllabusTrashScreenState();
}

class _SyllabusTrashScreenState extends ConsumerState<_SyllabusTrashScreen> {
  final Set<SyllabusNodeRef> _selected = <SyllabusNodeRef>{};

  SyllabusManagerController _controller() {
    final notifier = ref.read(teachingPlannerProvider.notifier);
    return SyllabusManagerController(
      notifier: notifier,
      readWorkspace: () => ref.read(teachingPlannerProvider).workspace,
    );
  }

  void _toggleSelection(SyllabusNodeRef node) {
    setState(() {
      if (!_selected.add(node)) _selected.remove(node);
    });
  }

  Future<SyllabusRestoreDestination?> _chooseRestoreDestination(
    List<SyllabusRestoreDestination> destinations,
  ) {
    if (destinations.isEmpty) return Future.value(null);
    return showDialog<SyllabusRestoreDestination>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore to another location'),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: destinations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final destination = destinations[index];
                return ListTile(
                  title: Text(destination.title),
                  subtitle: Text(destination.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(dialogContext, destination),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _restoreEntry(
    SyllabusManagerController controller,
    SyllabusTrashEntry entry,
  ) async {
    final prompt = controller.restorePrompt(entry.node);
    if (!prompt.requiresParentRecovery) {
      return controller.restoreFromTrash(entry.node);
    }

    final destinations = controller.restoreDestinations(entry.node);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_rounded),
        title: Text(prompt.title),
        content: Text(prompt.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (destinations.isNotEmpty)
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'elsewhere'),
              child: const Text('Restore elsewhere'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'hierarchy'),
            child: const Text('Restore hierarchy'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return false;
    if (action == 'hierarchy') {
      return controller.restoreHierarchyAndNode(entry.node);
    }
    final destination = await _chooseRestoreDestination(destinations);
    if (!mounted || destination == null) return false;
    return controller.restoreToDestination(entry.node, destination);
  }

  List<SyllabusTrashEntry> _topLevelSelectedEntries(
    List<SyllabusTrashEntry> entries,
  ) {
    final selectedEntries = entries
        .where((item) => _selected.contains(item.node))
        .toList(growable: false);
    return selectedEntries
        .where(
          (entry) => !selectedEntries.any(
            (other) => other.node != entry.node && other.node.contains(entry.node),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _restoreSelected(
    SyllabusManagerController controller,
    List<SyllabusTrashEntry> entries,
  ) async {
    final selectedEntries = _topLevelSelectedEntries(entries);
    if (selectedEntries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_rounded),
        title: Text('Restore ${selectedEntries.length} item(s)?'),
        content: const Text(
          'EduSheet will also restore any required parent hierarchy. Existing active items are never overwritten; a name conflict will leave that item in Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var restored = 0;
    for (final entry in selectedEntries) {
      if (await controller.restoreHierarchyAndNode(entry.node)) restored++;
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$restored of ${selectedEntries.length} item(s) restored.')),
    );
  }

  Future<void> _deleteSelectedPermanently(
    SyllabusManagerController controller,
    List<SyllabusTrashEntry> entries,
  ) async {
    final selectedEntries = _topLevelSelectedEntries(entries);
    if (selectedEntries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text('Delete ${selectedEntries.length} item(s) permanently?'),
        content: const Text(
          'This cannot be undone. Saved Papers themselves are not deleted, but planner hierarchy, lesson links and resource links inside these Trash scopes can be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var deleted = 0;
    for (final entry in selectedEntries) {
      if (await controller.deletePermanently(entry.node)) deleted++;
    }
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deleted of ${selectedEntries.length} item(s) permanently deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(teachingPlannerProvider);
    final controller = _controller();
    final entries = controller.trashEntries();
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: selecting
            ? IconButton(
                tooltip: 'Clear selection',
                onPressed: () => setState(_selected.clear),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(selecting ? '${_selected.length} selected' : 'Syllabus Trash'),
        actions: selecting
            ? [
                IconButton(
                  tooltip: 'Restore selected',
                  onPressed: () => _restoreSelected(controller, entries),
                  icon: const Icon(Icons.restore_rounded),
                ),
                IconButton(
                  tooltip: 'Delete selected permanently',
                  onPressed: () => _deleteSelectedPermanently(controller, entries),
                  icon: const Icon(Icons.delete_forever_outlined),
                ),
              ]
            : null,
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Trash is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Deleted syllabus items stay recoverable here until you delete them permanently.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final selected = _selected.contains(entry.node);
                return Card(
                  child: ListTile(
                    selected: selected,
                    leading: selecting
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleSelection(entry.node),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    title: Text(entry.title),
                    subtitle: Text('${entry.typeLabel} • ${entry.impactLabel}'),
                    onLongPress: () => _toggleSelection(entry.node),
                    onTap: selecting ? () => _toggleSelection(entry.node) : null,
                    trailing: selecting
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: 'Trash actions',
                            onSelected: (value) async {
                              if (value == 'restore') {
                                final ok = await _restoreEntry(controller, entry);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? '${entry.title} restored.'
                                          : 'Could not restore ${entry.title}. Check its parent or same-name conflicts.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    icon: const Icon(Icons.warning_amber_rounded),
                                    title: Text('Delete ${entry.title} permanently?'),
                                    content: Text(
                                      'This cannot be undone. ${entry.impactLabel} will be permanently removed from this Teaching Planner. Saved Papers themselves are not deleted.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: const Text('Delete permanently'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                final ok = await controller.deletePermanently(entry.node);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? '${entry.title} permanently deleted.'
                                          : 'Could not delete ${entry.title}.',
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'restore',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.restore_rounded),
                                  title: Text('Restore'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_forever_outlined),
                                  title: Text('Delete permanently'),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}

class _GuidedSyllabusSetupBanner extends StatelessWidget {
  const _GuidedSyllabusSetupBanner({
    required this.workspace,
    required this.classId,
    required this.onContinue,
  });

  final TeachingPlannerWorkspace workspace;
  final String? classId;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = classId;
    final subjects = id == null
        ? const <PlannerSubject>[]
        : workspace.activeSubjectsForClass(id);
    final subjectIds = subjects.map((item) => item.id).toSet();
    final chapterCount = workspace.chapters
        .where(
          (item) => !item.isArchived && subjectIds.contains(item.subjectId),
        )
        .length;
    final ready = subjects.isNotEmpty && chapterCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Card(
        elevation: 0,
        color: scheme.primaryContainer.withValues(alpha: .45),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.account_tree_rounded, color: scheme.primary),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Setup step 2 of 3 · Build a usable syllabus',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ready
                          ? '${subjects.length} subject${subjects.length == 1 ? '' : 's'} · $chapterCount chapter${chapterCount == 1 ? '' : 's'} ready. You can continue.'
                          : 'Add a subject, then add at least one chapter. Units and topics are optional.',
                    ),
                  ],
                ),
              ),
              GuideAnchor(
                targetId: CreateSyllabusGuideTargets.continueSetup,
                child: FilledButton.icon(
                  key: const ValueKey('planner-guided-syllabus-continue'),
                  onPressed: ready ? onContinue : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationEntry {
  const _DestinationEntry({
    required this.id,
    required this.title,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
}

class _ChapterDestinationChoice {
  const _ChapterDestinationChoice({
    required this.subjectId,
    required this.unitId,
  });

  final String subjectId;
  final String? unitId;
}
