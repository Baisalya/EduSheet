import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/lesson_schedule_service.dart';
import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../providers/teaching_planner_provider.dart';

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
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final canUseSlots = capabilities.allows(
      TeachingPlannerCapability.advancedScheduling,
    );
    final conflicts = _schedule.conflicts(workspace);
    final lessons = _schedule.lessonsOn(workspace, _selectedDay);
    final weekStart = _selectedDay.subtract(
      Duration(days: _selectedDay.weekday - 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teaching Calendar'),
        actions: [
          IconButton(
            tooltip: 'Today',
            onPressed: () {
              final now = DateTime.now();
              setState(
                () => _selectedDay = DateTime(now.year, now.month, now.day),
              );
            },
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = (constraints.maxWidth * .04)
                .clamp(12.0, 28.0)
                .toDouble();
            final wide = constraints.maxWidth >= 920;
            final agenda = _AgendaPanel(
              lessons: lessons,
              workspace: workspace,
              conflicts: conflicts,
              canUseSlots: canUseSlots,
              onSchedule: _editSchedule,
            );
            final overview = _CalendarOverview(
              totalLessons: workspace.activeLessonPlans.length,
              scheduledLessons: workspace.activeLessonPlans
                  .where((l) => l.startPeriod != null)
                  .length,
              conflictCount: conflicts.length,
              canUseSlots: canUseSlots,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Schedule lessons by day and period',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canUseSlots
                            ? 'Assign period slots and spot overlapping lessons for the same class.'
                            : 'Calendar view is available. Period-slot conflict tools use your existing Pro access.',
                      ),
                      const SizedBox(height: 18),
                      _WeekStrip(
                        weekStart: weekStart,
                        selectedDay: _selectedDay,
                        onSelected: (value) =>
                            setState(() => _selectedDay = value),
                        onPrevious: () => setState(
                          () => _selectedDay = _selectedDay.subtract(
                            const Duration(days: 7),
                          ),
                        ),
                        onNext: () => setState(
                          () => _selectedDay = _selectedDay.add(
                            const Duration(days: 7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 300, child: overview),
                            const SizedBox(width: 18),
                            Expanded(child: agenda),
                          ],
                        )
                      else ...[
                        overview,
                        const SizedBox(height: 18),
                        agenda,
                      ],
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

  Future<void> _editSchedule(LessonPlan lesson, bool canUseSlots) async {
    var date = lesson.plannedDate.toLocal();
    final controller = TextEditingController(
      text: lesson.startPeriod?.toString() ?? '',
    );
    final result = await showDialog<({DateTime date, int? startPeriod})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: date,
                    );
                    if (picked != null) setDialogState(() => date = picked);
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final period = raw.isEmpty ? null : int.tryParse(raw);
                if (canUseSlots &&
                    raw.isNotEmpty &&
                    (period == null || period < 1))
                  return;
                Navigator.pop(context, (
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

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: days.map((day) {
                    final selected = _sameDay(day, selectedDay);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text('${_weekday(day.weekday)} ${day.day}'),
                        onSelected: (_) => onSelected(day),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarOverview extends StatelessWidget {
  const _CalendarOverview({
    required this.totalLessons,
    required this.scheduledLessons,
    required this.conflictCount,
    required this.canUseSlots,
  });
  final int totalLessons;
  final int scheduledLessons;
  final int conflictCount;
  final bool canUseSlots;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Schedule overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text('Active lessons: $totalLessons'),
          Text('Period-slotted: $scheduledLessons'),
          Text('Conflicts: ${canUseSlots ? conflictCount : 'Pro'}'),
        ],
      ),
    ),
  );
}

class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel({
    required this.lessons,
    required this.workspace,
    required this.conflicts,
    required this.canUseSlots,
    required this.onSchedule,
  });
  final List<LessonPlan> lessons;
  final TeachingPlannerWorkspace workspace;
  final List<LessonScheduleConflict> conflicts;
  final bool canUseSlots;
  final void Function(LessonPlan, bool) onSchedule;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Daily agenda',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No lessons planned for this day.')),
            )
          else
            ...lessons.map((lesson) {
              final subject = workspace.subjectById(lesson.subjectId);
              final conflict = conflicts.any(
                (c) =>
                    c.firstLessonId == lesson.id ||
                    c.secondLessonId == lesson.id,
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(lesson.startPeriod?.toString() ?? '–'),
                ),
                title: Text(lesson.title),
                subtitle: Text(
                  '${subject?.name ?? 'Subject'} • ${lesson.plannedPeriods} period${lesson.plannedPeriods == 1 ? '' : 's'}${conflict ? ' • Conflict' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Schedule lesson',
                  onPressed: () => onSchedule(lesson, canUseSlots),
                  icon: Icon(
                    conflict
                        ? Icons.warning_amber_rounded
                        : Icons.edit_calendar_rounded,
                  ),
                ),
              );
            }),
        ],
      ),
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _weekday(int value) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
