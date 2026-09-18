import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/progress_insights_model.dart';

class ProgressDashboard extends StatelessWidget {
  const ProgressDashboard({
    super.key,
    required this.model,
    required this.advancedEnabled,
    this.onOpenLesson,
  });

  final ProgressInsightsModel model;
  final bool advancedEnabled;
  final ValueChanged<LessonPlan>? onOpenLesson;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 980;
        final medium = width >= 680;

        final overall = _OverallProgressCard(model: model);
        final pace = _PeriodPaceCard(model: model);
        final backlog = _BacklogSummaryCard(model: model);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: overall),
                  const SizedBox(width: 14),
                  Expanded(child: pace),
                  const SizedBox(width: 14),
                  Expanded(child: backlog),
                ],
              )
            else ...[
              overall,
              const SizedBox(height: 14),
              if (medium)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pace),
                    const SizedBox(width: 14),
                    Expanded(child: backlog),
                  ],
                )
              else ...[
                pace,
                const SizedBox(height: 14),
                backlog,
              ],
            ],
            const SizedBox(height: 14),
            _SubjectProgressCard(subjects: model.subjects),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _UpcomingDeadlinesCard(
                      lessons: model.upcomingLessons,
                      onOpenLesson: onOpenLesson,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BacklogAlertsCard(
                      overdueLessons: model.overdueLessons,
                      highPriorityTopics: model.highPriorityPendingTopics,
                      onOpenLesson: onOpenLesson,
                    ),
                  ),
                ],
              )
            else ...[
              _UpcomingDeadlinesCard(
                lessons: model.upcomingLessons,
                onOpenLesson: onOpenLesson,
              ),
              const SizedBox(height: 14),
              _BacklogAlertsCard(
                overdueLessons: model.overdueLessons,
                highPriorityTopics: model.highPriorityPendingTopics,
                onOpenLesson: onOpenLesson,
              ),
            ],
            const SizedBox(height: 14),
            _TeachingFocusCard(model: model),
            const SizedBox(height: 14),
            if (advancedEnabled) ...[
              _AdvancedInsightsHeader(),
              const SizedBox(height: 10),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CompletionTrendCard(
                        lessons: model.lessons,
                        now: model.now,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _TopicStatusCard(model: model)),
                  ],
                )
              else ...[
                _CompletionTrendCard(lessons: model.lessons, now: model.now),
                const SizedBox(height: 14),
                _TopicStatusCard(model: model),
              ],
              const SizedBox(height: 14),
              _PriorityProgressCard(topics: model.topics),
            ] else
              const _LockedAdvancedInsightsCard(),
          ],
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusXLarge),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      child: child,
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.model});

  final ProgressInsightsModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const progressColor = Color(0xFF14B8A6);
    final percentage = (model.overallProgress * 100).round();

    return _DashboardCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final ring = AnimatedProgressRing(
            progress: model.overallProgress,
            color: progressColor,
            centerText: '$percentage%',
            size: compact ? 118 : 132,
            strokeWidth: 11,
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      size: 20,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Overall Progress',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                model.overallProgressLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    label:
                        '${model.insights.completedTopics}/${model.insights.activeTopics} topics',
                    icon: Icons.fact_check_outlined,
                  ),
                  _MetricPill(
                    label:
                        '${model.insights.completedLessons}/${model.insights.activeLessons} lessons',
                    icon: Icons.school_outlined,
                  ),
                  _MetricPill(
                    label: '${model.insights.overdueLessons} overdue',
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.center, child: ring),
                const SizedBox(height: 16),
                details,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 20),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PeriodPaceCard extends StatelessWidget {
  const _PeriodPaceCard({required this.model});

  final ProgressInsightsModel model;

  @override
  Widget build(BuildContext context) {
    final planned = model.insights.plannedLessonPeriods;
    final actual = model.insights.actualLessonPeriods;
    final variance = model.periodVariance;
    final progress = planned == 0 ? 0.0 : (actual / planned).clamp(0.0, 1.0);
    final color = variance < 0
        ? const Color(0xFFF59E0B)
        : const Color(0xFF2563EB);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.av_timer_rounded,
            title: 'Period pace',
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            '$actual / $planned',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            'Actual / planned lesson periods',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            variance == 0
                ? 'Teaching pace matches the plan.'
                : variance < 0
                ? '${variance.abs()} periods behind plan.'
                : '$variance periods above plan.',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _BacklogSummaryCard extends StatelessWidget {
  const _BacklogSummaryCard({required this.model});

  final ProgressInsightsModel model;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEF4444);
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.notification_important_outlined,
            title: 'Backlog alerts',
            color: color,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CountBlock(
                  value: '${model.overdueLessons.length}',
                  label: 'Overdue lessons',
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountBlock(
                  value: '${model.highPriorityPendingTopics.length}',
                  label: 'High-priority topics',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            model.overdueLessons.isEmpty &&
                    model.highPriorityPendingTopics.isEmpty
                ? 'Nothing urgent needs attention.'
                : 'Use the alerts below to decide what to teach next.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _SubjectProgressCard extends StatelessWidget {
  const _SubjectProgressCard({required this.subjects});

  final List<SubjectProgressInsight> subjects;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.menu_book_rounded,
            title: 'Subject-wise Progress',
            color: Color(0xFF2563EB),
          ),
          const SizedBox(height: 14),
          if (subjects.isEmpty)
            const _EmptyMessage(
              icon: Icons.menu_book_outlined,
              text: 'Add subjects and syllabus topics to see subject progress.',
            )
          else
            ...subjects.map((subject) => _SubjectProgressRow(subject: subject)),
        ],
      ),
    );
  }
}

