import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';

import '../../application/planner_insights_service.dart';
import '../../application/teaching_planner_backup_restore_service.dart';
import '../../data/portable_paper_snapshot.dart';
import '../../data/teaching_planner_backup_codec.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/offline_sync_state.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/repositories/curriculum_merge_repository.dart';
import '../../domain/repositories/offline_sync_repository.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/teaching_planner_page_shell.dart';
import '../widgets/teaching_planner_responsive_content.dart';
import '../widgets/teaching_planner_shared_components.dart';

class PlannerInsightsBackupScreen extends ConsumerWidget {
  const PlannerInsightsBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teachingPlannerProvider);
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final insights = const PlannerInsightsService().calculate(state.workspace);
    final canUseAdvanced = capabilities.allows(
      TeachingPlannerCapability.advancedDashboards,
    );
    final canBackup = capabilities.allows(
      TeachingPlannerCapability.plannerBackupAndRestore,
    );

    return TeachingPlannerPageShell(
      title: 'Insights & backup',
      currentDestination: TeachingPlannerDestination.insightsBackup,
      actions: [
        IconButton(
          tooltip: 'Refresh planner data',
          onPressed: () => ref.read(teachingPlannerProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
      ],
      body: TeachingPlannerResponsiveContent(
        maxWidth: 1240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageIntro(insights: insights),
            const SizedBox(height: TeachingPlannerDesign.space16),
            _ResponsiveMetricGrid(insights: insights),
            const SizedBox(height: TeachingPlannerDesign.space16),
            if (canUseAdvanced)
              _AdvancedInsights(insights: insights)
            else
              const _LockedCard(
                title: 'Advanced teaching insights',
                message:
                    'Completion and period-efficiency insights are available with Teaching Planner Pro.',
              ),
            const SizedBox(height: TeachingPlannerDesign.space20),
            const TeachingPlannerSectionHeader(
              icon: Icons.devices_rounded,
              title: 'Move or protect your planner',
              subtitle:
                  'One .eds file carries the planner, attached files, and linked EduSheet papers between Android and Windows.',
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            _BackupWorkspace(
              enabled: canBackup,
              insights: insights,
              onExport: () => _exportBackup(context, ref),
              onRestore: () => _restoreBackup(context, ref),
            ),
            const SizedBox(height: TeachingPlannerDesign.space16),
            const _SafetyGuide(),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    var workspace = ref.read(teachingPlannerProvider).workspace;
    var mergeState = CurriculumMergeState.empty();
    var syncState = OfflineSyncState.uninitialized();
    try {
      final repository = ref.read(teachingPlannerRepositoryProvider);
      final syncRepository = switch (repository) {
        OfflineSyncRepository value => value,
        _ => null,
      };
      if (syncRepository != null) {
        final snapshot = await syncRepository.loadOfflineSyncSnapshot();
        workspace = snapshot.workspace;
        mergeState = snapshot.mergeState;
        syncState = snapshot.syncState;
      } else {
        final mergeRepository = switch (repository) {
          CurriculumMergeRepository value => value,
          _ => null,
        };
        if (mergeRepository != null) {
          final snapshot = await mergeRepository.loadCurriculumMergeSnapshot();
          workspace = snapshot.workspace;
          mergeState = snapshot.mergeState;
        }
      }
      final store = ref.read(teachingResourceFileStoreProvider);
      final resourceFiles = <String, List<int>>{};
      for (final resource in workspace.resources) {
        if (resource.kind != TeachingResourceKind.file) continue;
        final relativePath = resource.localRelativePath;
        if (relativePath == null || !await store.exists(relativePath)) {
          throw FileSystemException(
            'Attached teaching file is missing: ${resource.originalFileName ?? resource.title}',
          );
        }
        resourceFiles[resource.id] = await store.readBytes(relativePath);
      }

      final paperRepository = ref.read(paperRepositoryProvider);
      final savedPapers = await paperRepository.getAllPapers();
      final papersById = {for (final paper in savedPapers) paper.id: paper};
      final linkedPaperIds = workspace.resources
          .where((resource) => resource.kind == TeachingResourceKind.paper)
          .map((resource) => resource.linkedPaperId?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final paperSnapshots = <String, PortablePaperSnapshot>{};
      for (final paperId in linkedPaperIds) {
        final paper = papersById[paperId];
        if (paper == null) {
          throw FormatException(
            'Linked EduSheet paper is missing on this device: $paperId',
          );
        }
        paperSnapshots[paperId] = await PortablePaperSnapshot.capture(paper);
      }

      final source = const TeachingPlannerBackupCodec().encode(
        workspace,
        resourceFiles: resourceFiles,
        paperSnapshots: paperSnapshots,
        mergeState: mergeState,
        syncState: syncState,
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save EduSheet planner file',
        fileName: 'EduSheet_Teaching_Planner.eds',
        type: FileType.custom,
        allowedExtensions: const [TeachingPlannerBackupCodec.fileExtension],
      );
      if (path == null || !context.mounted) return;
      final portablePath =
          path.toLowerCase().endsWith(
            '.${TeachingPlannerBackupCodec.fileExtension}',
          )
          ? path
          : '$path.${TeachingPlannerBackupCodec.fileExtension}';
      await File(portablePath).writeAsString(source, flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Planner file saved. Share the .eds file to move this workspace to another device.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Planner file could not be saved. Your data was not changed.',
          ),
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose EduSheet planner file',
        type: FileType.custom,
        allowedExtensions: const [
          TeachingPlannerBackupCodec.fileExtension,
          'json',
        ],
        withData: true,
      );
      final file = pickerResult?.files.single;
      if (file == null || !context.mounted) return;
      final source = file.bytes != null
          ? utf8.decode(file.bytes!)
          : file.path != null
          ? await File(file.path!).readAsString()
          : null;
      if (source == null) {
        throw const FormatException('Planner file could not be read.');
      }
      final payload = const TeachingPlannerBackupCodec().decodePayload(source);
      final workspace = payload.workspace;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.swap_horiz_rounded),
          title: const Text('Replace current planner?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The selected EduSheet file passed validation. Opening it will replace the Teaching Planner currently on this device.',
                ),
                const SizedBox(height: 14),
                _RestoreSummary(
                  classes: workspace.activeClassCount,
                  topics: workspace.activeTopicCount,
                  lessons: workspace.activeLessonPlans.length,
                  papers: payload.paperSnapshots.length,
                ),
                if (payload.paperSnapshots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.copy_all_outlined, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked papers will be restored too. If a different saved paper already exists on this device, EduSheet keeps it and restores the incoming one as a separate copy.',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: export your current planner first if you may need to return to it later.',
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
      if (confirmed != true || !context.mounted) return;

      final service = TeachingPlannerBackupRestoreService(
        paperRepository: ref.read(paperRepositoryProvider),
        resourceFileStore: ref.read(teachingResourceFileStoreProvider),
      );
      final currentWorkspace = ref.read(teachingPlannerProvider).workspace;
      final restoreResult = await service.restore(
        payload: payload,
        currentWorkspace: currentWorkspace,
        saveWorkspace: (workspace, mergeState, syncState) => ref
            .read(teachingPlannerProvider.notifier)
            .restoreWorkspaceWithSyncMetadata(workspace, mergeState, syncState),
      );
      if (restoreResult.saved) {
        ref.invalidate(curriculumMergeStateProvider);
        ref.invalidate(savedPapersProvider);
      }
      if (!context.mounted) return;
      final paperNote = restoreResult.saved && payload.paperSnapshots.isNotEmpty
          ? ' ${restoreResult.restoredPaperCount} paper(s) restored, '
                '${restoreResult.reusedPaperCount} reused, '
                '${restoreResult.conflictCopyCount} conflict copy/copies created.'
          : '';
      final message = restoreResult.saved
          ? 'Planner opened successfully.$paperNote'
          : ref.read(teachingPlannerProvider).errorMessage ??
                'Planner could not be restored.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is not a valid EduSheet planner file. Your current planner was kept unchanged.',
          ),
        ),
      );
    }
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.insights});
  final PlannerInsights insights;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tone: TeachingPlannerTone.primary,
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
                    icon: Icons.auto_graph_rounded,
                    size: 46,
                    iconSize: 24,
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teaching overview',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space4),
                        Text(
                          'See what is moving and keep your planner safe',
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
                insights.activeLessons == 0
                    ? 'Create lessons in Lesson Planner and your teaching insights will appear here automatically.'
                    : 'Everything below is calculated from your current syllabus, lessons and recorded teaching progress.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                  height: 1.4,
                ),
              ),
            ],
          );
          final ring = _AnimatedRing(
            value: insights.lessonCompletionRate,
            label: 'Lessons',
            diameter: compact ? 96 : 112,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: TeachingPlannerDesign.space16),
                Align(alignment: Alignment.center, child: ring),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: TeachingPlannerDesign.space20),
              ring,
            ],
          );
        },
      ),
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  const _ResponsiveMetricGrid({required this.insights});
  final PlannerInsights insights;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        'Active lessons',
        '${insights.activeLessons}',
        Icons.menu_book_rounded,
      ),
      _MetricData(
        'Completed',
        '${insights.completedLessons}',
        Icons.task_alt_rounded,
      ),
      _MetricData(
        'Needs attention',
        '${insights.overdueLessons}',
        Icons.schedule_rounded,
      ),
      _MetricData(
        'Next 7 days',
        '${insights.upcomingSevenDays}',
        Icons.event_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= TeachingPlannerBreakpoints.twoPane
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(data: metric),
              ),
          ],
        );
      },
    );
  }
}

