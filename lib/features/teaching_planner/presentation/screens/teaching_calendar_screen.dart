import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/lesson_schedule_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../models/weekly_planner_model.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/teaching_calendar_agenda.dart';
import '../widgets/teaching_calendar_week_strip.dart';
import '../widgets/teaching_planner_page_shell.dart';
import '../widgets/teaching_planner_shared_components.dart';
import 'lesson_detail_screen.dart';
import 'lesson_planner_screen.dart';

class TeachingCalendarScreen extends ConsumerStatefulWidget {
  const TeachingCalendarScreen({super.key});

  @override
  ConsumerState<TeachingCalendarScreen> createState() =>
      _TeachingCalendarScreenState();
}

class _TeachingCalendarScreenState
    extends ConsumerState<TeachingCalendarScreen> {
  static const _schedule = LessonScheduleService();
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _day(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final canUseSlots = capabilities.allows(
      TeachingPlannerCapability.advancedScheduling,
    );
    final model = WeeklyPlannerModel.fromWorkspace(
      workspace,
      _selectedDay,
      schedule: _schedule,
    );
    final selected = model.dayFor(_selectedDay);

    return TeachingPlannerPageShell(
      title: 'Weekly Planner',
      showAppBar: false,
      currentDestination: TeachingPlannerDestination.calendar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = TeachingPlannerBreakpoints.horizontalPadding(
              constraints.maxWidth,
              factor: .04,
              max: 28,
            );
            final wide =
                constraints.maxWidth >= TeachingPlannerBreakpoints.wide;

            return SingleChildScrollView(
              key: const ValueKey('planner-calendar-scroll'),
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PlannerHeader(
                        canUseSlots: canUseSlots,
                        onToday: () =>
                            setState(() => _selectedDay = _day(DateTime.now())),
                        onPlanLesson: _openLessonPlanner,
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space18),
                      TeachingCalendarWeekProgressCard(
                        model: model,
                        canUseSlots: canUseSlots,
                        onPlanLesson: _openLessonPlanner,
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space16),
                      TeachingCalendarWeekStrip(
                        model: model,
                        selectedDay: _selectedDay,
                        onSelected: (value) =>
                            setState(() => _selectedDay = value),
                        onPreviousWeek: () => setState(
                          () => _selectedDay = _selectedDay.subtract(
                            const Duration(days: 7),
                          ),
                        ),
                        onNextWeek: () => setState(
                          () => _selectedDay = _selectedDay.add(
                            const Duration(days: 7),
                          ),
                        ),
                      ),
                      const SizedBox(height: TeachingPlannerDesign.space16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: TeachingCalendarAgenda(
                                day: selected,
                                canUseSlots: canUseSlots,
                                onSchedule: _editSchedule,
                                onOpenLesson: _openLessonDetail,
                                onPlanLesson: _openLessonPlanner,
                              ),
                            ),
                            const SizedBox(
                              width: TeachingPlannerDesign.space16,
                            ),
                            Expanded(
                              flex: 3,
                              child: _WeekOverviewPanel(
                                model: model,
                                selectedDay: _selectedDay,
                                canUseSlots: canUseSlots,
                                onSelected: (value) =>
                                    setState(() => _selectedDay = value),
                              ),
                            ),
                          ],
                        )
                      else
                        TeachingCalendarAgenda(
                          day: selected,
                          canUseSlots: canUseSlots,
                          onSchedule: _editSchedule,
                          onOpenLesson: _openLessonDetail,
                          onPlanLesson: _openLessonPlanner,
                        ),
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

  Future<void> _openLessonPlanner() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonPlannerScreen(
          openCreateOnStart: true,
          initialPlannedDate: _selectedDay,
        ),
      ),
    );
  }

  void _openLessonDetail(LessonPlan lesson) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonDetailScreen(lessonId: lesson.id),
      ),
    );
  }

  Future<void> _editSchedule(LessonPlan lesson, bool canUseSlots) async {
    var date = lesson.plannedDate.toLocal();
    final controller = TextEditingController(
      text: lesson.startPeriod?.toString() ?? '',
    );
    final result = await showDialog<({DateTime date, int? startPeriod})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Schedule ${lesson.title}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: date,
                    );
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text('${date.day}/${date.month}/${date.year}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  enabled: canUseSlots,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Start period',
                    helperText: canUseSlots
                        ? 'Optional. Example: 3'
                        : 'Period slots require Pro access.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('planner-schedule-save'),
              onPressed: () {
                final raw = controller.text.trim();
                final period = raw.isEmpty ? null : int.tryParse(raw);
                if (canUseSlots &&
                    raw.isNotEmpty &&
                    (period == null || period < 1)) {
                  return;
                }
                Navigator.pop(dialogContext, (
                  date: date,
                  startPeriod: canUseSlots ? period : lesson.startPeriod,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    await ref
        .read(teachingPlannerProvider.notifier)
        .scheduleLessonPlan(
          lesson.id,
          plannedDate: result.date,
          startPeriod: result.startPeriod,
        );
  }
}

class _PlannerHeader extends StatelessWidget {
  const _PlannerHeader({
    required this.canUseSlots,
    required this.onToday,
    required this.onPlanLesson,
  });

  final bool canUseSlots;
  final VoidCallback onToday;
  final VoidCallback onPlanLesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 590;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Planner',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              canUseSlots
                  ? 'Plan your week, assign periods and catch schedule conflicts.'
                  : 'Plan your week and organize lessons by day.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('planner-calendar-today'),
              onPressed: onToday,
              icon: const Icon(Icons.today_rounded),
              label: const Text('Today'),
            ),
            FilledButton.icon(
              key: const ValueKey('planner-header-add-lesson'),
              onPressed: onPlanLesson,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan lesson'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _WeekOverviewPanel extends StatelessWidget {
  const _WeekOverviewPanel({
    required this.model,
    required this.selectedDay,
    required this.canUseSlots,
    required this.onSelected,
  });

  final WeeklyPlannerModel model;
  final DateTime selectedDay;
  final bool canUseSlots;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeachingPlannerSectionHeader(
            title: 'Week at a glance',
            subtitle: 'Open any day to review its teaching load.',
            icon: Icons.calendar_view_week_rounded,
          ),
          const SizedBox(height: 12),
          for (final day in model.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _WeekOverviewRow(
                day: day,
                selected: _sameDay(day.date, selectedDay),
                onTap: () => onSelected(day.date),
              ),
            ),
          const SizedBox(height: 6),
          Divider(color: colors.border),
          const SizedBox(height: 4),
          _OverviewLine(
            label: 'Planned periods',
            value: '${model.plannedPeriods}',
          ),
          _OverviewLine(
            label: 'Slotted lessons',
            value: '${model.slottedLessons}',
          ),
          _OverviewLine(
            label: 'Conflicting lessons',
            value: canUseSlots ? '${model.conflictLessonCount}' : 'Pro',
          ),
        ],
      ),
    );
  }
}

class _WeekOverviewRow extends StatelessWidget {
  const _WeekOverviewRow({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final WeeklyPlannerDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Material(
      color: selected ? colors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  _weekday(day.date.weekday),
                  style: TextStyle(
                    color: selected ? colors.primary : colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  day.lessonCount == 0
                      ? 'Clear'
                      : '${day.lessonCount} lesson${day.lessonCount == 1 ? '' : 's'}',
                  style: TextStyle(color: colors.inkMuted),
                ),
              ),
              Text(
                '${day.plannedPeriods}p',
                style: TextStyle(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewLine extends StatelessWidget {
  const _OverviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.inkMuted)),
          ),
          Text(
            value,
            style: TextStyle(color: colors.ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

DateTime _day(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _weekday(int value) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