class _SubjectProgressRow extends StatelessWidget {
  const _SubjectProgressRow({required this.subject});

  final SubjectProgressInsight subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (subject.progress * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final name = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${subject.className} • ${subject.progressDetail}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          );
          final progress = Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: subject.progress.clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: scheme.primary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [name, const SizedBox(height: 8), progress],
            );
          }
          return Row(
            children: [
              SizedBox(width: 230, child: name),
              const SizedBox(width: 18),
              Expanded(child: progress),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingDeadlinesCard extends StatelessWidget {
  const _UpcomingDeadlinesCard({required this.lessons, this.onOpenLesson});

  final List<ProgressLessonInsight> lessons;
  final ValueChanged<LessonPlan>? onOpenLesson;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.calendar_month_rounded,
            title: 'Upcoming teaching',
            color: Color(0xFF2563EB),
          ),
          const SizedBox(height: 10),
          if (lessons.isEmpty)
            const _EmptyMessage(
              icon: Icons.event_available_rounded,
              text: 'No pending lessons in the next 7 days.',
            )
          else
            ...lessons
                .take(5)
                .map(
                  (item) => _LessonInsightTile(
                    insight: item,
                    tone: const Color(0xFF2563EB),
                    onTap: onOpenLesson == null
                        ? null
                        : () => onOpenLesson!(item.lesson),
                  ),
                ),
        ],
      ),
    );
  }
}

class _BacklogAlertsCard extends StatelessWidget {
  const _BacklogAlertsCard({
    required this.overdueLessons,
    required this.highPriorityTopics,
    this.onOpenLesson,
  });

  final List<ProgressLessonInsight> overdueLessons;
  final List<ProgressTopicInsight> highPriorityTopics;
  final ValueChanged<LessonPlan>? onOpenLesson;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.warning_amber_rounded,
            title: 'Backlog Alerts',
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),
          if (overdueLessons.isEmpty && highPriorityTopics.isEmpty)
            const _EmptyMessage(
              icon: Icons.check_circle_outline_rounded,
              text: 'No overdue lessons or pending high-priority topics.',
            )
          else ...[
            ...overdueLessons
                .take(3)
                .map(
                  (item) => _LessonInsightTile(
                    insight: item,
                    tone: const Color(0xFFEF4444),
                    badge: 'Overdue',
                    onTap: onOpenLesson == null
                        ? null
                        : () => onOpenLesson!(item.lesson),
                  ),
                ),
            ...highPriorityTopics
                .take(3)
                .map((item) => _TopicAlertTile(insight: item)),
          ],
        ],
      ),
    );
  }
}

class _LessonInsightTile extends StatelessWidget {
  const _LessonInsightTile({
    required this.insight,
    required this.tone,
    this.badge,
    this.onTap,
  });

