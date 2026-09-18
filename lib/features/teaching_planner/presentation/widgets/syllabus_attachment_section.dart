import 'package:flutter/material.dart';

import '../../application/teaching_resource_file_metadata.dart';
import '../../domain/models/teaching_resource.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import 'teaching_planner_shared_components.dart';

class SyllabusAttachmentSection extends StatelessWidget {
  const SyllabusAttachmentSection({
    super.key,
    required this.resources,
    this.onCreatePaper,
    this.onAttachSavedPaper,
    this.createPaperEnabled = true,
    this.attachSavedPaperEnabled = true,
    required this.onAddFiles,
    required this.onOpen,
    required this.onRemove,
  });

  final List<TeachingResource> resources;
  final VoidCallback? onCreatePaper;
  final VoidCallback? onAttachSavedPaper;
  final bool createPaperEnabled;
  final bool attachSavedPaperEnabled;
  final VoidCallback onAddFiles;
  final ValueChanged<TeachingResource> onOpen;
  final ValueChanged<TeachingResource> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('syllabus-attachments-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KeyedSubtree(
          key: ValueKey('syllabus-resources-papers-section'),
          child: TeachingPlannerSectionHeader(
            title: 'Resources & Papers',
          subtitle:
              'Create or attach an EduSheet paper here, or keep Word, PDF, images and other teaching files with this syllabus item.',
            icon: Icons.folder_copy_outlined,
          ),
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = <Widget>[
              FilledButton.icon(
                key: const ValueKey('syllabus-create-paper-button'),
                onPressed: createPaperEnabled ? onCreatePaper : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Paper'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('syllabus-attach-saved-paper-button'),
                onPressed: attachSavedPaperEnabled ? onAttachSavedPaper : null,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Attach Saved Paper'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('syllabus-add-file-button'),
                onPressed: onAddFiles,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Add files'),
              ),
            ];
            if (constraints.maxWidth < TeachingPlannerBreakpoints.compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    actions[index],
                    if (index != actions.length - 1)
                      const SizedBox(height: TeachingPlannerDesign.space8),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: TeachingPlannerDesign.space8,
              runSpacing: TeachingPlannerDesign.space8,
              children: actions,
            );
          },
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        if (resources.isEmpty)
          const TeachingPlannerSurfaceCard(
            tint: true,
            tone: TeachingPlannerTone.neutral,
            padding: EdgeInsets.all(TeachingPlannerDesign.space14),
            child: Row(
              children: [
                TeachingPlannerIconBadge(
                  icon: Icons.folder_open_outlined,
                  tone: TeachingPlannerTone.neutral,
                  size: 36,
                  iconSize: 18,
                ),
                SizedBox(width: TeachingPlannerDesign.space10),
                Expanded(
                  child: Text(
                    'No papers or files here yet. You can add them when you need them.',
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              const gap = TeachingPlannerDesign.space10;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final resource in resources)
                    SizedBox(
                      width: width,
                      child: resource.kind == TeachingResourceKind.paper
                          ? _PaperResourceCard(
                              resource: resource,
                              onOpen: () => onOpen(resource),
                              onRemove: () => onRemove(resource),
                            )
                          : _AttachmentCard(
                              resource: resource,
                              onOpen: () => onOpen(resource),
                              onRemove: () => onRemove(resource),
                            ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _PaperResourceCard extends StatelessWidget {
  const _PaperResourceCard({
    required this.resource,
    required this.onOpen,
    required this.onRemove,
  });

  final TeachingResource resource;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      key: ValueKey('syllabus-paper-${resource.linkedPaperId}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
      child: Row(
        children: [
          const TeachingPlannerIconBadge(
            icon: Icons.description_outlined,
            tone: TeachingPlannerTone.primary,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  'EduSheet paper • Saved Papers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open paper',
            onPressed: onOpen,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Paper actions',
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove from syllabus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.resource,
    required this.onOpen,
    required this.onRemove,
  });

  final TeachingResource resource;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final category = TeachingResourceFileMetadata.categoryFor(
      fileName: resource.originalFileName ?? resource.title,
      mimeType: resource.mimeType,
    );
    final tone = _toneForCategory(category);
    return TeachingPlannerSurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
      child: Row(
        children: [
          TeachingPlannerIconBadge(
            icon: _iconForCategory(category),
            tone: tone,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.originalFileName ?? resource.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  '${_categoryLabel(category)} • ${_formatBytes(resource.sizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open file',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'File actions',
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove from syllabus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

TeachingPlannerTone _toneForCategory(TeachingResourceFileCategory category) {
  return switch (category) {
    TeachingResourceFileCategory.image => TeachingPlannerTone.teal,
    TeachingResourceFileCategory.pdf => TeachingPlannerTone.coral,
    TeachingResourceFileCategory.video => TeachingPlannerTone.purple,
    TeachingResourceFileCategory.audio => TeachingPlannerTone.orange,
    TeachingResourceFileCategory.document => TeachingPlannerTone.primary,
    TeachingResourceFileCategory.spreadsheet => TeachingPlannerTone.teal,
    TeachingResourceFileCategory.presentation => TeachingPlannerTone.purple,
    TeachingResourceFileCategory.text => TeachingPlannerTone.primary,
    TeachingResourceFileCategory.other => TeachingPlannerTone.neutral,
  };
}

IconData _iconForCategory(TeachingResourceFileCategory category) {
  return switch (category) {
    TeachingResourceFileCategory.image => Icons.image_outlined,
    TeachingResourceFileCategory.pdf => Icons.picture_as_pdf_outlined,
    TeachingResourceFileCategory.video => Icons.movie_outlined,
    TeachingResourceFileCategory.audio => Icons.audio_file_outlined,
    TeachingResourceFileCategory.document => Icons.description_outlined,
    TeachingResourceFileCategory.spreadsheet => Icons.table_chart_outlined,
    TeachingResourceFileCategory.presentation => Icons.slideshow_outlined,
    TeachingResourceFileCategory.text => Icons.article_outlined,
    TeachingResourceFileCategory.other => Icons.insert_drive_file_outlined,
  };
}

String _categoryLabel(TeachingResourceFileCategory category) {
  return switch (category) {
    TeachingResourceFileCategory.image => 'Image',
    TeachingResourceFileCategory.pdf => 'PDF',
    TeachingResourceFileCategory.video => 'Video',
    TeachingResourceFileCategory.audio => 'Audio',
    TeachingResourceFileCategory.document => 'Document',
    TeachingResourceFileCategory.spreadsheet => 'Spreadsheet',
    TeachingResourceFileCategory.presentation => 'Presentation',
    TeachingResourceFileCategory.text => 'Text',
    TeachingResourceFileCategory.other => 'File',
  };
}

String _formatBytes(int? bytes) {
  if (bytes == null) return 'Unknown size';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}
