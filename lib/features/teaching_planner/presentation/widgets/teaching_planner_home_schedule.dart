import 'package:flutter/material.dart';

import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/teaching_planner_dashboard_model.dart';
import 'teaching_planner_home_components.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerTodaySchedule extends StatelessWidget {
  const TeachingPlannerTodaySchedule({
    super.key,
    required this.lessons,
    required this.onPlanLesson,
    required this.onOpenCalendar,
    required this.onOpenLesson,
  });

  final List<TeachingPlannerDashboardLesson> lessons;
  final VoidCallback onPlanLesson;
  final VoidCallback onOpenCalendar;
  final ValueChanged<String> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeachingPlannerHomeSectionHeader(
            title: "Today's schedule",
            icon: Icons.today_rounded,
            actionLabel: 'View planner',
            onAction: onOpenCalendar,
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          if (lessons.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TeachingPlannerDesign.space18,
                vertical: TeachingPlannerDesign.space24,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSoft,
                borderRadius: BorderRadius.circular(
                  TeachingPlannerDesign.radiusLarge,
                ),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  TeachingPlannerIconBadge(
                    icon: Icons.event_note_outlined,
                    tone: TeachingPlannerTone.primary,
                    size: 48,
                    iconSize: 25,
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space10),
                  Text(
                    'No lessons scheduled today',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space4),
                  Text(
                    'Plan a syllabus-linked lesson when you are ready.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space12),
                  FilledButton.icon(
                    onPressed: onPlanLesson,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Plan lesson'),
                  ),
                ],
              ),
            )
          else
            ...lessons
                .take(4)
                .map(
                  (lesson) => _LessonRow(
                    lesson: lesson,
                    onTap: () => onOpenLesson(lesson.id),
                  ),
                ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.onTap});

  final TeachingPlannerDashboardLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);
    final tone = switch (lesson.status) {
      TeachingProgressStatus.completed => TeachingPlannerTone.teal,
      TeachingProgressStatus.inProgress => TeachingPlannerTone.primary,
      TeachingProgressStatus.skipped => TeachingPlannerTone.neutral,
      TeachingProgressStatus.rescheduled => TeachingPlannerTone.purple,
      TeachingProgressStatus.planned => TeachingPlannerTone.primary,
    };
    final accent = tone.foreground(colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: TeachingPlannerDesign.space10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('planner-home-lesson-${lesson.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            TeachingPlannerDesign.radiusLarge,
          ),
          child: Container(
            padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(
                TeachingPlannerDesign.radiusLarge,
              ),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: TeachingPlannerDesign.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space4),
                      Text(
                        '${lesson.className} • ${lesson.subjectName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space2),
                      Text(
                        '${lesson.periodLabel} • ${lesson.statusLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TeachingPlannerDesign.space8),
                Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
