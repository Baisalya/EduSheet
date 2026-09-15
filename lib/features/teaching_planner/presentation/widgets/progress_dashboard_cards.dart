import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_status.dart';

class ProgressDashboard extends StatelessWidget {
  const ProgressDashboard({
    super.key,
    required this.topics,
    required this.lessons,
    required this.classNameFor,
    required this.now,
  });

  final List<PlannerTopic> topics;
  final List<LessonPlan> lessons;
  final String Function(String classId) classNameFor;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final completedTopics = topics
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final completedLessons = lessons
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final plannedLessonPeriods = lessons.fold<int>(
      0,
      (sum, item) => sum + item.plannedPeriods,
    );
    final actualLessonPeriods = lessons.fold<int>(
      0,
      (sum, item) => sum + item.actualPeriods,
    );
    final topicCompletion = topics.isEmpty
        ? 0.0
        : completedTopics / topics.length;
    final lessonCompletion = lessons.isEmpty
        ? 0.0
        : completedLessons / lessons.length;
    final periodCompletion = plannedLessonPeriods == 0
        ? 0.0
        : actualLessonPeriods / plannedLessonPeriods;
    final highTopics = topics
        .where((item) => item.priority == PlannerPriority.high)
        .toList();
    final highCompleted = highTopics
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final highCompletion = highTopics.isEmpty
        ? 0.0
        : highCompleted / highTopics.length;

