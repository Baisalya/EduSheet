import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import '../models/teaching_planner_dashboard_model.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerHomeHeader extends StatelessWidget {
  const TeachingPlannerHomeHeader({
    super.key,
    required this.accessLabel,
    required this.isLoading,
    required this.onRefresh,
  });

  final String accessLabel;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusMedium,
            ),
          ),
          child: Icon(Icons.school_rounded, color: colors.primary, size: 25),
        ),
        const SizedBox(width: TeachingPlannerDesign.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teaching Planner',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space2),
              Text(
                'Plan today. Teach with clarity.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: TeachingPlannerDesign.space8),
        TeachingPlannerPill(
          label: accessLabel,
          icon: Icons.verified_outlined,
          tone: TeachingPlannerTone.primary,
        ),
        const SizedBox(width: TeachingPlannerDesign.space6),
        IconButton.filledTonal(
          key: const ValueKey('planner-home-refresh'),
          tooltip: 'Refresh Teaching Planner',
          onPressed: isLoading ? null : onRefresh,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class TeachingPlannerProgressCard extends StatelessWidget {
  const TeachingPlannerProgressCard({
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
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Container(
      key: const ValueKey('planner-home-progress-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusHero),
        border: Border.all(color: colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primarySoft,
            colors.surface,
            colors.tealSoft.withValues(alpha: .55),
          ],
          stops: const [0, .56, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 650;
            final progress = _ProgressSummary(
              model: model,
              onOpenProgress: onOpenProgress,
            );
            final nextLesson = _NextLessonSummary(
              lesson: model.nextLesson,
              onOpenCalendar: onOpenCalendar,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  progress,
                  const SizedBox(height: TeachingPlannerDesign.space16),
                  nextLesson,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: progress),
                const SizedBox(width: TeachingPlannerDesign.space18),
                Expanded(flex: 4, child: nextLesson),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.model, required this.onOpenProgress});

  final TeachingPlannerDashboardModel model;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);
    final value = model.overallCompletion.clamp(0.0, 1.0).toDouble();
    final percentage = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TeachingPlannerIconBadge(
              icon: Icons.insights_rounded,
              tone: TeachingPlannerTone.primary,
              size: 34,
              iconSize: 18,
            ),
            const SizedBox(width: TeachingPlannerDesign.space10),
            Expanded(
              child: Text(
                'Overall teaching progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TeachingPlannerDesign.space18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.surfaceStrong,
                    color: colors.teal,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percentage%',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Complete',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TeachingPlannerDesign.space18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.overallCompletionLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space6),
                  Text(
                    '${model.classCount} classes • ${model.subjectCount} subjects • ${model.lessonCount} lessons',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space8),
                  TextButton.icon(
                    key: const ValueKey('planner-action-progress'),
                    onPressed: onOpenProgress,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View progress'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NextLessonSummary extends StatelessWidget {
  const _NextLessonSummary({
    required this.lesson,
    required this.onOpenCalendar,
  });

  final TeachingPlannerDashboardLesson? lesson;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              TeachingPlannerIconBadge(
                icon: Icons.event_available_rounded,
                tone: TeachingPlannerTone.teal,
                size: 34,
                iconSize: 18,
              ),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Text(
                  'Next lesson',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          if (lesson == null) ...[
            Text(
              'Nothing scheduled yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: TeachingPlannerDesign.space4),
            Text(
              'Open the weekly planner to review or plan your teaching week.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
                height: 1.35,
              ),
            ),
          ] else ...[
            Text(
              lesson!.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: TeachingPlannerDesign.space6),
            Text(
              '${lesson!.className} • ${lesson!.subjectName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.ink),
            ),
            const SizedBox(height: TeachingPlannerDesign.space4),
            Text(
              '${_dashboardDate(lesson!.plannedDate)} • ${lesson!.periodLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: TeachingPlannerDesign.space10),
          TextButton.icon(
            key: const ValueKey('planner-action-calendar'),
            onPressed: onOpenCalendar,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Open planner'),
          ),
        ],
      ),
    );
  }
}

String _dashboardDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
