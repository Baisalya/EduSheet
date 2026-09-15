import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../data/syllabus_import_codec.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_class.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/syllabus_import_package.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_resource.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_node_ref.dart';
import '../providers/teaching_planner_provider.dart';
import '../services/syllabus_attachment_controller.dart';
import '../services/syllabus_manager_controller.dart';
import '../services/syllabus_navigation_policy.dart';
import '../widgets/syllabus_adaptive_shell.dart';
import '../widgets/syllabus_detail_panel.dart';
import '../widgets/syllabus_entity_sheet.dart';
import '../widgets/syllabus_outline.dart';
import '../widgets/syllabus_start_sheet.dart';

class SyllabusManagerScreen extends ConsumerStatefulWidget {
  const SyllabusManagerScreen({super.key});

  @override
  ConsumerState<SyllabusManagerScreen> createState() =>
      _SyllabusManagerScreenState();
}

class _SyllabusManagerScreenState extends ConsumerState<SyllabusManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  SyllabusNodeRef? _selected;
  String _query = '';
  SyllabusFilter _filter = SyllabusFilter.all;

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
    final workspace = state.workspace;
    final selected = SyllabusNavigationPolicy.validatedSelection(
      workspace,
      _selected,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus Manager'),
        actions: [
          IconButton(
            tooltip: 'Import syllabus JSON',
            onPressed: state.isLoading ? null : _importSyllabus,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: 'Refresh syllabus',
            onPressed: state.isLoading
                ? null
                : () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SyllabusAdaptiveToolbar(
              filter: _filter,
              searchController: _searchController,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterChanged: (value) => setState(() => _filter = value),
              onCreateSyllabus: _createSyllabus,
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
                      constraints.maxWidth >= 840 &&
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
      ),
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
    return SyllabusDetailPanel(
      workspace: workspace,
      selected: selected,
      query: _query,
      filter: _filter,
      reorderEnabled: _canReorder,
      onSelected: _select,
      onEdit: _editNode,
      onArchive: _archiveNode,
      onAddAttachments: _addAttachments,
      onOpenAttachment: _openAttachment,
      onRemoveAttachment: _removeAttachment,
      onCreateSubject: _createSubject,
      onCreateUnit: _createUnit,
      onCreateChapter: _createChapter,
      onCreateTopic: _createTopic,
      onReorderSubjects: (classId, ids) => _reorderSubjects(classId, ids),
      onReorderUnits: (subjectId, ids) => _reorderUnits(subjectId, ids),
      onReorderChapters: (subjectId, unitId, ids) =>
          _reorderChapters(subjectId, unitId, ids),
      onReorderTopics: (chapterId, ids) => _reorderTopics(chapterId, ids),
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
      fileStore: ref.read(teachingResourceFileStoreProvider),
      attachFiles: ({required owner, required files}) =>
          notifier.attachTeachingFiles(owner: owner, files: files),
      archiveResource: notifier.archiveTeachingResource,
    );
  }

  Future<void> _addAttachments(SyllabusNodeRef node) async {
    final result = await _attachmentController.addFiles(node);
    if (!mounted || result.cancelled) {
      return;
    }
    _showAttachmentResult(result);
  }

  Future<void> _openAttachment(TeachingResource resource) async {
    final result = await _attachmentController.open(resource);
    if (!mounted || result.cancelled) {
      return;
    }
    _showAttachmentResult(result);
  }

  Future<void> _removeAttachment(TeachingResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text(
          '${resource.originalFileName ?? resource.title} will disappear from this syllabus. EduSheet keeps archived resource data safely for recovery.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await _attachmentController.archive(resource);
    if (!mounted) {
      return;
    }
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
    _applyMutationOutcome(outcome);
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
    _applyMutationOutcome(outcome);
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
    _applyMutationOutcome(outcome);
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
  }

  void _applyMutationOutcome(SyllabusMutationOutcome outcome) {
    if (!mounted) return;
    if (!outcome.success) {
      _showError();
      return;
    }
    final selection = outcome.selection;
    if (selection == null) return;
    setState(() {
      _clearSearchAndFilters();
      _selected = selection;
    });
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
