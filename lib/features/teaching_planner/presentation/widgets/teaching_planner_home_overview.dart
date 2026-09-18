import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import '../models/teaching_planner_dashboard_model.dart';
import '../navigation/teaching_planner_navigation.dart';
import 'teaching_planner_home_components.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerFocusCards extends StatelessWidget {
  const TeachingPlannerFocusCards({
    super.key,
    required this.model,
    required this.onOpenProgress,
    required this.onOpenCalendar,
  });

  final TeachingPlannerDashboardModel model;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FocusData(
        icon: Icons.checklist_rounded,
        value: model.pendingTopics.toString(),
        label: 'Topics not completed',
        tone: TeachingPlannerTone.primary,
        onTap: onOpenProgress,
      ),
      _FocusData(
        icon: Icons.warning_amber_rounded,
        value: model.insights.overdueLessons.toString(),
        label: 'Overdue lessons',
        tone: model.insights.overdueLessons > 0
            ? TeachingPlannerTone.coral
            : TeachingPlannerTone.teal,
        onTap: onOpenCalendar,
      ),
      _FocusData(
        icon: Icons.upcoming_rounded,
        value: model.insights.upcomingSevenDays.toString(),
        label: 'Lessons in next 7 days',
        tone: TeachingPlannerTone.purple,
        onTap: onOpenCalendar,
      ),
    ];

    return TeachingPlannerHomeSection(
      title: 'At a glance',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = TeachingPlannerDesign.space12;
          final columns = constraints.maxWidth >= 760 ? 3 : 1;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items
                .map(
                  (item) => SizedBox(
                    width: width,
                    child: _FocusCard(data: item),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _FocusData {
  const _FocusData({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final TeachingPlannerTone tone;
  final VoidCallback onTap;
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.data});

  final _FocusData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Row(
        children: [
          TeachingPlannerIconBadge(icon: data.icon, tone: data.tone),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space2),
                Text(
                  data.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
        ],
      ),
    );
  }
}

class TeachingPlannerClassesSection extends StatelessWidget {
  const TeachingPlannerClassesSection({
    super.key,
    required this.classes,
    required this.isLoading,
    required this.onCreateClass,
    required this.onOpenSyllabus,
  });

  final List<TeachingPlannerDashboardClass> classes;
  final bool isLoading;
  final VoidCallback onCreateClass;
  final VoidCallback onOpenSyllabus;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerHomeSection(
      title: 'My classes',
      trailing: classes.isNotEmpty
          ? TextButton(onPressed: onOpenSyllabus, child: const Text('Manage'))
          : null,
      child: isLoading && classes.isEmpty
          ? const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          : classes.isEmpty
          ? TeachingPlannerSurfaceCard(
              tint: true,
              tone: TeachingPlannerTone.primary,
              padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
              constraints: const BoxConstraints(minHeight: 170),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TeachingPlannerIconBadge(
                    icon: Icons.school_outlined,
                    tone: TeachingPlannerTone.primary,
                    size: 50,
                    iconSize: 27,
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space10),
                  Text(
                    'No classes yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space4),
                  Text(
                    'Create your first class, then build its syllabus and lessons.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space12),
                  FilledButton.icon(
                    onPressed: onCreateClass,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create class'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const spacing = TeachingPlannerDesign.space12;
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: classes
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _ClassCard(item: item, onTap: onOpenSyllabus),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.onTap});

  final TeachingPlannerDashboardClass item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Row(
        children: [
          TeachingPlannerIconBadge(
            icon: Icons.school_rounded,
            tone: TeachingPlannerTone.teal,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  [
                    if (item.academicYear != null) item.academicYear!,
                    '${item.subjectCount} ${item.subjectCount == 1 ? 'subject' : 'subjects'}',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
        ],
      ),
    );
  }
}

class TeachingPlannerMoreTools extends StatelessWidget {
  const TeachingPlannerMoreTools({super.key, required this.onOpenDestination});

  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerHomeSection(
      title: 'More tools',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = TeachingPlannerDesign.space12;
          final stacked = constraints.maxWidth < 560;
          final width = stacked
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing) / 2;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: width,
                child: _ToolTile(
                  key: const ValueKey('planner-action-workspace'),
                  destination: TeachingPlannerDestination.workspace,
                  tone: TeachingPlannerTone.teal,
                  onTap: () =>
                      onOpenDestination(TeachingPlannerDestination.workspace),
                ),
              ),
              SizedBox(
                width: width,
                child: _ToolTile(
                  key: const ValueKey('planner-action-insights-backup'),
                  destination: TeachingPlannerDestination.insightsBackup,
                  tone: TeachingPlannerTone.purple,
                  onTap: () => onOpenDestination(
                    TeachingPlannerDestination.insightsBackup,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    super.key,
    required this.destination,
    required this.tone,
    required this.onTap,
  });

  final TeachingPlannerDestination destination;
  final TeachingPlannerTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Row(
        children: [
          TeachingPlannerIconBadge(icon: destination.icon, tone: tone),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.shortLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  destination.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
        ],
      ),
    );
  }
}

class TeachingPlannerDashboardError extends StatelessWidget {
  const TeachingPlannerDashboardError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusLarge,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: TeachingPlannerDesign.space10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