    final upcoming = lessons.where((item) {
      if (item.status == TeachingProgressStatus.completed ||
          item.status == TeachingProgressStatus.skipped)
        return false;
      final day = DateTime(
        item.plannedDate.year,
        item.plannedDate.month,
        item.plannedDate.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      return !day.isBefore(today) &&
          day.isBefore(today.add(const Duration(days: 7)));
    }).toList()..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 1180
            ? (width - 36) / 4
            : width >= 760
            ? (width - 12) / 2
            : width;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _RingMetricCard(
                    title: 'Syllabus completion',
                    progress: topicCompletion,
                    value: '${(topicCompletion * 100).round()}%',
                    subtitle: '$completedTopics of ${topics.length} topics',
                    color: const Color(0xFF18B87A),
                    icon: Icons.fact_check_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RingMetricCard(
                    title: 'Lessons taught',
                    progress: lessonCompletion,
                    value: '${(lessonCompletion * 100).round()}%',
                    subtitle: '$completedLessons of ${lessons.length} lessons',
                    color: const Color(0xFF2D83F6),
                    icon: Icons.school_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RingMetricCard(
                    title: 'Planned vs actual',
                    progress: periodCompletion.clamp(0.0, 1.0),
                    value: plannedLessonPeriods == 0
                        ? '0%'
                        : '${(periodCompletion * 100).round()}%',
                    subtitle:
                        '$actualLessonPeriods actual / $plannedLessonPeriods planned',
                    color: const Color(0xFFF5A623),
                    icon: Icons.av_timer_rounded,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RingMetricCard(
                    title: 'High priority',
                    progress: highCompletion,
                    value: '${(highCompletion * 100).round()}%',
                    subtitle:
                        '$highCompleted of ${highTopics.length} high-priority topics',
                    color: const Color(0xFF9B51E0),
                    icon: Icons.priority_high_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (width >= 980)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _CompletionTrendCard(lessons: lessons, now: now),
                  ),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _TopicStatusCard(topics: topics)),
                ],
              )
            else ...[
              _CompletionTrendCard(lessons: lessons, now: now),
              const SizedBox(height: 14),
              _TopicStatusCard(topics: topics),
            ],
            const SizedBox(height: 14),
            if (width >= 980)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PriorityProgressCard(topics: topics)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _UpcomingWorkCard(
                      lessons: upcoming.take(5).toList(),
                      classNameFor: classNameFor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickInsightsCard(
                      topics: topics,
                      lessons: lessons,
                      now: now,
                    ),
                  ),
                ],
              )
            else ...[
              _PriorityProgressCard(topics: topics),
              const SizedBox(height: 14),
              _UpcomingWorkCard(
                lessons: upcoming.take(5).toList(),
                classNameFor: classNameFor,
              ),
              const SizedBox(height: 14),
              _QuickInsightsCard(topics: topics, lessons: lessons, now: now),
            ],
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _RingMetricCard extends StatelessWidget {
  const _RingMetricCard({
    required this.title,
    required this.progress,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final double progress;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: SizedBox(
        height: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  AnimatedProgressRing(
                    progress: progress,
                    color: color,
                    centerText: value,
                    size: 94,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
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
      duration: const Duration(milliseconds: 800),
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
      oldDelegate.trackColor != trackColor;
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
          const Text(
            'Progress over time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

class _LineProgressChart extends StatelessWidget {
  const _LineProgressChart({required this.months, required this.values});
  final List<DateTime> months;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    const lineColor = Color(0xFF18B87A);
    return LayoutBuilder(
      builder: (context, constraints) {
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
      },
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
    if (values.isEmpty) return;
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
          lineColor.withValues(alpha: 0.24),
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

class _TopicStatusCard extends StatelessWidget {
  const _TopicStatusCard({required this.topics});
  final List<PlannerTopic> topics;

  @override
  Widget build(BuildContext context) {
    final completed = topics
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final inProgress = topics
        .where((item) => item.status == TeachingProgressStatus.inProgress)
        .length;
    final remaining = math.max(0, topics.length - completed - inProgress);
    final total = math.max(1, topics.length);
    const colors = [Color(0xFF18B87A), Color(0xFF2D83F6), Color(0xFFF5A623)];
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Topic status distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox.square(
                dimension: 138,
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
                          '${topics.length}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text('Topics'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(
                      color: colors[0],
                      label: 'Completed',
                      value:
                          '$completed (${(completed * 100 / total).round()}%)',
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
                      value:
                          '$remaining (${(remaining * 100 / total).round()}%)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 9,
    );
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    if (total == 0) {
      paint.color = colors.first.withValues(alpha: 0.12);
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = math.pi * 2 * values[i] / total;
      paint.color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
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

class _PriorityProgressCard extends StatelessWidget {
  const _PriorityProgressCard({required this.topics});
  final List<PlannerTopic> topics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (PlannerPriority.high, 'High', const Color(0xFFFF5D5D)),
      (PlannerPriority.normal, 'Normal', const Color(0xFF2D83F6)),
      (PlannerPriority.low, 'Low', const Color(0xFF7B8BA6)),
    ];
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Priority-wise progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rows.map((row) {
              final items = topics
                  .where((item) => item.priority == row.$1)
                  .toList();
              final complete = items
                  .where(
                    (item) => item.status == TeachingProgressStatus.completed,
                  )
                  .length;
              final progress = items.isEmpty ? 0.0 : complete / items.length;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedProgressRing(
                      progress: progress,
                      color: row.$3,
                      centerText: '${(progress * 100).round()}%',
                      size: 72,
                      strokeWidth: 7,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      row.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$complete / ${items.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _UpcomingWorkCard extends StatelessWidget {
  const _UpcomingWorkCard({required this.lessons, required this.classNameFor});
  final List<LessonPlan> lessons;
  final String Function(String classId) classNameFor;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.event_note_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upcoming work (next 7 days)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'Nothing due in the next 7 days. Your schedule is clear.',
              ),
            )
          else
            ...lessons.map(
              (lesson) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${classNameFor(lesson.classId)} • ${_shortDate(lesson.plannedDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D83F6).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${lesson.plannedPeriods}p',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D83F6),
                        ),
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

class _QuickInsightsCard extends StatelessWidget {
  const _QuickInsightsCard({
    required this.topics,
    required this.lessons,
    required this.now,
  });
  final List<PlannerTopic> topics;
  final List<LessonPlan> lessons;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final topicCompleted = topics
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final topicRate = topics.isEmpty ? 0.0 : topicCompleted / topics.length;
    final planned = lessons.fold<int>(
      0,
      (sum, item) => sum + item.plannedPeriods,
    );
    final actual = lessons.fold<int>(
      0,
      (sum, item) => sum + item.actualPeriods,
    );
    final variance = actual - planned;
    final pendingHigh = topics
        .where(
          (item) =>
              item.priority == PlannerPriority.high &&
              item.status != TeachingProgressStatus.completed,
        )
        .length;
    final today = DateTime(now.year, now.month, now.day);
    final overdue = lessons.where((item) {
      if (item.status == TeachingProgressStatus.completed ||
          item.status == TeachingProgressStatus.skipped)
        return false;
      final day = DateTime(
        item.plannedDate.year,
        item.plannedDate.month,
        item.plannedDate.day,
      );
      return day.isBefore(today);
    }).length;

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InsightRow(
            icon: topicRate >= 0.6
                ? Icons.arrow_upward_rounded
                : Icons.trending_up_rounded,
            color: const Color(0xFF18B87A),
            title: topicRate >= 0.6
                ? 'Good progress'
                : 'Keep building momentum',
            subtitle:
                '${(topicRate * 100).round()}% of syllabus topics are complete.',
          ),
          const SizedBox(height: 12),
          _InsightRow(
            icon: variance < 0
                ? Icons.arrow_downward_rounded
                : Icons.balance_rounded,
            color: variance < 0
                ? const Color(0xFFFF5D5D)
                : const Color(0xFF2D83F6),
            title: variance < 0 ? 'Behind planned periods' : 'Period pace',
            subtitle: variance == 0
                ? 'Actual and planned periods are aligned.'
                : '${variance.abs()} periods ${variance < 0 ? 'behind' : 'above'} plan.',
          ),
          const SizedBox(height: 12),
          _InsightRow(
            icon: Icons.priority_high_rounded,
            color: const Color(0xFFF5A623),
            title: 'Focus area',
            subtitle:
                '$pendingHigh high-priority topics pending • $overdue overdue lessons.',
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

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
