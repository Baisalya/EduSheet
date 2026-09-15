import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/planner_insights_service.dart';
import '../../data/teaching_planner_backup_codec.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_resource.dart';
import '../providers/teaching_planner_provider.dart';

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
      TeachingPlannerCapability.richExportAndBackup,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & backup'),
        actions: [
          IconButton(
            tooltip: 'Refresh planner data',
            onPressed: () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = (constraints.maxWidth * 0.04)
                .clamp(12.0, 32.0)
                .toDouble();
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PageIntro(insights: insights),
                      const SizedBox(height: 16),
                      _ResponsiveMetricGrid(insights: insights),
                      const SizedBox(height: 16),
                      if (canUseAdvanced)
                        _AdvancedInsights(insights: insights)
                      else
                        const _LockedCard(
                          title: 'Advanced teaching insights',
                          message:
                              'Completion and period-efficiency insights are available with Teaching Planner Pro.',
                        ),
                      const SizedBox(height: 20),
                      _SectionHeading(
                        icon: Icons.devices_rounded,
                        title: 'Move or protect your planner',
                        subtitle:
                            'One .eds file carries the complete Teaching Planner workspace between Android and Windows.',
                      ),
                      const SizedBox(height: 12),
                      _BackupWorkspace(
                        enabled: canBackup,
                        insights: insights,
                        onExport: () => _exportBackup(context, ref),
                        onRestore: () => _restoreBackup(context, ref),
                      ),
                      const SizedBox(height: 16),
                      const _SafetyGuide(),
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

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    try {
      final store = ref.read(teachingResourceFileStoreProvider);
      final resourceFiles = <String, List<int>>{};
      for (final resource in workspace.resources) {
        if (resource.kind.name != 'file') continue;
        final relativePath = resource.localRelativePath;
        if (relativePath == null || !await store.exists(relativePath)) {
          throw FileSystemException(
            'Attached teaching file is missing: ${resource.originalFileName ?? resource.title}',
          );
        }
        resourceFiles[resource.id] = await store.readBytes(relativePath);
      }
      final source = const TeachingPlannerBackupCodec().encode(
        workspace,
        resourceFiles: resourceFiles,
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
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose EduSheet planner file',
        type: FileType.custom,
        allowedExtensions: const [
          TeachingPlannerBackupCodec.fileExtension,
          'json',
        ],
        withData: true,
      );
      final file = result?.files.single;
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
      var workspace = payload.workspace;
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
                ),
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

      final store = ref.read(teachingResourceFileStoreProvider);
      final currentWorkspace = ref.read(teachingPlannerProvider).workspace;
      final rollbackBytes = <String, List<int>>{};
      final rollbackNames = <String, String>{};
      final newlyWritten = <String>[];
      try {
        final restoredResources = <TeachingResource>[];
        for (final resource in workspace.resources) {
          if (resource.kind.name != 'file') {
            restoredResources.add(resource);
            continue;
          }
          final bytes = payload.resourceFiles[resource.id];
          if (bytes == null) {
            throw const FormatException(
              'This planner backup references an attached file that is not embedded in the .eds file.',
            );
          }
          final current = currentWorkspace.resourceById(resource.id);
          if (current?.localRelativePath != null &&
              await store.exists(current!.localRelativePath)) {
            rollbackBytes[resource.id] = await store.readBytes(
              current.localRelativePath!,
            );
            rollbackNames[resource.id] =
                current.originalFileName ?? current.title;
          }
          final relativePath = await store.writeBytes(
            resourceId: resource.id,
            fileName: resource.originalFileName ?? resource.title,
            bytes: bytes,
          );
          newlyWritten.add(resource.id);
          restoredResources.add(
            resource.copyWith(
              localRelativePath: relativePath,
              sizeBytes: bytes.length,
            ),
          );
        }
        workspace = workspace.copyWith(resources: restoredResources);
        final saved = await ref
            .read(teachingPlannerProvider.notifier)
            .restoreWorkspace(workspace);
        if (!saved) {
          for (final id in newlyWritten) {
            final old = rollbackBytes[id];
            if (old != null) {
              await store.writeBytes(
                resourceId: id,
                fileName: rollbackNames[id] ?? 'resource.bin',
                bytes: old,
              );
            } else {
              await store.deleteResourceFiles(id);
            }
          }
        }
        if (!context.mounted) return;
        final message = saved
            ? 'Planner opened successfully.'
            : ref.read(teachingPlannerProvider).errorMessage ??
                  'Planner could not be restored.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      } catch (_) {
        for (final id in newlyWritten) {
          final old = rollbackBytes[id];
          if (old != null) {
            await store.writeBytes(
              resourceId: id,
              fileName: rollbackNames[id] ?? 'resource.bin',
              bytes: old,
            );
          } else {
            await store.deleteResourceFiles(id);
          }
        }
        rethrow;
      }
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Teaching overview',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'See what is moving, what needs attention, and keep your planner safe.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insights.activeLessons == 0
                      ? 'Create lessons in Lesson Planner and your teaching insights will appear here automatically.'
                      : 'Everything below is calculated from your current syllabus, lessons and recorded teaching progress.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _AnimatedRing(
            value: insights.lessonCompletionRate,
            label: 'Lessons',
            diameter: 112,
          ),
        ],
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
        final columns = constraints.maxWidth >= 900
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
              'Create one portable .eds file with the complete Teaching Planner. Keep it as a backup or send it to your other device.',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: secondary
            ? scheme.surfaceContainerLow
            : scheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: secondary
              ? scheme.outlineVariant
              : scheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            eyebrow,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.verified_user_outlined
                    : Icons.lock_outline_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  enabled
                      ? footer
                      : 'Portable backup is available with Teaching Planner Pro.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
  });
  final int classes;
  final int topics;
  final int lessons;

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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}
