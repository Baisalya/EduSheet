import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/weekly_planner_model.dart';
import 'teaching_planner_shared_components.dart';

class TeachingCalendarWeekProgressCard extends StatelessWidget {
  const TeachingCalendarWeekProgressCard({
    super.key,
    required this.model,
    required this.canUseSlots,
    required this.onPlanLesson,
  });

  final WeeklyPlannerModel model;
  final bool canUseSlots;
  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final percent = (model.completionRatio * 100).round();

    return Container(
      key: const ValueKey('planner-week-progress-card'),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primarySoft,
            colors.surface,
            colors.tealSoft.withValues(alpha: .56),
          ],
          stops: const [0, .56, 1],
        ),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusHero),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 270;
          final ring = _ProgressRing(percent: percent);
          final summary = _ProgressSummary(
            model: model,
            canUseSlots: canUseSlots,
            onPlanLesson: onPlanLesson,
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: ring),
                const SizedBox(height: TeachingPlannerDesign.space16),
                summary,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: TeachingPlannerDesign.space18),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return SizedBox.square(
      dimension: 102,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 94,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 9,
              color: colors.teal,
              backgroundColor: colors.surfaceStrong,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
              Text(
                'complete',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.model,
    required this.canUseSlots,
    required this.onPlanLesson,
  });

  final WeeklyPlannerModel model;
  final bool canUseSlots;
  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final hasLessons = model.totalLessons > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_graph_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                "This Week's Progress",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasLessons
              ? 'Your teaching plan is moving.'
              : 'Build your teaching week.',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colors.teal,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hasLessons
              ? '${model.completedLessons} of ${model.totalLessons} lessons completed • ${model.plannedPeriods} planned periods'
              : 'No lessons are planned for this week yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.inkMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            TeachingPlannerPill(
              icon: Icons.menu_book_rounded,
              label: '${model.totalLessons} lessons',
              tone: TeachingPlannerTone.primary,
            ),
            TeachingPlannerPill(
              icon: Icons.schedule_rounded,
              label: '${model.slottedLessons} slotted',
              tone: TeachingPlannerTone.teal,
            ),
            TeachingPlannerPill(
              icon: model.conflictLessonCount > 0
                  ? Icons.warning_amber_rounded
                  : Icons.verified_rounded,
              label: canUseSlots
                  ? '${model.conflictLessonCount} conflicts'
                  : 'Slots: Pro',
              tone: model.conflictLessonCount > 0
                  ? TeachingPlannerTone.coral
                  : TeachingPlannerTone.purple,
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('planner-week-add-lesson'),
            onPressed: onPlanLesson,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Plan lesson'),
          ),
        ),
      ],
    );
  }
}

class TeachingCalendarAgenda extends StatelessWidget {
  const TeachingCalendarAgenda({
    super.key,
    required this.day,
    required this.canUseSlots,
    required this.onSchedule,
    required this.onOpenLesson,
    required this.onPlanLesson,
  });

  final WeeklyPlannerDay day;
  final bool canUseSlots;
  final void Function(LessonPlan, bool) onSchedule;
  final ValueChanged<LessonPlan> onOpenLesson;
  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      key: const ValueKey('planner-day-agenda'),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusXLarge),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayTitle(day.date),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      day.lessonCount == 0
                          ? 'No lessons scheduled'
                          : '${day.lessonCount} lesson${day.lessonCount == 1 ? '' : 's'} • ${day.plannedPeriods} periods',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                key: const ValueKey('planner-agenda-add-lesson'),
                tooltip: 'Plan lesson',
                onPressed: onPlanLesson,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!day.hasLessons)
            _EmptyAgenda(onPlanLesson: onPlanLesson)
          else
            ...day.lessons.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _LessonTimelineCard(
                  item: item,
                  canUseSlots: canUseSlots,
                  onOpen: () => onOpenLesson(item.lesson),
                  onSchedule: () => onSchedule(item.lesson, canUseSlots),
                ),
              ),
            ),
          if (day.hasLessons) ...[
            const SizedBox(height: 2),
            _AddLessonDropZone(onPlanLesson: onPlanLesson),
          ],
        ],
      ),
    );
  }
}

class _LessonTimelineCard extends StatelessWidget {
  const _LessonTimelineCard({
    required this.item,
    required this.canUseSlots,
    required this.onOpen,
    required this.onSchedule,
  });

  final WeeklyPlannerLessonItem item;
  final bool canUseSlots;
  final VoidCallback onOpen;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final lesson = item.lesson;
    final colors = TeachingPlannerTheme.colorsOf(context);
    final conflict = item.hasConflict && canUseSlots;
    final tone = _toneForStatus(lesson.status, conflict: conflict);
    final foreground = tone.foreground(colors);
    final background = tone.background(colors);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lesson.startPeriod == null ? '—' : 'P${lesson.startPeriod}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: conflict ? colors.danger : colors.inkMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${lesson.plannedPeriods}p',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey('planner-agenda-lesson-${lesson.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: onOpen,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: foreground.withValues(alpha: .15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconForStatus(lesson.status),
                        size: 19,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.subjectName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: colors.ink,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                              if (conflict) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 17,
                                  color: colors.danger,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.className} • ${item.chapterTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: ValueKey('planner-agenda-schedule-${lesson.id}'),
                      tooltip: 'Edit schedule',
                      onPressed: onSchedule,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddLessonDropZone extends StatelessWidget {
  const _AddLessonDropZone({required this.onPlanLesson});

  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return InkWell(
      onTap: onPlanLesson,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.primary.withValues(alpha: .36),
            style: BorderStyle.solid,
          ),
          color: colors.primarySoft.withValues(alpha: .28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Add another lesson',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.onPlanLesson});

  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TeachingPlannerIconBadge(
            icon: Icons.event_available_rounded,
            tone: TeachingPlannerTone.teal,
            size: 46,
            iconSize: 24,
          ),
          const SizedBox(height: 10),
          Text(
            'This day is clear',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Plan a lesson here when you are ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.inkMuted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPlanLesson,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Plan lesson'),
          ),
        ],
      ),
    );
  }
}

TeachingPlannerTone _toneForStatus(
  TeachingProgressStatus status, {
  required bool conflict,
}) {
  if (conflict) return TeachingPlannerTone.coral;
  return switch (status) {
    TeachingProgressStatus.completed => TeachingPlannerTone.teal,
    TeachingProgressStatus.inProgress => TeachingPlannerTone.purple,
    TeachingProgressStatus.rescheduled => TeachingPlannerTone.orange,
    TeachingProgressStatus.skipped => TeachingPlannerTone.neutral,
    TeachingProgressStatus.planned => TeachingPlannerTone.primary,
  };
}

IconData _iconForStatus(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.completed => Icons.task_alt_rounded,
  TeachingProgressStatus.inProgress => Icons.play_circle_outline_rounded,
  TeachingProgressStatus.rescheduled => Icons.update_rounded,
  TeachingProgressStatus.skipped => Icons.skip_next_rounded,
  TeachingProgressStatus.planned => Icons.menu_book_rounded,
};

String _dayTitle(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}
