import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/application/saved_paper_eds_service.dart';
import 'package:edusheet/features/editor/data/portable/saved_paper_eds_codec.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/question_paper_export_service.dart';
import 'package:edusheet/features/premium/application/premium_controller.dart';
import 'package:edusheet/features/premium/domain/freemium_policy.dart';
import 'package:edusheet/features/premium/presentation/widgets/premium_gate_dialog.dart';
import 'package:edusheet/features/premium/presentation/widgets/premium_operation_gate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/shared/services/review_service.dart';
import 'package:edusheet/shared/services/eds_export_file_saver.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import '../providers/editor_provider.dart';
import '../widgets/paper_rename_dialog.dart';
import 'create_paper_screen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum PaperSort { dateNewest, dateOldest, titleAZ, marksHigh, marksLow }

class SavedPapersScreen extends ConsumerStatefulWidget {
  const SavedPapersScreen({super.key});

  @override
  ConsumerState<SavedPapersScreen> createState() => _SavedPapersScreenState();
}

class _SavedPapersScreenState extends ConsumerState<SavedPapersScreen> {
  String _searchQuery = '';
  PaperSort _sortBy = PaperSort.dateNewest;
  final Map<String, Paper> _paperOverrides = <String, Paper>{};

  void _showRenamedPaper(Paper paper) {
    if (!mounted) return;
    setState(() => _paperOverrides[paper.id] = paper);
  }

