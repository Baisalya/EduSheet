import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import '../models/weekly_planner_model.dart';

class TeachingCalendarWeekStrip extends StatelessWidget {
  const TeachingCalendarWeekStrip({
    super.key,
    required this.model,
    required this.selectedDay,
    required this.onSelected,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final WeeklyPlannerModel model;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

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
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              _WeekArrowButton(
                key: const ValueKey('planner-week-previous'),
                tooltip: 'Previous week',
                icon: Icons.chevron_left_rounded,
                onPressed: onPreviousWeek,
              ),
              Expanded(
                child: Text(
                  _weekLabel(model.weekStart, model.weekEnd),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _WeekArrowButton(
                key: const ValueKey('planner-week-next'),
                tooltip: 'Next week',
                icon: Icons.chevron_right_rounded,
                onPressed: onNextWeek,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final chips = <Widget>[
                for (final day in model.days)
                  _DayChip(
                    day: day,
                    selected: _sameDay(day.date, selectedDay),
                    compact: compact,
                    onTap: () => onSelected(day.date),
                  ),
              ];

              if (compact) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < chips.length; index++) ...[
                        if (index > 0) const SizedBox(width: 6),
                        chips[index],
                      ],
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < chips.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(child: chips[index]),
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

class _WeekArrowButton extends StatelessWidget {
  const _WeekArrowButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceSoft,
        foregroundColor: colors.ink,
        minimumSize: const Size.square(42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final WeeklyPlannerDay day;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final foreground = selected ? Colors.white : colors.ink;
    final muted = selected
        ? Colors.white.withValues(alpha: .78)
        : colors.inkMuted;

    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey(
          'planner-day-${day.date.toIso8601String().substring(0, 10)}',
        ),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 58 : 0,
            minHeight: 68,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : day.hasLessons
                  ? colors.primary.withValues(alpha: .18)
                  : colors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _weekday(day.date.weekday),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.date.day}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: day.hasLessons
                      ? selected
                            ? Colors.white
                            : colors.teal
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekday(int value) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];

String _weekLabel(DateTime start, DateTime end) {
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
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${months[start.month - 1]} ${end.year}';
  }
  return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]} ${end.year}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
