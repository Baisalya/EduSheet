import 'package:flutter/material.dart';

import '../../application/teaching_resource_file_metadata.dart';
import '../../domain/models/teaching_resource.dart';

class SyllabusAttachmentSection extends StatelessWidget {
  const SyllabusAttachmentSection({
    super.key,
    required this.resources,
    required this.onAddFiles,
    required this.onOpen,
    required this.onRemove,
  });

  final List<TeachingResource> resources;
  final VoidCallback onAddFiles;
  final ValueChanged<TeachingResource> onOpen;
  final ValueChanged<TeachingResource> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('syllabus-attachments-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attachments',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add images, PDFs, documents or videos. EduSheet keeps a private copy and includes it in portable .eds files.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: onAddFiles,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Add files'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (resources.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              'No files attached yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final resource in resources)
                    SizedBox(
                      width: width,
                      child: _AttachmentCard(
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
    final theme = Theme.of(context);
    final category = TeachingResourceFileMetadata.categoryFor(
      fileName: resource.originalFileName ?? resource.title,
      mimeType: resource.mimeType,
    );
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: Icon(_iconForCategory(category)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.originalFileName ?? resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_categoryLabel(category)} • ${_formatBytes(resource.sizeBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open attachment',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Attachment actions',
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  }
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
        ),
      ),
    );
  }
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
  if (bytes == null) {
    return 'Unknown size';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}
