import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:edusheet/features/document_reader/presentation/providers/document_provider.dart';
import 'package:edusheet/features/eds_import/presentation/screens/eds_import_center_screen.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/presentation/screens/user_manual_screen.dart';
import 'package:edusheet/features/guided_experience/presentation/widgets/contextual_help_prompt.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/features/premium/presentation/widgets/premium_gate_dialog.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../application/teaching_resource_attachment_service.dart';
import '../../data/teaching_pack_codec.dart';
import '../../domain/models/curriculum_layer_policy.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../services/teaching_attachment_open_coordinator.dart';
import '../services/teaching_resource_file_picker.dart';
import '../services/teaching_pack_export_file_saver.dart';
import '../providers/teaching_planner_provider.dart';
import 'teaching_attachment_image_preview_screen.dart';
import '../widgets/teaching_planner_page_shell.dart';
import '../widgets/teaching_planner_responsive_content.dart';
import '../widgets/teaching_planner_shared_components.dart';

class TeachingWorkspaceScreen extends ConsumerStatefulWidget {
  const TeachingWorkspaceScreen({
    super.key,
    this.initialLessonId,
    this.initialTeachingPackPath,
  });

  final String? initialLessonId;
  final String? initialTeachingPackPath;

  @override
  ConsumerState<TeachingWorkspaceScreen> createState() =>
      _TeachingWorkspaceScreenState();
}