  final ProgressLessonInsight insight;
  final Color tone;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                children: [
                  Text(
                    '${insight.lesson.plannedDate.day}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: tone),
                  ),
                  Text(
                    _monthLabel(insight.lesson.plannedDate.month),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${insight.subjectName} • ${insight.chapterTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              _SmallBadge(label: badge!, color: tone),
            ] else if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 7),
                child: Icon(Icons.chevron_right_rounded, size: 19),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicAlertTile extends StatelessWidget {
  const _TopicAlertTile({required this.insight});

  final ProgressTopicInsight insight;

  @override
  Widget build(BuildContext context) {
    const tone = Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: tone,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.topic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${insight.subjectName} • ${insight.chapterTitle} • ${_statusLabel(insight.topic.status)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _SmallBadge(label: 'High', color: tone),
        ],
      ),
    );
  }
}

class _TeachingFocusCard extends StatelessWidget {
  const _TeachingFocusCard({required this.model});

  final ProgressInsightsModel model;

  @override
  Widget build(BuildContext context) {
    final suggestions =
        <({IconData icon, Color color, String title, String subtitle})>[];

    if (model.overdueLessons.isNotEmpty) {
      suggestions.add((
        icon: Icons.schedule_rounded,
        color: const Color(0xFFEF4444),
        title: 'Clear overdue teaching first',
        subtitle:
            '${model.overdueLessons.length} lesson${model.overdueLessons.length == 1 ? '' : 's'} are past the planned date.',
      ));
    }
    if (model.highPriorityPendingTopics.isNotEmpty) {
      suggestions.add((
        icon: Icons.priority_high_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Protect high-priority syllabus time',
        subtitle:
            '${model.highPriorityPendingTopics.length} high-priority topic${model.highPriorityPendingTopics.length == 1 ? '' : 's'} still need attention.',
      ));
    }
    if (model.periodVariance < 0) {
      suggestions.add((
        icon: Icons.av_timer_rounded,
        color: const Color(0xFF7C3AED),
        title: 'Teaching periods are behind plan',
        subtitle:
            '${model.periodVariance.abs()} planned lesson periods have not yet been matched by actual teaching.',
      ));
    }
    if (suggestions.isEmpty) {
      suggestions.add((
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
        title: 'Teaching plan is on track',
        subtitle:
            'No overdue lessons or urgent high-priority backlog is currently detected.',
      ));
    }

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Teaching focus',
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          ...suggestions
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon, size: 19, color: item.color),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AdvancedInsightsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.analytics_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Advanced insights',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _LockedAdvancedInsightsCard extends StatelessWidget {
  const _LockedAdvancedInsightsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _DashboardCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.lock_outline_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advanced teaching insights',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Progress trends, topic distribution and priority analysis are available with Teaching Planner Pro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionTrendCard extends StatelessWidget {
  const _CompletionTrendCard({required this.lessons, required this.now});

  final List<LessonPlan> lessons;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(6, (index) {
      final monthIndex = now.month - 5 + index;
      return DateTime(now.year, monthIndex, 1);
    });
    var cumulative = 0;
    final values = <double>[];
    final completed = lessons
        .where(
          (item) =>
              item.status == TeachingProgressStatus.completed &&
              item.taughtAt != null,
        )
        .toList();
    for (final month in months) {
      cumulative += completed.where((item) {
        final date = item.taughtAt!.toLocal();
        return date.year == month.year && date.month == month.month;
      }).length;
      values.add(lessons.isEmpty ? 0 : cumulative / lessons.length);
    }

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.show_chart_rounded,
            title: 'Progress over time',
            color: Color(0xFF14B8A6),
          ),
          const SizedBox(height: 4),
          Text(
            'Cumulative completed lessons using recorded taught dates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: _LineProgressChart(months: months, values: values),
          ),
        ],
      ),
    );
  }
}

class _TopicStatusCard extends StatelessWidget {
  const _TopicStatusCard({required this.model});

  final ProgressInsightsModel model;

