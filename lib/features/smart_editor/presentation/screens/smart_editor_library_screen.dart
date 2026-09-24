import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_file_opener.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SmartEditorLibraryScreen extends ConsumerWidget {
  const SmartEditorLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(smartDocumentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Editor'),
        actions: [
          IconButton(
            key: const Key('smart-editor-import-docx'),
            tooltip: 'Import Word document',
            onPressed: () => _importDocx(context, ref),
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            key: const Key('smart-editor-new-top'),
            tooltip: 'New blank document',
            onPressed: () => _createDocument(context, ref),
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('smart-editor-new'),
        onPressed: () => _createDocument(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New document'),
      ),
      body: documents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SmartEditorLibraryMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not load documents',
          message: error.toString(),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(smartDocumentsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _SmartEditorLibraryMessage(
              icon: Icons.edit_note_rounded,
              title: 'Create your first free document',
              message:
                  'Type like a normal Word document. Smart mode keeps tools simple; use / or Ctrl+K for fast commands, and add editable Math or Geometry whenever needed. No section, question or marks structure is required.',
              actionLabel: 'New blank document',
              onAction: () => _createDocument(context, ref),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth >= 900 ? 780.0 : 680.0;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final document = items[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Card(
                        child: ListTile(
                          key: ValueKey('smart-document-${document.id}'),
                          leading: const CircleAvatar(
                            child: Icon(Icons.description_outlined),
                          ),
                          title: Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Edited ${DateFormat.yMMMd().add_jm().format(document.updatedAt.toLocal())}',
                          ),
                          onTap: () => _openDocument(context, ref, document),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Document actions',
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await _deleteDocument(context, ref, document);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded),
                                    SizedBox(width: 10),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _importDocx(BuildContext context, WidgetRef ref) async {
    try {
      final result = await SmartEditorDocxFileOpener().pickAndImport();
      if (result == null || !context.mounted) return;

      await ref.read(smartDocumentRepositoryProvider).save(result.document);
      try {
        await ref
            .read(smartEditorRecoveryStoreProvider)
            .clear(result.document.id);
      } catch (_) {
        // A successful import is authoritative; stale session recovery is
        // best-effort cleanup only.
      }
      ref.invalidate(smartDocumentsProvider);
      if (!context.mounted) return;

      if (result.warnings.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.nativeRoundTrip
                ? 'EduSheet document restored'
                : 'Word import notes'),
            content: SingleChildScrollView(
              child: Text(result.warnings.map((item) => '• $item').join('\n\n')),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SmartEditorScreen(document: result.document),
        ),
      );
      ref.invalidate(smartDocumentsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not import Word document: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createDocument(BuildContext context, WidgetRef ref) async {
    final document = SmartDocument.blank();
    await ref.read(smartDocumentRepositoryProvider).save(document);
    ref.invalidate(smartDocumentsProvider);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SmartEditorScreen(document: document),
      ),
    );
    ref.invalidate(smartDocumentsProvider);
  }

  Future<void> _openDocument(
    BuildContext context,
    WidgetRef ref,
    SmartDocument document,
  ) async {
    var documentToOpen = document;
    SmartDocument? recovery;
    try {
      recovery = await ref
          .read(smartEditorRecoveryStoreProvider)
          .newerSnapshotFor(document);
    } catch (_) {
      // A damaged journal must never block opening the last primary save.
    }
    if (recovery != null) {
      documentToOpen = recovery;
      var promoted = false;
      try {
        await ref.read(smartDocumentRepositoryProvider).save(recovery);
        promoted = true;
        ref.invalidate(smartDocumentsProvider);
      } catch (_) {
        // Keep the journal and still open the recovered in-memory snapshot.
      }
      if (promoted) {
        try {
          await ref.read(smartEditorRecoveryStoreProvider).clear(document.id);
        } catch (_) {
          // The promoted repository copy is authoritative now.
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovered unsaved Smart Editor changes.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SmartEditorScreen(document: documentToOpen),
      ),
    );
    ref.invalidate(smartDocumentsProvider);
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    SmartDocument document,
  ) async {
    try {
      await ref.read(teachingPlannerProvider.notifier).load();
    } catch (_) {
      // The notifier exposes any load failure through its state below.
    }
    if (!context.mounted) return;
    final plannerState = ref.read(teachingPlannerProvider);
    if (plannerState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teaching Planner links could not be checked safely, so this document was not deleted.',
          ),
        ),
      );
      return;
    }
    final linkedResources = plannerState.workspace.resources
        .where(
          (item) =>
              !item.isArchived &&
              item.kind == TeachingResourceKind.smartDocument &&
              item.linkedSmartDocumentId == document.id,
        )
        .toList(growable: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          linkedResources.isEmpty
              ? 'Delete document?'
              : 'Delete document everywhere?',
        ),
        content: Text(
          linkedResources.isEmpty
              ? '“${document.title}” will be removed from Smart Editor. This does not affect Saved Papers.'
              : '“${document.title}” is linked in ${linkedResources.length} Teaching Planner location${linkedResources.length == 1 ? '' : 's'}. Delete removes those planner links too. Use Remove from syllabus inside Teaching Planner if you only want to unlink it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              linkedResources.isEmpty ? 'Delete' : 'Delete everywhere',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final planner = ref.read(teachingPlannerProvider.notifier);
    for (final resource in linkedResources) {
      final removed = await planner.archiveTeachingResource(resource.id);
      if (!removed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A Teaching Planner link could not be removed safely. The Smart Document was kept.',
              ),
            ),
          );
        }
        return;
      }
    }

    await ref.read(smartDocumentRepositoryProvider).delete(document.id);
    try {
      await ref.read(smartEditorRecoveryStoreProvider).clear(document.id);
    } catch (_) {
      // The primary document is already deleted; stale recovery cleanup is
      // best-effort and can be retried on a later launch.
    }
    ref.invalidate(smartDocumentsProvider);
  }
}

class _SmartEditorLibraryMessage extends StatelessWidget {
  const _SmartEditorLibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
