import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/application/saved_paper_eds_service.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/eds_import/application/eds_import_router.dart';
import 'package:edusheet/features/eds_import/domain/eds_import_inspection.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_merge_engine.dart';
import 'package:edusheet/features/teaching_planner/application/curriculum_package_import_service.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_backup_restore_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/premium/application/premium_controller.dart';
import 'package:edusheet/features/premium/domain/freemium_policy.dart';
import 'package:edusheet/features/premium/presentation/widgets/premium_gate_dialog.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EdsImportCenterScreen extends ConsumerStatefulWidget {
  const EdsImportCenterScreen({
    super.key,
    this.initialFilePath,
    this.initialDisplayName,
  });

  final String? initialFilePath;
  final String? initialDisplayName;

  @override
  ConsumerState<EdsImportCenterScreen> createState() =>
      _EdsImportCenterScreenState();
}

class _EdsImportCenterScreenState extends ConsumerState<EdsImportCenterScreen> {
  EdsImportInspection? _inspection;
  String? _source;
  String? _fileName;
  String? _errorMessage;
  String? _successMessage;
  bool _selectedImportAllowed = true;
  String? _selectedImportBlockedReason;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialFile());
    }
  }

  Future<void> _loadInitialFile() async {
    final path = widget.initialFilePath;
    if (path == null || _busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final source = await File(path).readAsString();
      await _inspectSource(
        source,
        widget.initialDisplayName ?? path.split(Platform.pathSeparator).last,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inspection = null;
        _source = null;
        _fileName = null;
        _selectedImportAllowed = true;
        _selectedImportBlockedReason = null;
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import EduSheet file',
        type: FileType.custom,
        allowedExtensions: const [EdsUnifiedContainer.fileExtension],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      final path = file.path;
      final source = bytes != null
          ? utf8.decode(bytes)
          : path != null
          ? await File(path).readAsString()
          : null;
      if (source == null) {
        throw const FormatException(
          'The selected .eds file could not be read.',
        );
      }

      await _inspectSource(source, file.name);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inspection = null;
        _source = null;
        _fileName = null;
        _selectedImportAllowed = true;
        _selectedImportBlockedReason = null;
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _inspectSource(String source, String fileName) async {
    final router = EdsImportRouter(
      paperRepository: ref.read(paperRepositoryProvider),
    );
    final inspection = await router.inspect(source);
    if (!mounted) return;
    var importAllowed = true;
    String? blockedReason;
    if (inspection is PlannerBackupEdsImportInspection) {
      final capabilities = ref.read(teachingPlannerCapabilitiesProvider);
      importAllowed = capabilities.allows(
        TeachingPlannerCapability.plannerBackupAndRestore,
      );
      if (!importAllowed) {
        blockedReason =
            'Teaching Planner backup import is unavailable with the current access level.';
      }
    }
    setState(() {
      _inspection = inspection;
      _source = source;
      _fileName = fileName;
      _selectedImportAllowed = importAllowed;
      _selectedImportBlockedReason = blockedReason;
      _errorMessage = null;
    });
  }

  Future<void> _importSelected() async {
    final inspection = _inspection;
    final source = _source;
    if (_busy ||
        inspection == null ||
        source == null ||
        !inspection.canImport ||
        !_selectedImportAllowed) {
      return;
    }

    if (inspection is PaperEdsImportInspection) {
      await _importPaper(inspection);
      return;
    }
    if (inspection is PlannerBackupEdsImportInspection) {
      await _importPlanner(inspection);
      return;
    }
    if (inspection is CurriculumPackageEdsImportInspection) {
      await _importCurriculum(inspection);
    }
  }

  Future<void> _importPaper(PaperEdsImportInspection inspection) async {
    final paperInspection = inspection.paperInspection;
    final mode = await showDialog<SavedPaperImportMode>(
      context: context,
      builder: (context) {
        final paper = paperInspection.package.paper;
        return AlertDialog(
          icon: const Icon(Icons.description_outlined),
          title: const Text('Import to Saved Papers?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
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
                const SizedBox(height: 10),
                if (paperInspection.sameLineagePapers.isEmpty)
                  const Text(
                    'No matching paper lineage exists on this device. EduSheet can add this paper safely.',
                  )
                else if (paperInspection.canReplace)
                  Text(
                    'A matching local lineage exists at revision ${paperInspection.replaceTarget!.revision}. Add as new keeps both copies; replace updates only that matching lineage.',
                  )
                else
                  Text(
                    '${paperInspection.replaceBlockedReason} Add as new keeps the existing paper unchanged.',
                  ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EduSheet never silently overwrites a Saved Paper.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (paperInspection.canReplace)
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
        );
      },
    );
    if (mode == null || !mounted) {
      return;
    }

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
        if (!mounted) return;
        await showPremiumGateDialog(
          context,
          title: 'Free paper limit reached',
          message:
              'This EduSheet file is valid and stays available. Premium is needed only to add another Saved Paper; replacing a newer matching lineage remains available.',
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final service = SavedPaperEdsService(
        paperRepository: ref.read(paperRepositoryProvider),
      );
      final result = await service.importInspected(
        paperInspection,
        mode: mode,
        maximumSavedPaperCount: maximumSavedPaperCount,
      );
      ref.invalidate(savedPapersProvider);
      await ref.read(savedPapersProvider.future);
      if (!mounted) {
        return;
      }
      final message = mode == SavedPaperImportMode.replaceSameLineage
          ? '“${result.paper.title}” updated from its matching lineage.'
          : '“${result.paper.title}” added safely to Saved Papers.';
      setState(() => _successMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importPlanner(
    PlannerBackupEdsImportInspection inspection,
  ) async {
    final capabilities = ref.read(teachingPlannerCapabilitiesProvider);
    if (!capabilities.allows(
      TeachingPlannerCapability.plannerBackupAndRestore,
    )) {
      if (mounted) {
        setState(() {
          _selectedImportAllowed = false;
          _selectedImportBlockedReason =
              'Teaching Planner backup import is unavailable with the current access level.';
          _errorMessage = _selectedImportBlockedReason;
        });
      }
      return;
    }

    final workspace = inspection.payload.workspace;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.swap_horiz_rounded),
        title: const Text('Replace current Teaching Planner?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This package passed validation. Importing a planner backup replaces the current Teaching Planner workspace on this device.',
              ),
              const SizedBox(height: 12),
              Text(
                '${workspace.activeClassCount} class(es) · ${workspace.activeSubjectCount} subject(s) · ${workspace.activeLessonPlans.length} lesson(s) · ${inspection.payload.paperSnapshots.length} linked paper(s)',
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Export the current planner first if you may need to return to it later.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Open & replace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final service = TeachingPlannerBackupRestoreService(
        paperRepository: ref.read(paperRepositoryProvider),
        resourceFileStore: ref.read(teachingResourceFileStoreProvider),
      );
      final currentWorkspace = ref.read(teachingPlannerProvider).workspace;
      final result = await service.restore(
        payload: inspection.payload,
        currentWorkspace: currentWorkspace,
        saveWorkspace: (workspace, mergeState, syncState) => ref
            .read(teachingPlannerProvider.notifier)
            .restoreWorkspaceWithSyncMetadata(workspace, mergeState, syncState),
      );
      if (result.saved) {
        ref.invalidate(curriculumMergeStateProvider);
        ref.invalidate(savedPapersProvider);
      }
      if (!mounted) {
        return;
      }

      final message = result.saved
          ? 'Teaching Planner imported successfully.${inspection.payload.paperSnapshots.isEmpty ? '' : ' ${result.restoredPaperCount} paper(s) restored, ${result.reusedPaperCount} reused, ${result.conflictCopyCount} conflict copy/copies created.'}'
          : ref.read(teachingPlannerProvider).errorMessage ??
                'Teaching Planner could not be restored. Existing data was kept.';
      setState(() {
        if (result.saved) {
          _successMessage = message;
        } else {
          _errorMessage = message;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importCurriculum(
    CurriculumPackageEdsImportInspection inspection,
  ) async {
    final capabilities = ref.read(teachingPlannerCapabilitiesProvider);
    if (!capabilities.allows(TeachingPlannerCapability.bulkOperations)) {
      await showPremiumGateDialog(
        context,
        title: 'Premium curriculum merge',
        message:
            'This EduSheet curriculum file was opened and validated. Premium is required only to merge this new curriculum pack; your existing planner remains fully available.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final service = CurriculumPackageImportService(
      plannerRepository: ref.read(teachingPlannerRepositoryProvider),
      paperRepository: ref.read(paperRepositoryProvider),
      resourceFileStore: ref.read(teachingResourceFileStoreProvider),
    );

    CurriculumPackageDryRun dryRun;
    try {
      dryRun = await service.dryRun(inspection.preview);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = _friendlyError(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final plan = dryRun.plan;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.merge_type_rounded),
        title: const Text('Merge this curriculum safely?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EduSheet matches official items by canonical origin and revision. Existing teacher-created items are not deleted, and teacher progress/lesson notes stay local.',
              ),
              const SizedBox(height: 14),
              Text(
                '${plan.addedCount} new · ${plan.updatedCount} official update(s) · ${plan.unchangedCount} unchanged · ${plan.staleCount} older item(s) ignored',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (plan.conflicts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${plan.conflicts.length} local change conflict(s) detected. EduSheet will preserve those local changes instead of silently overwriting them.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final conflict in plan.conflicts.take(3))
                  Padding(
                    padding: const EdgeInsets.only(left: 27, bottom: 5),
                    child: Text('• ${conflict.message}'),
                  ),
                if (plan.conflicts.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 27),
                    child: Text(
                      '+ ${plan.conflicts.length - 3} more preserved conflict(s)',
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Package absence is not treated as deletion in this phase, so unrelated local work and teacher-added resources remain untouched.',
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
            icon: const Icon(Icons.merge_rounded),
            label: const Text('Merge safely'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final result = await service.import(inspection.preview);
      await ref.read(teachingPlannerProvider.notifier).load();
      ref.invalidate(curriculumMergeStateProvider);
      ref.invalidate(savedPapersProvider);
      try {
        await ref.read(savedPapersProvider.future);
      } catch (_) {
        // The merge is already committed. A UI refresh problem must not be
        // reported as an import rollback or imply that no data changed.
      }
      if (!mounted) return;
      final message =
          'Curriculum merged safely: ${result.plan.addedCount} new, ${result.plan.updatedCount} updated, ${result.plan.conflicts.length} local conflict(s) preserved.';
      setState(() => _successMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Import EduSheet File')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          final copy = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'One .eds file, the correct destination',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'EduSheet reads the package first, validates its type, and shows what it contains before anything is imported.',
                              ),
                            ],
                          );
                          final button = FilledButton.icon(
                            onPressed: _busy ? null : _pickFile,
                            icon: const Icon(Icons.file_open_outlined),
                            label: Text(
                              _inspection == null
                                  ? 'Choose .eds file'
                                  : 'Choose another file',
                            ),
                          );
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                copy,
                                const SizedBox(height: 18),
                                button,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: copy),
                              const SizedBox(width: 20),
                              button,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      icon: Icons.error_outline_rounded,
                      text: _errorMessage!,
                      color: scheme.error,
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      icon: Icons.check_circle_outline_rounded,
                      text: _successMessage!,
                      color: scheme.primary,
                    ),
                  ],
                  if (_inspection != null) ...[
                    const SizedBox(height: 18),
                    _InspectionCard(
                      fileName: _fileName ?? 'EduSheet file.eds',
                      inspection: _inspection!,
                      busy: _busy,
                      executionAllowed: _selectedImportAllowed,
                      blockedReason: _selectedImportBlockedReason,
                      onImport: _importSelected,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _SafetyCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is FormatException ||
        error is StateError ||
        error is CurriculumMergeException) {
      return error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
    }
    return 'EduSheet could not import this file safely. No local data was changed.';
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({
    required this.fileName,
    required this.inspection,
    required this.busy,
    required this.executionAllowed,
    required this.blockedReason,
    required this.onImport,
  });

  final String fileName;
  final EdsImportInspection inspection;
  final bool busy;
  final bool executionAllowed;
  final String? blockedReason;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = _details(inspection);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(_iconFor(inspection.contentType)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection.title.trim().isEmpty
                            ? _labelFor(inspection.contentType)
                            : inspection.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(fileName, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _TypeChip(label: _labelFor(inspection.contentType)),
              ],
            ),
            const SizedBox(height: 18),
            _InfoLine(label: 'Target', value: inspection.destinationLabel),
            _InfoLine(
              label: 'Package',
              value: inspection.isLegacy
                  ? 'Legacy Teaching Planner v${(inspection as PlannerBackupEdsImportInspection).payload.version}'
                  : 'EduSheet universal .eds v4',
            ),
            for (final entry in details.entries)
              _InfoLine(label: entry.key, value: entry.value),
            const SizedBox(height: 16),
            if (inspection is UnsupportedEdsImportInspection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'This package type is recognized, but its importer is not available in this EduSheet build.',
                ),
              )
            else if (inspection is CurriculumPackageEdsImportInspection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.merge_type_rounded, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Origin-aware merge is available. EduSheet will preview local conflicts before changing the Teaching Planner and will not infer deletions from missing package items.',
                      ),
                    ),
                  ],
                ),
              )
            else if (!executionAllowed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        blockedReason ??
                            'This import action is not available with the current Teaching Planner access level.',
                      ),
                    ),
                  ],
                ),
              )
            else
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Validation passed. EduSheet has not changed local data yet.',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: !inspection.canImport || !executionAllowed || busy
                    ? null
                    : onImport,
                icon: Icon(
                  inspection is PlannerBackupEdsImportInspection
                      ? Icons.swap_horiz_rounded
                      : Icons.download_done_rounded,
                ),
                label: Text(
                  !inspection.canImport
                      ? 'Importer not available yet'
                      : !executionAllowed
                      ? 'Import unavailable'
                      : 'Import to ${inspection.destinationLabel}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, String> _details(EdsImportInspection inspection) {
    switch (inspection) {
      case PaperEdsImportInspection():
        final package = inspection.paperInspection.package;
        final paper = package.paper;
        final metadata = package.manifest.metadata;
        return <String, String>{
          'School': paper.schoolName.trim().isEmpty
              ? 'Not specified'
              : paper.schoolName,
          'Contains':
              '${metadata['sectionCount'] ?? paper.sections.length} section(s) · ${metadata['questionCount'] ?? '—'} question(s) · ${metadata['assetCount'] ?? package.snapshot.assets.length} embedded asset(s)',
          'Revision': '${paper.revision}',
        };
      case PlannerBackupEdsImportInspection():
        final workspace = inspection.payload.workspace;
        final attachmentCount = inspection.payload.resourceFiles.length;
        return <String, String>{
          'Contains':
              '${workspace.activeClassCount} class(es) · ${workspace.activeSubjectCount} subject(s) · ${workspace.activeTopicCount} topic(s) · ${workspace.activeLessonPlans.length} lesson(s)',
          'Portable content':
              '$attachmentCount attached file(s) · ${inspection.payload.paperSnapshots.length} linked paper(s)',
        };
      case CurriculumPackageEdsImportInspection():
        final manifest = inspection.preview.manifest;
        final details = _curriculumDetails(manifest);
        final assignment = inspection.preview.payload.assignment;
        final assignedTo = assignment?.assignedTo;
        if (assignedTo != null) {
          details['Assigned to'] = assignedTo;
        }
        if (assignment != null) {
          details['Mode'] = assignment.editable
              ? 'Editable teacher assignment'
              : 'Read-only assignment intent';
          final note = assignment.note?.trim();
          if (note != null && note.isNotEmpty) {
            details['Assignment note'] = note;
          }
        }
        return details;
      case UnsupportedEdsImportInspection():
        return _curriculumDetails(inspection.manifest!);
    }
  }

  static Map<String, String> _curriculumDetails(EdsPackageManifest manifest) {
    final metadata = manifest.metadata;
    final details = <String, String>{};
    final school = _firstMetadataText(metadata, const <String>[
      'sourceSchool',
      'schoolName',
    ]);
    final academicYear = _firstMetadataText(metadata, const <String>[
      'academicYear',
      'academicYearName',
    ]);
    if (school != null) details['From'] = school;
    if (academicYear != null) details['Academic year'] = academicYear;
    final className = _firstMetadataText(metadata, const <String>['className']);
    final subjectName = _firstMetadataText(metadata, const <String>[
      'subjectName',
    ]);
    final target = <String>[?className, ?subjectName];
    if (target.isNotEmpty) details['Target'] = target.join(' → ');
    final counts = <String>[];
    _appendMetadataCount(counts, metadata, 'classCount', 'class');
    _appendMetadataCount(counts, metadata, 'subjectCount', 'subject');
    _appendMetadataCount(counts, metadata, 'unitCount', 'unit');
    _appendMetadataCount(counts, metadata, 'chapterCount', 'chapter');
    _appendMetadataCount(counts, metadata, 'topicCount', 'topic');
    _appendMetadataCount(counts, metadata, 'lessonCount', 'lesson');
    _appendMetadataCount(counts, metadata, 'resourceCount', 'resource');
    _appendMetadataCount(counts, metadata, 'paperCount', 'paper');
    if (counts.isNotEmpty) details['Contains'] = counts.join(' · ');
    final attachments = metadata['attachmentCount'];
    if (attachments != null) {
      details['Attachments'] = '$attachments';
    }
    details['Schema'] = 'v${manifest.schemaVersion}';
    details['Revision'] = '${manifest.revision}';
    return details;
  }

  static String? _firstMetadataText(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static void _appendMetadataCount(
    List<String> output,
    Map<String, dynamic> metadata,
    String key,
    String label,
  ) {
    final raw = metadata[key];
    final count = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (count == null || count < 0) {
      return;
    }
    final unit = count == 1 ? label : '${label}s';
    output.add('$count $unit');
  }

  static String _labelFor(EdsContentType type) {
    switch (type) {
      case EdsContentType.paper:
        return 'Saved Paper';
      case EdsContentType.chapterPack:
        return 'Chapter Pack';
      case EdsContentType.subjectPack:
        return 'Subject Pack';
      case EdsContentType.syllabus:
        return 'Syllabus';
      case EdsContentType.teacherPack:
        return 'Teacher Pack';
      case EdsContentType.schoolCurriculum:
        return 'School Curriculum';
      case EdsContentType.plannerBackup:
        return 'Planner Backup';
    }
  }

  static IconData _iconFor(EdsContentType type) {
    switch (type) {
      case EdsContentType.paper:
        return Icons.description_outlined;
      case EdsContentType.chapterPack:
        return Icons.menu_book_outlined;
      case EdsContentType.subjectPack:
        return Icons.library_books_outlined;
      case EdsContentType.syllabus:
        return Icons.account_tree_outlined;
      case EdsContentType.teacherPack:
        return Icons.assignment_ind_outlined;
      case EdsContentType.schoolCurriculum:
        return Icons.school_outlined;
      case EdsContentType.plannerBackup:
        return Icons.calendar_month_outlined;
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.security_rounded),
                SizedBox(width: 10),
                Text(
                  'Import safety',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'EduSheet validates package type and structure before import. Saved Papers default to Add as new, while full Teaching Planner backups always require explicit confirmation before replacing the local planner.',
            ),
          ],
        ),
      ),
    );
  }
}