  @override
  Widget build(BuildContext context) {
    final completed = model.completedTopicCount;
    final inProgress = model.inProgressTopicCount;
    final remaining = model.remainingTopicCount;
    final total = math.max(1, completed + inProgress + remaining);
    const colors = [Color(0xFF14B8A6), Color(0xFF2563EB), Color(0xFFF59E0B)];

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.donut_large_rounded,
            title: 'Topic status distribution',
            color: Color(0xFF2563EB),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final chart = SizedBox.square(
                dimension: compact ? 120 : 138,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: [
                      completed.toDouble(),
                      inProgress.toDouble(),
                      remaining.toDouble(),
                    ],
                    colors: colors,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${model.topics.length}',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text('Topics'),
                      ],
                    ),
                  ),
                ),
              );
              final legend = Column(
                children: [
                  _LegendRow(
                    color: colors[0],
                    label: 'Completed',
                    value: '$completed (${(completed * 100 / total).round()}%)',
                  ),
                  const SizedBox(height: 10),
                  _LegendRow(
                    color: colors[1],
                    label: 'In progress',
                    value:
                        '$inProgress (${(inProgress * 100 / total).round()}%)',
                  ),
                  const SizedBox(height: 10),
                  _LegendRow(
                    color: colors[2],
                    label: 'Remaining',
                    value: '$remaining (${(remaining * 100 / total).round()}%)',
                  ),
                ],
              );
              if (compact) {
                return Column(
                  children: [chart, const SizedBox(height: 14), legend],
                );
              }
              return Row(
                children: [
                  chart,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PriorityProgressCard extends StatelessWidget {
  const _PriorityProgressCard({required this.topics});

  final List<PlannerTopic> topics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (PlannerPriority.high, 'High', const Color(0xFFEF4444)),
      (PlannerPriority.normal, 'Normal', const Color(0xFF2563EB)),
      (PlannerPriority.low, 'Low', const Color(0xFF64748B)),
    ];
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.flag_outlined,
            title: 'Priority-wise progress',
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final items = rows.map((row) {
                final grouped = topics
                    .where((item) => item.priority == row.$1)
                    .toList();
                final complete = grouped
                    .where(
                      (item) => item.status == TeachingProgressStatus.completed,
                    )
                    .length;
                final progress = grouped.isEmpty
                    ? 0.0
                    : complete / grouped.length;
                return _PriorityMetric(
                  label: row.$2,
                  progress: progress,
                  value: '$complete / ${grouped.length}',
                  color: row.$3,
                );
              }).toList();
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      items[i],
                      if (i != items.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(child: items[i]),
                    if (i != items.length - 1) const SizedBox(width: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PriorityMetric extends StatelessWidget {
  const _PriorityMetric({
    required this.label,
    required this.progress,
    required this.value,
    required this.color,
  });

  final String label;
  final double progress;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedProgressRing(
        progress: progress,
        color: color,
        centerText: '${(progress * 100).round()}%',
        size: 76,
        strokeWidth: 7,
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(value, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.centerText,
    this.size = 88,
    this.strokeWidth = 9,
  });

  final double progress;
  final Color color;
  final String centerText;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: safeProgress),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: color,
            trackColor: color.withValues(alpha: 0.13),
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Text(
              centerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 0.19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _LineProgressChart extends StatelessWidget {
  const _LineProgressChart({required this.months, required this.values});

  final List<DateTime> months;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    const lineColor = Color(0xFF14B8A6);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              lineColor: lineColor,
              gridColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months
                .map(
                  (month) => Text(
                    _monthLabel(month.month),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 28;
    final chartWidth = size.width;
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), grid);
    }
    if (values.isEmpty) {
      return;
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? chartWidth / 2
          : chartWidth * i / (values.length - 1);
      final y = chartHeight * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = lineColor);
    }
    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, item) => sum + item);
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;
    if (total <= 0) {
      stroke.color = colors.first.withValues(alpha: 0.12);
      canvas.drawArc(
        rect.deflate(10),
        -math.pi / 2,
        math.pi * 2,
        false,
        stroke,
      );
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      if (sweep <= 0) {
        continue;
      }
      stroke.color = colors[i];
      canvas.drawArc(rect.deflate(10), start, sweep, false, stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String _statusLabel(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => 'Planned',
  TeachingProgressStatus.inProgress => 'In progress',
  TeachingProgressStatus.completed => 'Completed',
  TeachingProgressStatus.skipped => 'Skipped',
  TeachingProgressStatus.rescheduled => 'Rescheduled',
};

String _monthLabel(int month) => const [
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
][month - 1];