class _TeachingWorkspaceScreenState
    extends ConsumerState<TeachingWorkspaceScreen> {
  String? _lessonId;
  bool _incomingTeachingPackScheduled = false;

  @override
  void initState() {
    super.initState();
    _lessonId = widget.initialLessonId;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final mergeState =
        ref.watch(curriculumMergeStateProvider).asData?.value ??
        CurriculumMergeState.empty();
    final layerPolicy = CurriculumLayerPolicy(mergeState);
    final lessons = workspace.activeLessonPlans;
    final selected = _selectedLesson(lessons);
    if (widget.initialTeachingPackPath != null &&
        selected != null &&
        !_incomingTeachingPackScheduled) {
      _incomingTeachingPackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _importPack(selected, sourcePath: widget.initialTeachingPackPath);
      });
    }
    final lessonLayer = selected == null
        ? null
        : layerPolicy.describe('lessonPlan', selected.id);
    final resources = selected == null
        ? const <TeachingResource>[]
        : workspace.activeResourcesForLesson(selected.id);

    final shell = TeachingPlannerPageShell(
      title: 'Teaching workspace',
      currentDestination: TeachingPlannerDestination.workspace,
      showGlobalNavigation: widget.initialLessonId == null,
      actions: [
        IconButton(
          tooltip: 'Teaching Workspace help',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const EduSheetUserManualScreen(
                focus: EduSheetManualSection.files,
              ),
            ),
          ),
          icon: const Icon(Icons.help_outline_rounded),
        ),
        IconButton(
          tooltip: 'Refresh workspace',
          onPressed: () => ref.read(teachingPlannerProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: lessons.isEmpty
          ? _NoLessons(
              incomingPack: widget.initialTeachingPackPath != null,
              onPlanLesson: () => Navigator.of(context).maybePop(),
            )
          : TeachingPlannerResponsiveContent(
              maxWidth: 1240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkspaceHero(
                    lesson: selected!,
                    resourceCount: resources.length,
                    layer: lessonLayer!,
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space16),
                  TeachingPlannerResponsiveSplit(
                    breakpoint: TeachingPlannerBreakpoints.twoPane,
                    sideWidth: 300,
                    sideFirstOnCompact: true,
                    side: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LessonPicker(
                          lessons: lessons,
                          value: selected.id,
                          onChanged: (value) =>
                              setState(() => _lessonId = value),
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space12),
                        _QuickActions(
                          onNote: () => _addNote(selected, mathFirst: false),
                          onMath: () => _addNote(selected, mathFirst: true),
                          onFile: () => _addFile(selected),
                          onLink: () => _addLink(selected),
                          onGeometry: () => _addGeometry(selected),
                        ),
                      ],
                    ),
                    primary: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TeachingPlannerSectionHeader(
                          title: 'Materials for this lesson',
                          subtitle: resources.isEmpty
                              ? 'Add the notes, files and visuals you want ready before class.'
                              : '${resources.length} item${resources.length == 1 ? '' : 's'} ready for teaching.',
                          icon: Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space12),
                        if (resources.isEmpty)
                          _EmptyResources(
                            onAdd: () => _addNote(selected, mathFirst: false),
                          )
                        else
                          _ResourceGrid(
                            resources: resources,
                            onOpen: (item) => _openResource(item),
                            onEdit: (item) => _editResource(item),
                            onArchive: (item) => _archiveResource(item),
                            canEdit: (item) =>
                                !layerPolicy.isOfficial('resource', item.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space20),
                  _TeachingPackCard(
                    lesson: selected,
                    resourceCount: resources.length,
                    onExport: resources.isEmpty
                        ? null
                        : () => _exportPack(selected, resources),
                    onImport: () => _importPack(selected),
                  ),
                ],
              ),
            ),
    );

    if (selected == null || resources.isNotEmpty) return shell;

    return ContextualHelpOffer(
      suggestion: ContextualHelpSuggestion(
        id: 'teaching_workspace.${selected.id}.add_first_material',
        screen: GuidedScreenContext.teachingWorkspace,
        title: 'Add teaching material for this lesson?',
        message:
            'You can keep a PDF, Word file, image, note, link or diagram with this lesson so it is ready before class.',
        primaryLabel: 'Add file',
        minimumInactivity: const Duration(minutes: 1),
        requiresIncompleteAction: true,
        suppressWhenRelatedGuideCompleted: false,
      ),
      signals: const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingWorkspace,
        hasIncompleteAction: true,
      ),
      onShowMe: () => _addFile(selected),
      child: shell,
    );
  }

  LessonPlan? _selectedLesson(List<LessonPlan> lessons) {
    if (lessons.isEmpty) return null;
    final requested = _lessonId;
    if (requested != null) {
      for (final lesson in lessons) {
        if (lesson.id == requested) return lesson;
      }
    }
    return lessons.first;
  }

  Future<void> _addNote(LessonPlan lesson, {required bool mathFirst}) async {
    final draft = await showAdaptiveModalBottomSheet<_TextResourceDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoteResourceSheet(mathFirst: mathFirst),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .createTeachingResource(
          lessonPlanId: lesson.id,
          kind: TeachingResourceKind.note,
          role: draft.role,
          title: draft.title,
          body: draft.value,
        );
    _showSaveResult(ok, success: 'Teaching note added.');
  }

  Future<void> _addLink(LessonPlan lesson) async {
    final draft = await showAdaptiveModalBottomSheet<_TextResourceDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LinkResourceSheet(),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .createTeachingResource(
          lessonPlanId: lesson.id,
          kind: TeachingResourceKind.link,
          role: draft.role,
          title: draft.title,
          url: draft.value,
        );
    _showSaveResult(ok, success: 'Link added to the lesson.');
  }

  Future<void> _addGeometry(LessonPlan lesson) async {
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .createTeachingResource(
          lessonPlanId: lesson.id,
          kind: TeachingResourceKind.geometry,
          role: TeachingResourceRole.teachInClass,
          title: diagram.name,
          geometryJson: diagram.toJson(),
        );
    _showSaveResult(ok, success: 'Geometry diagram added.');
  }

  Future<void> _addFile(LessonPlan lesson) async {
    try {
      var linkOriginal = false;
      if (Platform.isWindows) {
        final mode = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add teaching file'),
            content: const Text(
              'Add to EduSheet is recommended for portable .eds/.edtp backups. Link original keeps the file in its current Windows location.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'link'),
                child: const Text('Link original'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, 'managed'),
                child: const Text('Add to EduSheet'),
              ),
            ],
          ),
        );
        if (mode == null || !mounted) return;
        linkOriginal = mode == 'link';
      }
      final files = await ref
          .read(teachingResourceFilePickerProvider)
          .pickFiles(
            dialogTitle: 'Add teaching material',
            allowMultiple: true,
            readBytes: !linkOriginal,
          );
      if (files.isEmpty || !mounted) return;
      final notifier = ref.read(teachingPlannerProvider.notifier);
      final ok = linkOriginal
          ? await notifier.attachLinkedTeachingFiles(
              owner: TeachingResourceOwner.lessonPlan(lesson.id),
              files: files,
              role: TeachingResourceRole.teachInClass,
            )
          : await notifier.attachTeachingFiles(
              owner: TeachingResourceOwner.lessonPlan(lesson.id),
              files: files,
              role: TeachingResourceRole.teachInClass,
            );
      final success = files.length == 1
          ? (linkOriginal
                ? '${files.single.fileName} linked to its original file.'
                : '${files.single.fileName} added to EduSheet.')
          : (linkOriginal
                ? '${files.length} original files linked.'
                : '${files.length} files added to EduSheet.');
      _showSaveResult(ok, success: success);
    } on TeachingAttachmentSelectionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Those files could not be attached. Your planner was not changed.',
          ),
        ),
      );
    }
  }

  Future<void> _openResource(TeachingResource item) async {
    switch (item.kind) {
      case TeachingResourceKind.note:
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(item.title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SelectableText(item.body ?? ''),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        break;
      case TeachingResourceKind.link:
        final uri = Uri.tryParse(item.url ?? '');
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case TeachingResourceKind.file:
        await _openFileResource(item);
        break;
      case TeachingResourceKind.paper:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Open linked papers from the syllabus Resources & Papers section.',
            ),
          ),
        );
        break;
      case TeachingResourceKind.smartDocument:
        await _openSmartDocumentResource(item);
        break;
      case TeachingResourceKind.geometry:
        final mergeState = await ref.read(curriculumMergeStateProvider.future);
        if (!mounted) return;
        if (mergeState.isOfficialLocalId('resource', item.id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This geometry is an official curriculum reference. Add your own geometry from Quick Actions to make an editable version.',
              ),
            ),
          );
          return;
        }
        final json = item.geometryJson;
        if (json == null) return;
        final updated = await GeometryBuilderScreen.show(
          context,
          initialDiagram: GeometryDiagram.fromJson(
            Map<String, dynamic>.from(json),
          ),
        );
        if (updated == null || !mounted) return;
        final ok = await ref
            .read(teachingPlannerProvider.notifier)
            .updateTeachingResource(
              item.id,
              role: item.role,
              title: updated.name,
              geometryJson: updated.toJson(),
            );
        _showSaveResult(ok, success: 'Geometry diagram updated.');
        break;
    }
  }

  Future<void> _openSmartDocumentResource(TeachingResource item) async {
    final documentId = item.linkedSmartDocumentId;
    if (documentId == null || documentId.trim().isEmpty) {
      _showMessage('This Smart Document link is incomplete.');
      return;
    }
    try {
      var document = await ref
          .read(smartDocumentRepositoryProvider)
          .getById(documentId);
      if (!mounted) return;
      if (document == null) {
        _showMessage(
          'This Smart Document is not on this device. The lesson link was kept safely.',
        );
        return;
      }
      try {
        final recovery = await ref
            .read(smartEditorRecoveryStoreProvider)
            .newerSnapshotFor(document);
        if (recovery != null) {
          document = recovery;
          await ref.read(smartDocumentRepositoryProvider).save(recovery);
          try {
            await ref.read(smartEditorRecoveryStoreProvider).clear(documentId);
          } catch (_) {
            // Primary repository now has the recovered snapshot.
          }
        }
      } catch (_) {
        // Recovery must not block opening the primary copy.
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SmartEditorScreen(document: document!),
        ),
      );
      ref.invalidate(smartDocumentsProvider);
      if (!mounted) return;
      final refreshed = await ref
          .read(smartDocumentRepositoryProvider)
          .getById(documentId);
      final cleanTitle = refreshed?.title.trim();
      if (cleanTitle != null &&
          cleanTitle.isNotEmpty &&
          cleanTitle != item.title) {
        await ref
            .read(teachingPlannerProvider.notifier)
            .updateTeachingResource(
              item.id,
              role: item.role,
              title: cleanTitle,
            );
      }
    } catch (_) {
      if (mounted) _showMessage('Smart Document could not be opened.');
    }
  }

  Future<void> _editResource(TeachingResource item) async {
    if (item.kind == TeachingResourceKind.geometry ||
        item.kind == TeachingResourceKind.smartDocument) {
      await _openResource(item);
      return;
    }
    if (item.kind == TeachingResourceKind.file ||
        item.kind == TeachingResourceKind.paper) {
      return;
    }
    final draft = await showAdaptiveModalBottomSheet<_TextResourceDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => item.kind == TeachingResourceKind.note
          ? _NoteResourceSheet(mathFirst: false, initial: item)
          : _LinkResourceSheet(initial: item),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateTeachingResource(
          item.id,
          role: draft.role,
          title: draft.title,
          body: item.kind == TeachingResourceKind.note
              ? draft.value
              : item.body,
          url: item.kind == TeachingResourceKind.link ? draft.value : item.url,
        );
    _showSaveResult(ok, success: 'Teaching resource updated.');
  }

  Future<void> _archiveResource(TeachingResource item) async {
    final isSmartDocument = item.kind == TeachingResourceKind.smartDocument;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from this lesson?'),
        content: Text(
          isSmartDocument
              ? '${item.title} will be unlinked from this lesson. The original document stays safely in Smart Editor.'
              : '${item.title} will be archived. Attached file data is kept safely for recovery/export.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .archiveTeachingResource(item.id);
    _showSaveResult(
      ok,
      success: isSmartDocument
          ? 'Smart Document removed from this lesson. Smart Editor is unchanged.'
          : 'Resource removed from this lesson. Managed file data was kept safely.',
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openFileResource(TeachingResource resource) async {
    final coordinator = TeachingAttachmentOpenCoordinator(
      fileStore: ref.read(teachingResourceFileStoreProvider),
      documentRepository: ref.read(documentRepositoryProvider),
    );
    final result = await coordinator.resolve(resource);
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
        await _recoverMissingFile(resource, result.message);
        return;
      case TeachingAttachmentOpenKind.invalid:
        _showMessage(result.message ?? 'This file could not be opened.');
        return;
    }
  }

  Future<void> _recoverMissingFile(
    TeachingResource resource,
    String? reason,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attachment not found'),
        content: Text(reason ?? 'This attachment is missing.'),
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
    final notifier = ref.read(teachingPlannerProvider.notifier);
    if (action == 'remove') {
      final saved = await notifier.archiveTeachingResource(resource.id);
      if (mounted) {
        _showMessage(saved ? 'Attachment removed.' : 'Attachment could not be removed.');
      }
      return;
    }
    final relinkOnly = action == 'locate' &&
        resource.fileOwnership == TeachingResourceFileOwnership.linkedExternal;
    List<TeachingAttachmentCandidate> files;
    try {
      files = await ref.read(teachingResourceFilePickerProvider).pickFiles(
        dialogTitle: action == 'locate'
            ? 'Locate attachment'
            : 'Replace attachment',
        allowMultiple: false,
        readBytes: !relinkOnly,
      );
    } on TeachingAttachmentSelectionException catch (error) {
      _showMessage(error.message);
      return;
    }
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    final saved = action == 'locate' &&
            resource.fileOwnership == TeachingResourceFileOwnership.linkedExternal &&
            (file.sourcePath ?? '').trim().isNotEmpty
        ? await notifier.relinkTeachingFile(resource: resource, file: file)
        : await notifier.replaceTeachingFileWithManagedCopy(
            resource: resource,
            file: file,
          );
    if (mounted) {
      _showMessage(
        saved
            ? (action == 'locate' ? 'Attachment location updated.' : 'Attachment replaced.')
            : 'Attachment could not be updated.',
      );
    }
  }

  Future<void> _exportPack(
    LessonPlan lesson,
    List<TeachingResource> resources,
  ) async {
    final capabilities = ref.read(teachingPlannerCapabilitiesProvider);
    if (!capabilities.allows(TeachingPlannerCapability.richCurriculumExport)) {
      await showPremiumGateDialog(
        context,
        title: 'Premium Teaching Pack export',
        message:
            'Your lesson and its resources remain editable. Premium is required only to create a new shareable Teaching Pack.',
      );
      return;
    }
    try {
      final workspace = ref.read(teachingPlannerProvider).workspace;
      final store = ref.read(teachingResourceFileStoreProvider);
      final payloadResources = <TeachingPackResourcePayload>[];
      for (final item in resources) {
        List<int>? bytes;
        if (item.kind == TeachingResourceKind.file) {
          if (!await store.resourceExists(item)) {
            throw FileSystemException(
              'Missing attached file: ${item.originalFileName ?? item.title}',
              item.externalFilePath ?? item.localRelativePath,
            );
          }
          bytes = await store.readResourceBytes(item);
        }
        payloadResources.add(
          TeachingPackResourcePayload(resource: item, fileBytes: bytes),
        );
      }
      final plannerClass = workspace.classById(lesson.classId)!;
      final subject = workspace.subjectById(lesson.subjectId)!;
      final chapter = workspace.chapterById(lesson.chapterId)!;
      final source = const TeachingPackCodec().encode(
        TeachingPackPayload(
          sourceLessonTitle: lesson.title,
          sourceClassName: plannerClass.name,
          sourceSubjectName: subject.name,
          sourceChapterTitle: chapter.title,
          resources: payloadResources,
        ),
      );
      final safeLesson = lesson.title
          .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
          .trim()
          .replaceAll(' ', '_');
      final finalPath = await TeachingPackExportFileSaver().save(
        source: source,
        dialogTitle: 'Share teaching pack',
        fileName:
            'EduSheet_${safeLesson.isEmpty ? 'Teaching_Pack' : safeLesson}.edtp',
      );
      if (finalPath == null || !mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teaching Pack saved. Share the .edtp file with another teacher or device.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teaching Pack could not be created. Check that all attached files are available.',
          ),
        ),
      );
    }
  }

  Future<void> _importPack(
    LessonPlan targetLesson, {
    String? sourcePath,
  }) async {
    try {
      String? source;
      if (sourcePath != null) {
        source = await File(sourcePath).readAsString();
      } else {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Open EduSheet Teaching Pack',
          type: FileType.custom,
          allowedExtensions: const [TeachingPackCodec.fileExtension],
          withData: true,
        );
        final picked = result?.files.single;
        if (picked == null || !mounted) return;
        source = picked.bytes != null
            ? utf8.decode(picked.bytes!)
            : picked.path != null
            ? await File(picked.path!).readAsString()
            : null;
      }
      if (source == null) {
        throw const FormatException('Teaching Pack could not be read.');
      }
      final pack = const TeachingPackCodec().decode(source);
      if (!mounted) return;
      final capabilities = ref.read(teachingPlannerCapabilitiesProvider);
      if (!capabilities.allows(TeachingPlannerCapability.bulkOperations)) {
        await showPremiumGateDialog(
          context,
          title: 'Premium Teaching Pack import',
          message:
              'This Teaching Pack was opened and validated. Premium is required only to add its resources to a lesson; existing lessons and resources remain available.',
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.inventory_2_outlined),
          title: const Text('Add this Teaching Pack?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pack.sourceClassName} • ${pack.sourceSubjectName} • ${pack.sourceChapterTitle}',
                ),
                const SizedBox(height: 6),
                Text(
                  pack.sourceLessonTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Text(
                  '${pack.resources.length} resource${pack.resources.length == 1 ? '' : 's'} will be copied into “${targetLesson.title}”. Your existing resources stay unchanged.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add resources'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final store = ref.read(teachingResourceFileStoreProvider);
      final imported = <TeachingResource>[];
      final writtenIds = <String>[];
      final now = DateTime.now().toUtc();
      try {
        for (final payload in pack.resources) {
          final sourceResource = payload.resource;
          final id = const Uuid().v4();
          String? relativePath;
          if (sourceResource.kind == TeachingResourceKind.file) {
            final bytes = payload.fileBytes;
            if (bytes == null) {
              throw const FormatException(
                'Teaching Pack file content is missing.',
              );
            }
            final blob = await store.writeManagedBlob(
              fileName: sourceResource.originalFileName ?? sourceResource.title,
              bytes: bytes,
            );
            relativePath = blob.relativePath;
            writtenIds.add(id);
          }
          imported.add(
            TeachingResource(
              id: id,
              lessonPlanId: targetLesson.id,
              kind: sourceResource.kind,
              role: sourceResource.role,
              title: sourceResource.title,
              body: sourceResource.body,
              url: sourceResource.url,
              originalFileName: sourceResource.originalFileName,
              mimeType: sourceResource.mimeType,
              fileOwnership: TeachingResourceFileOwnership.managed,
              localRelativePath: relativePath,
              externalFilePath: null,
              sizeBytes: sourceResource.kind == TeachingResourceKind.file
                  ? payload.fileBytes?.length
                  : sourceResource.sizeBytes,
              contentSha256: sourceResource.kind == TeachingResourceKind.file &&
                      payload.fileBytes != null
                  ? store.sha256ForBytes(payload.fileBytes!)
                  : sourceResource.contentSha256,
              linkedSmartDocumentId: sourceResource.linkedSmartDocumentId,
              geometryJson: sourceResource.geometryJson,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        final ok = await ref
            .read(teachingPlannerProvider.notifier)
            .importTeachingResources(
              lessonPlanId: targetLesson.id,
              resources: imported,
            );
        if (!ok) {
          for (final id in writtenIds) {
            await store.deleteResourceFiles(id);
          }
        }
        _showSaveResult(
          ok,
          success: '${imported.length} teaching resources added.',
        );
      } catch (_) {
        for (final id in writtenIds) {
          await store.deleteResourceFiles(id);
        }
        rethrow;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This Teaching Pack could not be imported. Your current lesson was kept unchanged.',
          ),
        ),
      );
    }
  }

  void _showSaveResult(bool ok, {required String success}) {
    if (!mounted) return;
    final message = ok
        ? success
        : ref.read(teachingPlannerProvider).errorMessage ??
              'Teaching workspace could not save this change.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.lesson,
    required this.resourceCount,
    required this.layer,
  });
  final LessonPlan lesson;
  final int resourceCount;
  final CurriculumLayerDescriptor layer;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tone: TeachingPlannerTone.teal,
      tint: true,
      borderRadius: TeachingPlannerDesign.radiusHero,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < TeachingPlannerBreakpoints.medium;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const TeachingPlannerIconBadge(
                    icon: Icons.inventory_2_outlined,
                    tone: TeachingPlannerTone.teal,
                    size: 46,
                    iconSize: 24,
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready-to-teach desk',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.teal,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space4),
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TeachingPlannerDesign.space12),
              Text(
                'Keep exactly what you need for class here: notes, PDFs, images, videos, links, math and geometry.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                  height: 1.4,
                ),
              ),
              if (layer.isOfficial) ...[
                const SizedBox(height: TeachingPlannerDesign.space10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: colors.teal,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${layer.sourceSchool == null ? 'Official lesson plan' : 'Official lesson plan from ${layer.sourceSchool}'}. The master definition stays protected; your progress, reflection, notes and added resources are your working layer.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
          final count = TeachingPlannerPill(
            label: '$resourceCount resources',
            icon: Icons.attach_file_rounded,
            tone: TeachingPlannerTone.teal,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: TeachingPlannerDesign.space14),
                count,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: TeachingPlannerDesign.space20),
              count,
            ],
          );
        },
      ),
    );
  }
}

