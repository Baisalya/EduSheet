import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_keyboard_field.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../data/teaching_pack_codec.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../providers/teaching_planner_provider.dart';

class TeachingWorkspaceScreen extends ConsumerStatefulWidget {
  const TeachingWorkspaceScreen({super.key, this.initialLessonId});

  final String? initialLessonId;

  @override
  ConsumerState<TeachingWorkspaceScreen> createState() =>
      _TeachingWorkspaceScreenState();
}

class _TeachingWorkspaceScreenState
    extends ConsumerState<TeachingWorkspaceScreen> {
  String? _lessonId;

  @override
  void initState() {
    super.initState();
    _lessonId = widget.initialLessonId;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final lessons = workspace.activeLessonPlans;
    final selected = _selectedLesson(lessons);
    final resources = selected == null
        ? const <TeachingResource>[]
        : workspace.activeResourcesForLesson(selected.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teaching workspace'),
        actions: [
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: lessons.isEmpty
            ? _NoLessons(onPlanLesson: () => Navigator.of(context).maybePop())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final padding = (constraints.maxWidth * 0.035)
                      .clamp(12.0, 30.0)
                      .toDouble();
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WorkspaceHero(
                              lesson: selected!,
                              resourceCount: resources.length,
                            ),
                            const SizedBox(height: 16),
                            _LessonPicker(
                              lessons: lessons,
                              value: selected.id,
                              onChanged: (value) =>
                                  setState(() => _lessonId = value),
                            ),
                            const SizedBox(height: 16),
                            _QuickActions(
                              onNote: () =>
                                  _addNote(selected, mathFirst: false),
                              onMath: () => _addNote(selected, mathFirst: true),
                              onFile: () => _addFile(selected),
                              onLink: () => _addLink(selected),
                              onGeometry: () => _addGeometry(selected),
                            ),
                            const SizedBox(height: 20),
                            _SectionTitle(
                              title: 'Materials for this lesson',
                              subtitle: resources.isEmpty
                                  ? 'Add the notes, files and visuals you want ready before class.'
                                  : '${resources.length} item${resources.length == 1 ? '' : 's'} ready for teaching.',
                            ),
                            const SizedBox(height: 12),
                            if (resources.isEmpty)
                              _EmptyResources(
                                onAdd: () =>
                                    _addNote(selected, mathFirst: false),
                              )
                            else
                              _ResourceGrid(
                                resources: resources,
                                onOpen: (item) => _openResource(item),
                                onEdit: (item) => _editResource(item),
                                onArchive: (item) => _archiveResource(item),
                              ),
                            const SizedBox(height: 24),
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
                    ),
                  );
                },
              ),
      ),
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
      final files = await ref
          .read(teachingResourceFilePickerProvider)
          .pickFiles(dialogTitle: 'Add teaching material', allowMultiple: true);
      if (files.isEmpty || !mounted) return;
      final ok = await ref
          .read(teachingPlannerProvider.notifier)
          .attachTeachingFiles(
            owner: TeachingResourceOwner.lessonPlan(lesson.id),
            files: files,
            role: TeachingResourceRole.teachInClass,
          );
      final success = files.length == 1
          ? '${files.single.fileName} attached.'
          : '${files.length} files attached.';
      _showSaveResult(ok, success: success);
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
        if (uri != null)
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        break;
      case TeachingResourceKind.file:
        final path = item.localRelativePath;
        if (path == null) return;
        final file = await ref
            .read(teachingResourceFileStoreProvider)
            .resolve(path);
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This file is not available on this device. Import the Teaching Pack again if needed.',
              ),
            ),
          );
          return;
        }
        await OpenFilex.open(file.path);
        break;
      case TeachingResourceKind.geometry:
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

  Future<void> _editResource(TeachingResource item) async {
    if (item.kind == TeachingResourceKind.geometry) {
      await _openResource(item);
      return;
    }
    if (item.kind == TeachingResourceKind.file) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from this lesson?'),
        content: Text(
          '${item.title} will be archived. Attached file data is kept safely for recovery/export.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .archiveTeachingResource(item.id);
    _showSaveResult(ok, success: 'Resource archived.');
  }

  Future<void> _exportPack(
    LessonPlan lesson,
    List<TeachingResource> resources,
  ) async {
    try {
      final workspace = ref.read(teachingPlannerProvider).workspace;
      final store = ref.read(teachingResourceFileStoreProvider);
      final payloadResources = <TeachingPackResourcePayload>[];
      for (final item in resources) {
        List<int>? bytes;
        if (item.kind == TeachingResourceKind.file) {
          final path = item.localRelativePath;
          if (path == null || !await store.exists(path)) {
            throw FileSystemException(
              'Missing attached file: ${item.originalFileName ?? item.title}',
            );
          }
          bytes = await store.readBytes(path);
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
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Share teaching pack',
        fileName:
            'EduSheet_${safeLesson.isEmpty ? 'Teaching_Pack' : safeLesson}.edtp',
        type: FileType.custom,
        allowedExtensions: const [TeachingPackCodec.fileExtension],
      );
      if (path == null || !mounted) return;
      final finalPath = path.toLowerCase().endsWith('.edtp')
          ? path
          : '$path.edtp';
      await File(finalPath).writeAsString(source, flush: true);
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

  Future<void> _importPack(LessonPlan targetLesson) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open EduSheet Teaching Pack',
        type: FileType.custom,
        allowedExtensions: const [TeachingPackCodec.fileExtension],
        withData: true,
      );
      final picked = result?.files.single;
      if (picked == null || !mounted) return;
      final source = picked.bytes != null
          ? utf8.decode(picked.bytes!)
          : picked.path != null
          ? await File(picked.path!).readAsString()
          : null;
      if (source == null)
        throw const FormatException('Teaching Pack could not be read.');
      final pack = const TeachingPackCodec().decode(source);
      if (!mounted) return;
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
            if (bytes == null)
              throw const FormatException(
                'Teaching Pack file content is missing.',
              );
            relativePath = await store.writeBytes(
              resourceId: id,
              fileName: sourceResource.originalFileName ?? sourceResource.title,
              bytes: bytes,
            );
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
              localRelativePath: relativePath,
              sizeBytes: sourceResource.kind == TeachingResourceKind.file
                  ? payload.fileBytes?.length
                  : sourceResource.sizeBytes,
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
  const _WorkspaceHero({required this.lesson, required this.resourceCount});
  final LessonPlan lesson;
  final int resourceCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.78),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready-to-teach desk',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep exactly what you need for class here: notes, PDFs, images, videos, links, math and geometry.',
                ),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.attach_file_rounded, size: 18),
            label: Text('$resourceCount resources'),
          ),
        ],
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Which lesson are you preparing?',
        prefixIcon: Icon(Icons.menu_book_rounded),
        border: OutlineInputBorder(),
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
      _ActionData('Note', Icons.note_add_outlined, onNote),
      _ActionData('Math note', Icons.functions_rounded, onMath),
      _ActionData('File / media', Icons.attach_file_rounded, onFile),
      _ActionData('Link', Icons.link_rounded, onLink),
      _ActionData('Geometry', Icons.architecture_rounded, onGeometry),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 900
            ? (width - 48) / 5
            : width >= 520
            ? (width - 12) / 2
            : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: FilledButton.tonalIcon(
                  onPressed: action.onTap,
                  icon: Icon(action.icon),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(action.label),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({
    required this.resources,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });
  final List<TeachingResource> resources;
  final ValueChanged<TeachingResource> onOpen;
  final ValueChanged<TeachingResource> onEdit;
  final ValueChanged<TeachingResource> onArchive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        const gap = 12.0;
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
                  onEdit: () => onEdit(item),
                  onArchive: () => onArchive(item),
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
    required this.onEdit,
    required this.onArchive,
  });
  final TeachingResource item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(_iconFor(item)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Resource actions',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'archive') onArchive();
                    },
                    itemBuilder: (_) => [
                      if (item.kind != TeachingResourceKind.file)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _resourceSummary(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(_kindLabel(item))),
                  Chip(label: Text(_roleLabel(item.role))),
                ],
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Shareable Teaching Pack',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Principal or teacher can package this lesson’s resources into one .edtp file. The receiving teacher chooses the lesson to add it to—nothing is silently replaced.',
              ),
              const SizedBox(height: 6),
              Text(
                '$resourceCount resources in “${lesson.title}”.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );

          Widget buildButtons({required bool stacked}) {
            final openButton = OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Open .edtp'),
            );
            final shareButton = FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share this pack'),
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [openButton, const SizedBox(height: 10), shareButton],
              );
            }
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [openButton, shareButton],
            );
          }

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: text),
                const SizedBox(width: 24),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: buildButtons(stacked: constraints.maxWidth < 880),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 16),
              buildButtons(stacked: constraints.maxWidth < 520),
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
          decoration: const InputDecoration(
            labelText: 'Note title',
            border: OutlineInputBorder(),
          ),
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
              border: const OutlineInputBorder(),
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
          decoration: const InputDecoration(
            labelText: 'Link title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'https://…',
            border: OutlineInputBorder(),
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
            !(uri.isScheme('http') || uri.isScheme('https')))
          return;
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Add to lesson'),
                ),
              ),
            ],
          ),
        ),
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
      decoration: const InputDecoration(
        labelText: 'Use this as',
        border: OutlineInputBorder(),
      ),
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
  const _NoLessons({required this.onPlanLesson});
  final VoidCallback onPlanLesson;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Create a lesson first',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Teaching materials live inside lessons, so every note or file stays connected to what you are going to teach.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPlanLesson,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan a lesson'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 38),
          const SizedBox(height: 10),
          const Text(
            'Nothing to carry to class yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start with a short teaching note. Add files, links, math or geometry only when you need them.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Add first note'),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
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
  const _ActionData(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
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
    TeachingResourceKind.geometry => Icons.architecture_rounded,
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
    TeachingResourceKind.geometry => 'Geometry',
  };
}

String _resourceSummary(TeachingResource item) => switch (item.kind) {
  TeachingResourceKind.note => item.body ?? '',
  TeachingResourceKind.link => item.url ?? '',
  TeachingResourceKind.file => item.originalFileName ?? 'Attached file',
  TeachingResourceKind.geometry => 'Editable EduSheet geometry diagram',
};

String _roleLabel(TeachingResourceRole role) => switch (role) {
  TeachingResourceRole.teachInClass => 'Teach in class',
  TeachingResourceRole.homework => 'Homework',
  TeachingResourceRole.worksheet => 'Worksheet',
  TeachingResourceRole.reference => 'Reference',
  TeachingResourceRole.teacherOnly => 'Teacher only',
};