  Future<void> _importEdsPaper() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import EduSheet paper',
        type: FileType.custom,
        allowedExtensions: const ['eds'],
        withData: true,
      );
      final file = picked?.files.single;
      if (file == null || !mounted) return;
      final source = file.bytes != null
          ? utf8.decode(file.bytes!)
          : file.path != null
          ? await File(file.path!).readAsString()
          : null;
      if (source == null) {
        throw const FormatException(
          'The selected .eds file could not be read.',
        );
      }

      final service = SavedPaperEdsService(
        paperRepository: ref.read(paperRepositoryProvider),
      );
      final inspection = await service.inspect(source);
      if (!mounted) return;
      final paper = inspection.package.paper;
      final metadata = inspection.package.manifest.metadata;
      final sectionCount = metadata['sectionCount'] ?? paper.sections.length;
      final questionCount = metadata['questionCount'] ?? '—';
      final assetCount =
          metadata['assetCount'] ?? inspection.package.snapshot.assets.length;

      final mode = await showDialog<SavedPaperImportMode>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.inventory_2_outlined),
          title: const Text('Import EduSheet paper?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title.trim().isEmpty ? 'Untitled Paper' : paper.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'School: ${paper.schoolName.trim().isEmpty ? 'Not specified' : paper.schoolName}',
                  ),
                  Text(
                    'Contains: $sectionCount section(s) · $questionCount question(s) · $assetCount embedded asset(s)',
                  ),
                  Text('Revision: ${paper.revision}'),
                  const SizedBox(height: 14),
                  if (inspection.sameLineagePapers.isEmpty)
                    const Text(
                      'No matching paper lineage exists on this device. EduSheet will add it safely to Saved Papers.',
                    )
                  else if (inspection.canReplace)
                    Text(
                      'A matching paper lineage exists locally (revision ${inspection.replaceTarget!.revision}). You can keep both copies or replace that matching version.',
                    )
                  else
                    Text(
                      '${inspection.replaceBlockedReason} The safe option is to add this as a separate paper.',
                    ),
                  const SizedBox(height: 10),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add as new is the default. EduSheet never silently overwrites an existing Saved Paper.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (inspection.canReplace)
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  SavedPaperImportMode.replaceSameLineage,
                ),
                child: const Text('Replace matching version'),
              ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, SavedPaperImportMode.addAsNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add as new'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;

      final premium = ref.read(premiumProvider);
      final maximumSavedPaperCount = FreemiumPolicy.hasFullAccess(premium)
          ? null
          : FreemiumPolicy.freeSavedPaperLimit;
      if (mode == SavedPaperImportMode.addAsNew) {
        final savedPaperCount =
            (await ref.read(paperRepositoryProvider).getAllPapers()).length;
        if (!mounted) return;
        if (!FreemiumPolicy.canCreatePaper(
          premium: premium,
          savedPaperCount: savedPaperCount,
        )) {
          await showPremiumGateDialog(
            context,
            title: 'Free paper limit reached',
            message:
                'This EduSheet file is valid and stays available. Premium is needed only to add another Saved Paper; replacing a newer matching lineage remains available.',
          );
          return;
        }
      }

      final imported = await service.importInspected(
        inspection,
        mode: mode,
        maximumSavedPaperCount: maximumSavedPaperCount,
      );
      ref.invalidate(savedPapersProvider);
      await ref.read(savedPapersProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == SavedPaperImportMode.replaceSameLineage
                ? '“${imported.paper.title}” updated from its matching .eds lineage.'
                : '“${imported.paper.title}” added safely to Saved Papers.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not import EduSheet paper: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final papersAsync = ref.watch(savedPapersProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: const Text(
          'Saved Papers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Import EduSheet paper (.eds)',
            onPressed: _importEdsPaper,
            icon: const Icon(Icons.file_open_outlined),
          ),
          PopupMenuButton<PaperSort>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) => setState(() => _sortBy = sort),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PaperSort.dateNewest,
                child: Text('Date (Newest First)'),
              ),
              const PopupMenuItem(
                value: PaperSort.dateOldest,
                child: Text('Date (Oldest First)'),
              ),
              const PopupMenuItem(
                value: PaperSort.titleAZ,
                child: Text('Title (A-Z)'),
              ),
              const PopupMenuItem(
                value: PaperSort.marksHigh,
                child: Text('Marks (High to Low)'),
              ),
              const PopupMenuItem(
                value: PaperSort.marksLow,
                child: Text('Marks (Low to High)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by title or school...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: papersAsync.when(
              data: (papers) {
                final displayPapers = papers
                    .map((paper) => _paperOverrides[paper.id] ?? paper)
                    .toList(growable: false);
                var filtered = displayPapers.where((p) {
                  final query = _searchQuery.toLowerCase();
                  return p.title.toLowerCase().contains(query) ||
                      p.schoolName.toLowerCase().contains(query);
                }).toList();

                // Sorting logic
                switch (_sortBy) {
                  case PaperSort.dateNewest:
                    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    break;
                  case PaperSort.dateOldest:
                    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    break;
                  case PaperSort.titleAZ:
                    filtered.sort(
                      (a, b) => a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      ),
                    );
                    break;
                  case PaperSort.marksHigh:
                    filtered.sort(
                      (a, b) => b.totalMarks.compareTo(a.totalMarks),
                    );
                    break;
                  case PaperSort.marksLow:
                    filtered.sort(
                      (a, b) => a.totalMarks.compareTo(b.totalMarks),
                    );
                    break;
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.description_outlined
                              : Icons.search_off,
                          size: 64,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No saved papers yet.'
                              : 'No papers match your search.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final paper = filtered[index];
                    return _SavedPaperCard(
                      paper: paper,
                      onPaperRenamed: _showRenamedPaper,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPaperCard extends ConsumerWidget {
  final Paper paper;
  final ValueChanged<Paper> onPaperRenamed;

  const _SavedPaperCard({required this.paper, required this.onPaperRenamed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = DateFormat(
      'MMM dd, yyyy • hh:mm a',
    ).format(paper.createdAt);
    final mergeStateAsync = ref.watch(curriculumMergeStateProvider);
    final mergeState = mergeStateAsync.asData?.value;
    final protectionReady = mergeState != null;
    final officialRecord = mergeState?.replicaForLocalId('paper', paper.id);
    final officialSourceSchool = officialRecord?.sourceSchool?.trim();
    final isOfficial = officialRecord != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: protectionReady
            ? () => _openPaper(context, ref, paper, isOfficial: isOfficial)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      paper.title.isEmpty ? 'Untitled Paper' : paper.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${paper.totalMarks.toStringAsFixed(0)} Marks',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isOfficial) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: .18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          officialSourceSchool != null &&
                                  officialSourceSchool.isNotEmpty
                              ? 'Official curriculum · $officialSourceSchool'
                              : 'Official curriculum',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                paper.schoolName,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _ActionButton(
                          icon: isOfficial
                              ? Icons.copy_rounded
                              : Icons.edit_outlined,
                          label: isOfficial ? 'Teacher copy' : 'Edit',
                          color: scheme.primary,
                          onPressed: protectionReady
                              ? () => _openPaper(
                                  context,
                                  ref,
                                  paper,
                                  isOfficial: isOfficial,
                                )
                              : null,
                        ),
                        if (!isOfficial)
                          _ActionButton(
                            icon: Icons.drive_file_rename_outline_rounded,
                            label: 'Rename',
                            color: scheme.primary,
                            onPressed: protectionReady
                                ? () => _renamePaper(context, ref, paper)
                                : null,
                          ),
                        _ActionButton(
                          icon: Icons.archive_outlined,
                          label: 'Export .eds',
                          color: scheme.tertiary,
                          onPressed: () => _saveAsEds(context, ref, paper),
                        ),
                        _ActionButton(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Export PDF',
                          color: Colors.redAccent,
                          onPressed: () => _saveAsPdf(context, ref, paper),
                        ),
                        _ActionButton(
                          icon: Icons.description_outlined,
                          label: 'Export Word',
                          color: Colors.indigo,
                          onPressed: () => _saveAsWord(context, ref, paper),
                        ),
                      ],
                    ),
                  ),
                  if (isOfficial)
                    Tooltip(
                      message: 'Official curriculum papers cannot be deleted.',
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    IconButton(
                      tooltip: protectionReady
                          ? 'Delete paper'
                          : 'Checking paper protection',
                      icon: Icon(
                        Icons.delete_outline,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: protectionReady
                          ? () => _confirmDelete(context, ref, paper)
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPaper(
    BuildContext context,
    WidgetRef ref,
    Paper paper, {
    required bool isOfficial,
  }) async {
    var editable = paper;
    if (isOfficial) {
      final createCopy = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: const Text('Official paper is protected'),
          content: const Text(
            'This Saved Paper belongs to the official curriculum. EduSheet can create a separate teacher copy for your edits while keeping the official version unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep official'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Create teacher copy'),
            ),
          ],
        ),
      );
      if (createCopy != true || !context.mounted) return;

      final now = DateTime.now().toUtc();
      final copyId = const Uuid().v4();
      editable = paper.copyWith(
        id: copyId,
        originId: copyId,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        title: '${paper.title} — Teacher Copy',
      );
      try {
        final repository = ref.read(paperRepositoryProvider);
        final savedPaperCount = (await repository.getAllPapers()).length;
        if (!FreemiumPolicy.canCreatePaper(
          premium: ref.read(premiumProvider),
          savedPaperCount: savedPaperCount,
        )) {
          if (context.mounted) {
            await showPremiumGateDialog(
              context,
              title: 'Free paper limit reached',
              message:
                  'The protected official paper stays available. Premium is needed only to create this additional teacher copy.',
            );
          }
          return;
        }
        await repository.savePaper(editable);
        ref.invalidate(savedPapersProvider);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create teacher copy: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!context.mounted) return;
    }

    ref.read(editorStateProvider.notifier).loadPaper(editable);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const CreatePaperScreen()),
    );
  }

  Future<void> _renamePaper(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    final renamed = await showPaperRenameDialog(
      context,
      initialTitle: paper.title == 'New Paper' ? '' : paper.title,
    );
    final cleanTitle = renamed?.trim();
    if (cleanTitle == null || cleanTitle.isEmpty || cleanTitle == paper.title) {
      return;
    }

    final updated = paper.copyWith(title: cleanTitle);
    try {
      final repository = ref.read(paperRepositoryProvider);
      await repository.savePaper(updated);
      final persisted = (await repository.getAllPapers()).firstWhere(
        (item) => item.id == paper.id,
        orElse: () => updated,
      );
      onPaperRenamed(persisted);

      final current = ref.read(editorStateProvider);
      if (current.id == paper.id) {
        ref.read(editorStateProvider.notifier).loadPaper(persisted);
      }

      final planner = ref.read(teachingPlannerProvider.notifier);
      await planner.load();
      final plannerState = ref.read(teachingPlannerProvider);
      final linkedResources = plannerState.workspace.resources
          .where(
            (resource) =>
                !resource.isArchived &&
                resource.kind == TeachingResourceKind.paper &&
                resource.linkedPaperId == paper.id &&
                resource.title != cleanTitle,
          )
          .toList(growable: false);
      for (final resource in linkedResources) {
        await planner.updateTeachingResource(
          resource.id,
          role: resource.role,
          title: cleanTitle,
        );
      }

      // Invalidate the watched AsyncValue first, then await its fresh load.
      // Refreshing only the `.future` projection can leave the screen watching
      // the previous AsyncValue snapshot in this route/dialog transition.
      ref.invalidate(savedPapersProvider);
      await ref.read(savedPapersProvider.future);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renamed to “$cleanTitle”'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not rename paper: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Paper paper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Paper?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "${paper.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(paperRepositoryProvider).deletePaper(paper.id);
              ref.invalidate(savedPapersProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsEds(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    try {
      final repository = ref.read(paperRepositoryProvider);
      final latest = (await repository.getAllPapers()).firstWhere(
        (item) => item.id == paper.id,
        orElse: () => paper,
      );
      final service = SavedPaperEdsService(paperRepository: repository);
      final source = await service.exportPaper(latest);
      final suggestedName = SavedPaperEdsCodec.suggestedFileName(latest);
      final portablePath = await EdsExportFileSaver().save(
        source: source,
        fileName: suggestedName,
        dialogTitle: 'Save editable EduSheet paper',
      );
      if (portablePath == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Editable EduSheet paper saved: $portablePath'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save editable .eds paper: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAsPdf(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    if (!await allowPdfExport(context, ref) || !context.mounted) return;
    try {
      final file = await QuestionPaperExportService.exportPdf(
        paper: paper,
        availableTemplates: ref.read(templateProvider).all,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ReviewService.instance.recordSuccessfulExport();
      await recordPdfExport(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save PDF: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAsWord(
    BuildContext context,
    WidgetRef ref,
    Paper paper,
  ) async {
    if (!await allowWordExport(context, ref) || !context.mounted) return;
    try {
      final file = await QuestionPaperExportService.exportWord(
        paper: paper,
        availableTemplates: ref.read(templateProvider).all,
        openAfterExport: true,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word file saved: ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ReviewService.instance.recordSuccessfulExport();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save Word file: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