class _LessonPicker extends StatelessWidget {
  const _LessonPicker({
    required this.lessons,
    required this.value,
    required this.onChanged,
  });
  final List<LessonPlan> lessons;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Lesson in focus',
            subtitle: 'Switch workspace without leaving this screen.',
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Which lesson are you preparing?',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
            items: lessons
                .map(
                  (lesson) => DropdownMenuItem<String>(
                    value: lesson.id,
                    child: Text(
                      lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNote,
    required this.onMath,
    required this.onFile,
    required this.onLink,
    required this.onGeometry,
  });
  final VoidCallback onNote;
  final VoidCallback onMath;
  final VoidCallback onFile;
  final VoidCallback onLink;
  final VoidCallback onGeometry;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        'Note',
        Icons.note_add_outlined,
        onNote,
        TeachingPlannerTone.primary,
      ),
      _ActionData(
        'Math note',
        Icons.functions_rounded,
        onMath,
        TeachingPlannerTone.purple,
      ),
      _ActionData(
        'File / media',
        Icons.attach_file_rounded,
        onFile,
        TeachingPlannerTone.teal,
      ),
      _ActionData(
        'Link',
        Icons.link_rounded,
        onLink,
        TeachingPlannerTone.orange,
      ),
      _ActionData(
        'Geometry',
        Icons.architecture_rounded,
        onGeometry,
        TeachingPlannerTone.coral,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TeachingPlannerSectionHeader(
          title: 'Add material',
          subtitle: 'Use only the resource types needed for this lesson.',
          icon: Icons.add_circle_outline_rounded,
        ),
        const SizedBox(height: TeachingPlannerDesign.space10),
        for (var index = 0; index < actions.length; index++) ...[
          TeachingPlannerActionTile(
            icon: actions[index].icon,
            label: actions[index].label,
            onTap: actions[index].onTap,
            tone: actions[index].tone,
          ),
          if (index != actions.length - 1)
            const SizedBox(height: TeachingPlannerDesign.space8),
        ],
      ],
    );
  }
}

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({
    required this.resources,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.canEdit,
  });
  final List<TeachingResource> resources;
  final ValueChanged<TeachingResource> onOpen;
  final ValueChanged<TeachingResource> onEdit;
  final ValueChanged<TeachingResource> onArchive;
  final bool Function(TeachingResource resource) canEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= TeachingPlannerBreakpoints.extraWide
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const gap = TeachingPlannerDesign.space12;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in resources)
              SizedBox(
                width: width,
                child: _ResourceCard(
                  item: item,
                  onOpen: () => onOpen(item),
                  onEdit: canEdit(item) ? () => onEdit(item) : null,
                  onArchive: canEdit(item) ? () => onArchive(item) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.item,
    required this.onOpen,
    this.onEdit,
    this.onArchive,
  });
  final TeachingResource item;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final tone = _toneForResource(item);
    return TeachingPlannerSurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeachingPlannerIconBadge(icon: _iconFor(item), tone: tone),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onEdit != null || onArchive != null)
                PopupMenuButton<String>(
                  tooltip: 'Resource actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'archive') onArchive?.call();
                  },
                  itemBuilder: (_) => [
                    if (item.kind != TeachingResourceKind.file &&
                        onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onArchive != null)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Remove from lesson'),
                      ),
                  ],
                )
              else
                const Tooltip(
                  message: 'Official curriculum resource',
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          Text(
            _resourceSummary(item),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Wrap(
            spacing: TeachingPlannerDesign.space8,
            runSpacing: TeachingPlannerDesign.space8,
            children: [
              TeachingPlannerPill(label: _kindLabel(item), tone: tone),
              if (item.kind == TeachingResourceKind.file)
                TeachingPlannerPill(
                  label: item.fileOwnership ==
                          TeachingResourceFileOwnership.linkedExternal
                      ? 'Linked original'
                      : 'EduSheet copy',
                ),
              TeachingPlannerPill(label: _roleLabel(item.role)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeachingPackCard extends StatelessWidget {
  const _TeachingPackCard({
    required this.lesson,
    required this.resourceCount,
    required this.onExport,
    required this.onImport,
  });
  final LessonPlan lesson;
  final int resourceCount;
  final VoidCallback? onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tone: TeachingPlannerTone.purple,
      tint: true,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < TeachingPlannerBreakpoints.medium;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeachingPlannerSectionHeader(
                icon: Icons.inventory_2_outlined,
                title: 'Shareable Teaching Pack',
                subtitle:
                    'Package this lesson’s real resources into one .edtp file. The receiving teacher chooses where to add it; nothing is silently replaced.',
              ),
              const SizedBox(height: TeachingPlannerDesign.space10),
              Text(
                '$resourceCount resources in “${lesson.title}”.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          );
          final buttons = Wrap(
            alignment: WrapAlignment.end,
            spacing: TeachingPlannerDesign.space10,
            runSpacing: TeachingPlannerDesign.space10,
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Open .edtp'),
              ),
              FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share this pack'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: TeachingPlannerDesign.space16),
                buttons,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: text),
              const SizedBox(width: TeachingPlannerDesign.space20),
              Flexible(flex: 2, child: buttons),
            ],
          );
        },
      ),
    );
  }
}

