import 'package:flutter/material.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_shared_components.dart';

class LessonTeachingSessionDraft {
  const LessonTeachingSessionDraft({
    required this.status,
    required this.actualPeriods,
    this.taughtAt,
    this.reflection,
  });

  final TeachingProgressStatus status;
  final int actualPeriods;
  final DateTime? taughtAt;
  final String? reflection;
}

Future<LessonTeachingSessionDraft?> showLessonTeachingSessionSheet({
  required BuildContext context,
  required LessonPlan lesson,
  TeachingProgressStatus? suggestedStatus,
}) {
  return showAdaptiveModalBottomSheet<LessonTeachingSessionDraft>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TeachingPlannerThemeScope(
      child: LessonTeachingSessionSheet(
        lesson: lesson,
        suggestedStatus: suggestedStatus,
      ),
    ),
  );
}

class LessonTeachingSessionSheet extends StatefulWidget {
  const LessonTeachingSessionSheet({
    super.key,
    required this.lesson,
    this.suggestedStatus,
  });

  final LessonPlan lesson;
  final TeachingProgressStatus? suggestedStatus;

  @override
  State<LessonTeachingSessionSheet> createState() =>
      _LessonTeachingSessionSheetState();
}

class _LessonTeachingSessionSheetState
    extends State<LessonTeachingSessionSheet> {
  late TeachingProgressStatus _status;
  late final TextEditingController _periods;
  late final TextEditingController _reflection;
  DateTime? _taughtAt;

  @override
  void initState() {
    super.initState();
    _status = widget.suggestedStatus ?? widget.lesson.status;
    _periods = TextEditingController(
      text: widget.lesson.actualPeriods.toString(),
    );
    _reflection = TextEditingController(text: widget.lesson.reflection ?? '');
    _taughtAt = widget.lesson.taughtAt?.toLocal();
  }

  @override
  void dispose() {
    _periods.dispose();
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colors = TeachingPlannerTheme.colorsOf(context);

    return ColoredBox(
      color: colors.canvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TeachingPlannerDesign.space20,
          TeachingPlannerDesign.space4,
          TeachingPlannerDesign.space20,
          TeachingPlannerDesign.space20 + bottomInset,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionSheetHeader(lesson: widget.lesson),
                  const SizedBox(height: TeachingPlannerDesign.space16),
                  TeachingPlannerSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<TeachingProgressStatus>(
                          key: const ValueKey('lesson-session-status'),
                          initialValue: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Teaching status',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: TeachingProgressStatus.values
                              .map(
                                (status) =>
                                    DropdownMenuItem<TeachingProgressStatus>(
                                      value: status,
                                      child: Text(
                                        _statusLabel(status),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _status = value);
                            }
                          },
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 480;
                            final periods = TextField(
                              key: const ValueKey(
                                'lesson-session-actual-periods',
                              ),
                              controller: _periods,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Actual periods',
                                helperText:
                                    '${widget.lesson.plannedPeriods} planned period${widget.lesson.plannedPeriods == 1 ? '' : 's'}',
                                prefixIcon: const Icon(Icons.schedule_rounded),
                              ),
                            );
                            final taughtDate = OutlinedButton.icon(
                              key: const ValueKey('lesson-session-taught-date'),
                              onPressed: _pickTaughtDate,
                              icon: const Icon(Icons.event_available_rounded),
                              label: Text(
                                _taughtAt == null
                                    ? 'Set taught date'
                                    : 'Taught ${_dateLabel(_taughtAt!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  periods,
                                  const SizedBox(
                                    height: TeachingPlannerDesign.space12,
                                  ),
                                  taughtDate,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: periods),
                                const SizedBox(
                                  width: TeachingPlannerDesign.space12,
                                ),
                                Expanded(child: taughtDate),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space12),
                        TextField(
                          key: const ValueKey('lesson-session-reflection'),
                          controller: _reflection,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Reflection / outcome',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.rate_review_outlined),
                            hintText:
                                'What worked, what needs another period, or what to revisit next time.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space14),
                  FilledButton.icon(
                    key: const ValueKey('lesson-session-save'),
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save teaching session'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTaughtDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _taughtAt ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _taughtAt = picked);
    }
  }

  void _submit() {
    final periods = int.tryParse(_periods.text.trim());
    if (periods == null || periods < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actual periods must be zero or more.')),
      );
      return;
    }
    final reflection = _reflection.text.trim();
    Navigator.of(context).pop(
      LessonTeachingSessionDraft(
        status: _status,
        actualPeriods: periods,
        taughtAt: _taughtAt,
        reflection: reflection.isEmpty ? null : reflection,
      ),
    );
  }
}

class _SessionSheetHeader extends StatelessWidget {
  const _SessionSheetHeader({required this.lesson});

  final LessonPlan lesson;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tint: true,
      tone: TeachingPlannerTone.primary,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeachingPlannerIconBadge(
            icon: Icons.school_rounded,
            size: 46,
            iconSize: 24,
            tone: TeachingPlannerTone.primary,
          ),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teaching session',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space8),
                TeachingPlannerPill(
                  label:
                      '${lesson.plannedPeriods} planned period${lesson.plannedPeriods == 1 ? '' : 's'}',
                  icon: Icons.schedule_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => 'Planned',
  TeachingProgressStatus.inProgress => 'In progress',
  TeachingProgressStatus.completed => 'Completed',
  TeachingProgressStatus.skipped => 'Skipped',
  TeachingProgressStatus.rescheduled => 'Rescheduled',
};

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