class _AdvancedInsights extends StatelessWidget {
  const _AdvancedInsights({required this.insights});
  final PlannerInsights insights;

  @override
  Widget build(BuildContext context) {
    final lessonVariance = insights.lessonPeriodVariance;
    final topicVariance = insights.topicPeriodVariance;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.insights_rounded,
            title: 'Progress at a glance',
            subtitle:
                'Completion and period usage from your recorded teaching data.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final rings = [
                _InsightRing(
                  label: 'Lesson completion',
                  value: insights.lessonCompletionRate,
                  detail:
                      '${insights.completedLessons} of ${insights.activeLessons} lessons',
                ),
                _InsightRing(
                  label: 'Topic completion',
                  value: insights.topicCompletionRate,
                  detail:
                      '${insights.completedTopics} of ${insights.activeTopics} topics',
                ),
              ];
              final periods = _PeriodSummary(
                lessonActual: insights.actualLessonPeriods,
                lessonPlanned: insights.plannedLessonPeriods,
                lessonVariance: lessonVariance,
                topicActual: insights.actualTopicPeriods,
                topicPlanned: insights.plannedTopicPeriods,
                topicVariance: topicVariance,
              );
              if (compact) {
                return Column(
                  children: [
                    ...rings.map(
                      (ring) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ring,
                      ),
                    ),
                    periods,
                  ],
                );
              }
              // This row lives inside the page's vertical SingleChildScrollView,
              // so its incoming maxHeight is intentionally unbounded. Stretching
              // children on the cross axis would turn that into h=Infinity and
              // crash desktop layout. Let each insight card measure its own finite
              // height instead; width is still controlled by Expanded.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: rings[0]),
                  const SizedBox(width: 12),
                  Expanded(child: rings[1]),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: periods),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BackupWorkspace extends StatelessWidget {
  const _BackupWorkspace({
    required this.enabled,
    required this.insights,
    required this.onExport,
    required this.onRestore,
  });

  final bool enabled;
  final PlannerInsights insights;
  final VoidCallback onExport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 760;
        final export = _ActionCard(
          icon: Icons.ios_share_rounded,
          eyebrow: 'STEP 1 · BACK UP OR MOVE',
          title: 'Save this planner',
          description:
              'Create one portable .eds file with the planner, attached files and linked EduSheet papers. Keep it as a backup or send it to your other device.',
          buttonLabel: 'Save .eds file',
          enabled: enabled,
          onPressed: onExport,
          footer:
              '${insights.activeLessons} lessons • ${insights.activeTopics} topics',
        );
        final restore = _ActionCard(
          icon: Icons.folder_open_rounded,
          eyebrow: 'OPEN ON THIS DEVICE',
          title: 'Open a planner file',
          description:
              'Choose an EduSheet .eds file from another phone or computer. You will see its contents and confirm before anything is replaced.',
          buttonLabel: 'Choose .eds file',
          enabled: enabled,
          onPressed: onRestore,
          footer: 'Also accepts older EduSheet .json backups',
          secondary: true,
        );
        if (!sideBySide) {
          return Column(
            children: [export, const SizedBox(height: 12), restore],
          );
        }
        // This row also sits inside the page's vertical SingleChildScrollView.
        // Its incoming maxHeight is unbounded, so cross-axis stretch would
        // convert that into h=Infinity for both action cards. Let each card
        // measure its own finite height while Expanded controls only width.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: export),
            const SizedBox(width: 14),
            Expanded(child: restore),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
    required this.footer,
    this.secondary = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final String footer;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final tone = secondary
        ? TeachingPlannerTone.teal
        : TeachingPlannerTone.primary;
    return TeachingPlannerSurfaceCard(
      tone: tone,
      tint: !secondary,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeachingPlannerIconBadge(
            icon: icon,
            tone: tone,
            size: 46,
            iconSize: 23,
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone.foreground(colors),
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space4),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space18),
          SizedBox(
            width: double.infinity,
            child: secondary
                ? OutlinedButton.icon(
                    onPressed: enabled ? onPressed : null,
                    icon: Icon(icon),
                    label: Text(buttonLabel),
                  )
                : FilledButton.icon(
                    onPressed: enabled ? onPressed : null,
                    icon: Icon(icon),
                    label: Text(buttonLabel),
                  ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                enabled
                    ? Icons.verified_user_outlined
                    : Icons.lock_outline_rounded,
                size: 16,
                color: colors.inkMuted,
              ),
              const SizedBox(width: TeachingPlannerDesign.space6),
              Expanded(
                child: Text(
                  enabled
                      ? footer
                      : 'Portable backup is unavailable with the current access level.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafetyGuide extends StatelessWidget {
  const _SafetyGuide();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '1',
        'Save',
        'Create a .eds file before changing phones, reinstalling, or making a major planner change.',
      ),
      (
        '2',
        'Share',
        'Send that single file through Drive, email, messaging, USB, or any file-sharing method you prefer.',
      ),
      (
        '3',
        'Open',
        'On the other device choose the file in EduSheet. Nothing is replaced until you confirm.',
      ),
    ];
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.shield_outlined,
            title: 'Simple and safe',
            subtitle: 'You do not need an account, server, or special folder.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 760;
              final children = items
                  .map(
                    (item) => Expanded(
                      child: _GuideStep(
                        number: item.$1,
                        title: item.$2,
                        body: item.$3,
                      ),
                    ),
                  )
                  .toList();
              if (horizontal) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    children[0],
                    const SizedBox(width: 12),
                    children[1],
                    const SizedBox(width: 12),
                    children[2],
                  ],
                );
              }
              return Column(
                children: [
                  _GuideStep(
                    number: items[0].$1,
                    title: items[0].$2,
                    body: items[0].$3,
                  ),
                  const SizedBox(height: 10),
                  _GuideStep(
                    number: items[1].$1,
                    title: items[1].$2,
                    body: items[1].$3,
                  ),
                  const SizedBox(height: 10),
                  _GuideStep(
                    number: items[2].$1,
                    title: items[2].$2,
                    body: items[2].$3,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRing extends StatelessWidget {
  const _InsightRing({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final double value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        _AnimatedRing(value: value, label: label, diameter: 104),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    required this.value,
    required this.label,
    required this.diameter,
  });
  final double value;
  final String label;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0).toDouble();
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: safeValue),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingPainter(
                value: animatedValue,
                trackColor: scheme.surfaceContainerHighest,
                progressColor: scheme.primary,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(animatedValue * 100).round()}%',
                    style: TextStyle(
                      fontSize: diameter >= 110 ? 22 : 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.trackColor,
    required this.progressColor,
  });
  final double value;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(8.0, size.shortestSide * 0.09);
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.lessonActual,
    required this.lessonPlanned,
    required this.lessonVariance,
    required this.topicActual,
    required this.topicPlanned,
    required this.topicVariance,
  });
  final int lessonActual;
  final int lessonPlanned;
  final int lessonVariance;
  final int topicActual;
  final int topicPlanned;
  final int topicVariance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Period usage',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _PeriodRow(
          label: 'Lessons',
          actual: lessonActual,
          planned: lessonPlanned,
          variance: lessonVariance,
        ),
        const Divider(height: 24),
        _PeriodRow(
          label: 'Topics',
          actual: topicActual,
          planned: topicPlanned,
          variance: topicVariance,
        ),
      ],
    ),
  );
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.label,
    required this.actual,
    required this.planned,
    required this.variance,
  });
  final String label;
  final int actual;
  final int planned;
  final int variance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final varianceText = variance > 0 ? '+$variance' : '$variance';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                '$actual actual / $planned planned',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (variance == 0 ? scheme.primary : scheme.tertiary)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$varianceText periods',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(data.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreSummary extends StatelessWidget {
  const _RestoreSummary({
    required this.classes,
    required this.topics,
    required this.lessons,
    required this.papers,
  });
  final int classes;
  final int topics;
  final int lessons;
  final int papers;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      Chip(
        avatar: const Icon(Icons.school_outlined, size: 17),
        label: Text('$classes classes'),
      ),
      Chip(
        avatar: const Icon(Icons.topic_outlined, size: 17),
        label: Text('$topics topics'),
      ),
      Chip(
        avatar: const Icon(Icons.menu_book_outlined, size: 17),
        label: Text('$lessons lessons'),
      ),
      if (papers > 0)
        Chip(
          avatar: const Icon(Icons.description_outlined, size: 17),
          label: Text('$papers linked papers'),
        ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => TeachingPlannerSectionHeader(
    icon: icon,
    title: title,
    subtitle: subtitle,
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TeachingPlannerSurfaceCard(
    padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
    child: child,
  );
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tone: TeachingPlannerTone.purple,
      tint: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeachingPlannerIconBadge(
            icon: Icons.lock_outline_rounded,
            tone: TeachingPlannerTone.purple,
          ),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