class _NoteResourceSheet extends ConsumerStatefulWidget {
  const _NoteResourceSheet({required this.mathFirst, this.initial});
  final bool mathFirst;
  final TeachingResource? initial;

  @override
  ConsumerState<_NoteResourceSheet> createState() => _NoteResourceSheetState();
}

class _NoteResourceSheetState extends ConsumerState<_NoteResourceSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _bodyFocus = FocusNode();
  late TeachingResourceRole _role;
  bool _openedMath = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _body = TextEditingController(text: widget.initial?.body ?? '');
    _role = widget.initial?.role ?? TeachingResourceRole.teachInClass;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mathFirst && !_openedMath) {
      _openedMath = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bodyFocus.requestFocus();
        ref
            .read(mathKeyboardControllerProvider.notifier)
            .showMathKeyboardFor(_body, _bodyFocus);
      });
    }
    return _EditorShell(
      title: widget.initial != null
          ? 'Edit teaching note'
          : (widget.mathFirst ? 'Add math teaching note' : 'Add teaching note'),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Note title'),
        ),
        const SizedBox(height: 12),
        MathKeyboardField(
          controller: _body,
          focusNode: _bodyFocus,
          builder: (context, focusNode, isMathActive) => TextField(
            controller: _body,
            focusNode: focusNode,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'What should the teacher explain?',
              hintText:
                  'Key explanation, examples, formula steps, questions to ask…',
              suffixIcon: IconButton(
                tooltip: isMathActive
                    ? 'Math keyboard active'
                    : 'Open Math Keyboard',
                onPressed: () => ref
                    .read(mathKeyboardControllerProvider.notifier)
                    .showMathKeyboardFor(_body, focusNode),
                icon: const Icon(Icons.functions_rounded),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RolePicker(
          value: _role,
          onChanged: (value) => setState(() => _role = value),
        ),
      ],
      onSave: () {
        if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
        Navigator.pop(
          context,
          _TextResourceDraft(
            title: _title.text.trim(),
            value: _body.text.trim(),
            role: _role,
          ),
        );
      },
    );
  }
}

class _LinkResourceSheet extends StatefulWidget {
  const _LinkResourceSheet({this.initial});
  final TeachingResource? initial;
  @override
  State<_LinkResourceSheet> createState() => _LinkResourceSheetState();
}

class _LinkResourceSheetState extends State<_LinkResourceSheet> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late TeachingResourceRole _role;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _url = TextEditingController(text: widget.initial?.url ?? '');
    _role = widget.initial?.role ?? TeachingResourceRole.reference;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.initial == null
          ? 'Add teaching link'
          : 'Edit teaching link',
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Link title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'https://…',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _RolePicker(
          value: _role,
          onChanged: (value) => setState(() => _role = value),
        ),
      ],
      onSave: () {
        final uri = Uri.tryParse(_url.text.trim());
        if (_title.text.trim().isEmpty ||
            uri == null ||
            !(uri.isScheme('http') || uri.isScheme('https'))) {
          return;
        }
        Navigator.pop(
          context,
          _TextResourceDraft(
            title: _title.text.trim(),
            value: _url.text.trim(),
            role: _role,
          ),
        );
      },
    );
  }
}

class _EditorShell extends StatelessWidget {
  const _EditorShell({
    required this.title,
    required this.children,
    required this.onSave,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final editing = title.toLowerCase().startsWith('edit');
    return TeachingPlannerSheetFrame(
      title: title,
      subtitle:
          'This resource stays attached to the selected lesson and is kept inside the local Teaching Planner workspace.',
      icon: Icons.inventory_2_outlined,
      action: FilledButton.icon(
        onPressed: onSave,
        icon: const Icon(Icons.check_rounded),
        label: Text(editing ? 'Save changes' : 'Add to lesson'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.value, required this.onChanged});
  final TeachingResourceRole value;
  final ValueChanged<TeachingResourceRole> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TeachingResourceRole>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Use this as'),
      items: TeachingResourceRole.values
          .map(
            (role) =>
                DropdownMenuItem(value: role, child: Text(_roleLabel(role))),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _NoLessons extends StatelessWidget {
  const _NoLessons({required this.onPlanLesson, required this.incomingPack});
  final VoidCallback onPlanLesson;
  final bool incomingPack;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerResponsiveContent(
      maxWidth: 620,
      child: TeachingPlannerEmptyState(
        icon: Icons.inventory_2_outlined,
        title: incomingPack
            ? 'Teaching Pack ready — create a lesson first'
            : 'Create a lesson first',
        message: incomingPack
            ? 'EduSheet opened the Teaching Pack safely. Create a lesson, then open the .edtp file again and choose where its resources should be added.'
            : 'Teaching materials live inside lessons, so every note or file stays connected to what you are going to teach.',
        actionLabel: 'Plan a lesson',
        onAction: onPlanLesson,
        tone: TeachingPlannerTone.teal,
      ),
    );
  }
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerEmptyState(
      icon: Icons.auto_awesome_outlined,
      title: 'Nothing to carry to class yet',
      message:
          'Start with a short teaching note. Add files, links, math or geometry only when you need them.',
      actionLabel: 'Add first note',
      onAction: onAdd,
      tone: TeachingPlannerTone.teal,
    );
  }
}

class _TextResourceDraft {
  const _TextResourceDraft({
    required this.title,
    required this.value,
    required this.role,
  });
  final String title;
  final String value;
  final TeachingResourceRole role;
}

class _ActionData {
  const _ActionData(this.label, this.icon, this.onTap, this.tone);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final TeachingPlannerTone tone;
}

TeachingPlannerTone _toneForResource(TeachingResource item) {
  return switch (item.kind) {
    TeachingResourceKind.note => TeachingPlannerTone.primary,
    TeachingResourceKind.file => TeachingPlannerTone.teal,
    TeachingResourceKind.link => TeachingPlannerTone.orange,
    TeachingResourceKind.paper => TeachingPlannerTone.primary,
    TeachingResourceKind.geometry => TeachingPlannerTone.purple,
    TeachingResourceKind.smartDocument => TeachingPlannerTone.purple,
  };
}

IconData _iconFor(TeachingResource item) {
  if (item.kind == TeachingResourceKind.file) {
    final mime = item.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
  return switch (item.kind) {
    TeachingResourceKind.note => Icons.sticky_note_2_outlined,
    TeachingResourceKind.file => Icons.insert_drive_file_outlined,
    TeachingResourceKind.link => Icons.link_rounded,
    TeachingResourceKind.paper => Icons.description_outlined,
    TeachingResourceKind.geometry => Icons.architecture_rounded,
    TeachingResourceKind.smartDocument => Icons.edit_note_rounded,
  };
}

String _kindLabel(TeachingResource item) {
  if (item.kind == TeachingResourceKind.file) {
    final mime = item.mimeType ?? '';
    if (mime.startsWith('image/')) return 'Image';
    if (mime.startsWith('video/')) return 'Video';
    if (mime == 'application/pdf') return 'PDF';
    return 'File';
  }
  return switch (item.kind) {
    TeachingResourceKind.note => 'Note',
    TeachingResourceKind.file => 'File',
    TeachingResourceKind.link => 'Link',
    TeachingResourceKind.paper => 'Paper',
    TeachingResourceKind.geometry => 'Geometry',
    TeachingResourceKind.smartDocument => 'Smart Document',
  };
}

String _resourceSummary(TeachingResource item) => switch (item.kind) {
  TeachingResourceKind.note => item.body ?? '',
  TeachingResourceKind.link => item.url ?? '',
  TeachingResourceKind.file => item.originalFileName ?? 'Attached file',
  TeachingResourceKind.paper => 'Linked EduSheet saved paper',
  TeachingResourceKind.geometry => 'Editable EduSheet geometry diagram',
  TeachingResourceKind.smartDocument =>
    'Linked editable Smart Editor document',
};

String _roleLabel(TeachingResourceRole role) => switch (role) {
  TeachingResourceRole.teachInClass => 'Teach in class',
  TeachingResourceRole.homework => 'Homework',
  TeachingResourceRole.worksheet => 'Worksheet',
  TeachingResourceRole.reference => 'Reference',
  TeachingResourceRole.teacherOnly => 'Teacher only',
};
