import 'package:flutter/material.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import 'teaching_planner_shared_components.dart';

class ProgressPageHeader extends StatelessWidget {
  const ProgressPageHeader({
    super.key,
    required this.className,
    required this.onRefresh,
  });

  final String className;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < TeachingPlannerBreakpoints.navigationRail;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TeachingPlannerIconBadge(
                  icon: Icons.bar_chart_rounded,
                  size: 46,
                  iconSize: 24,
                  tone: TeachingPlannerTone.primary,
                ),
                const SizedBox(width: TeachingPlannerDesign.space12),
                Flexible(
                  child: Text(
                    'Progress & Insights',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TeachingPlannerDesign.space6),
            Text(
              'Track syllabus completion, teaching pace and what needs attention next.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
          ],
        );

        final controls = Wrap(
          spacing: TeachingPlannerDesign.space8,
          runSpacing: TeachingPlannerDesign.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TeachingPlannerPill(
              label: className,
              icon: Icons.school_outlined,
              tone: TeachingPlannerTone.primary,
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: TeachingPlannerDesign.space12),
              controls,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: TeachingPlannerDesign.space18),
            controls,
          ],
        );
      },
    );
  }
}

class ProgressFilterBar extends StatelessWidget {
  const ProgressFilterBar({
    super.key,
    required this.classes,
    required this.classId,
    required this.status,
    required this.onClassChanged,
    required this.onStatusChanged,
  });

  final List<(String, String)> classes;
  final String? classId;
  final TeachingProgressStatus? status;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<TeachingProgressStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final classField = DropdownButtonFormField<String?>(
            initialValue: classId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Class',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All classes'),
              ),
              ...classes.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.$1,
                  child: Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onClassChanged,
          );
          final statusField = DropdownButtonFormField<TeachingProgressStatus?>(
            initialValue: status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.tune_rounded),
            ),
            items: [
              const DropdownMenuItem<TeachingProgressStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...TeachingProgressStatus.values.map(
                (item) => DropdownMenuItem<TeachingProgressStatus?>(
                  value: item,
                  child: Text(_statusLabel(item)),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          );

          final fields = compact
              ? Column(
                  children: [
                    classField,
                    const SizedBox(height: TeachingPlannerDesign.space10),
                    statusField,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: classField),
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    Expanded(child: statusField),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const TeachingPlannerIconBadge(
                    icon: Icons.filter_alt_outlined,
                    size: 34,
                    iconSize: 18,
                    tone: TeachingPlannerTone.primary,
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space10),
                  Expanded(
                    child: Text(
                      'Filter progress records',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TeachingPlannerDesign.space12),
              fields,
            ],
          );
        },
      ),
    );
  }
}

class LessonProgressPanel extends StatelessWidget {
  const LessonProgressPanel({
    super.key,
    required this.lessons,
    required this.workspace,
    required this.onEdit,
  });

  final List<LessonPlan> lessons;
  final TeachingPlannerWorkspace workspace;
  final ValueChanged<LessonPlan> onEdit;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Lesson execution',
            subtitle: 'Record taught date, actual periods and reflection.',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          if (lessons.isEmpty)
            const _EmptyEditorState(
              icon: Icons.event_busy_outlined,
              text: 'No lessons match this filter.',
            )
          else
            ...lessons.map(
              (lesson) => _LessonProgressRow(
                lesson: lesson,
                workspace: workspace,
                onEdit: () => onEdit(lesson),
              ),
            ),
        ],
      ),
    );
  }
}

class TopicProgressPanel extends StatelessWidget {
  const TopicProgressPanel({
    super.key,
    required this.topics,
    required this.workspace,
    required this.onEdit,
  });

  final List<PlannerTopic> topics;
  final TeachingPlannerWorkspace workspace;
  final ValueChanged<PlannerTopic> onEdit;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Syllabus progress',
            subtitle: 'Track topic completion and actual syllabus periods.',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          if (topics.isEmpty)
            const _EmptyEditorState(
              icon: Icons.checklist_rtl_outlined,
              text: 'No topics match this filter.',
            )
          else
            ...topics.map(
              (topic) => _TopicProgressRow(
                topic: topic,
                workspace: workspace,
                onEdit: () => onEdit(topic),
              ),
            ),
        ],
      ),
    );
  }
}

class TopicProgressDraft {
  const TopicProgressDraft({required this.status, required this.actualPeriods});

  final TeachingProgressStatus status;
  final int actualPeriods;
}

Future<TopicProgressDraft?> showTopicProgressSheet({
  required BuildContext context,
  required PlannerTopic topic,
}) {
  return showAdaptiveModalBottomSheet<TopicProgressDraft>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        TeachingPlannerThemeScope(child: _TopicProgressSheet(topic: topic)),
  );
}

class _LessonProgressRow extends StatelessWidget {
  const _LessonProgressRow({
    required this.lesson,
    required this.workspace,
    required this.onEdit,
  });

  final LessonPlan lesson;
  final TeachingPlannerWorkspace workspace;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final subject = workspace.subjectById(lesson.subjectId);
    final chapter = workspace.chapterById(lesson.chapterId);
    final tone = _statusTone(lesson.status);

    return Container(
      margin: const EdgeInsets.only(bottom: TeachingPlannerDesign.space8),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeachingPlannerIconBadge(
            icon: Icons.menu_book_rounded,
            size: 38,
            iconSize: 20,
            tone: tone,
          ),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  '${subject?.name ?? 'Subject'} • ${chapter?.title ?? 'Chapter'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: TeachingPlannerDesign.space8),
                Wrap(
                  spacing: TeachingPlannerDesign.space6,
                  runSpacing: TeachingPlannerDesign.space6,
                  children: [
                    TeachingPlannerPill(
                      label: _statusLabel(lesson.status),
                      tone: tone,
                    ),
                    TeachingPlannerPill(
                      label:
                          '${lesson.actualPeriods}/${lesson.plannedPeriods} periods',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Update lesson progress',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
    );
  }
}

class _TopicProgressRow extends StatelessWidget {
  const _TopicProgressRow({
    required this.topic,
    required this.workspace,
    required this.onEdit,
  });

  final PlannerTopic topic;
  final TeachingPlannerWorkspace workspace;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final chapter = workspace.chapterById(topic.chapterId);
    final tone = _statusTone(topic.status);
    return Container(
      margin: const EdgeInsets.only(bottom: TeachingPlannerDesign.space8),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeachingPlannerIconBadge(
            icon: _statusIcon(topic.status),
            size: 38,
            iconSize: 20,
            tone: tone,
          ),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space4),
                Text(
                  chapter?.title ?? 'Chapter',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: TeachingPlannerDesign.space8),
                Wrap(
                  spacing: TeachingPlannerDesign.space6,
                  runSpacing: TeachingPlannerDesign.space6,
                  children: [
                    TeachingPlannerPill(
                      label: _statusLabel(topic.status),
                      tone: tone,
                    ),
                    TeachingPlannerPill(
                      label:
                          '${topic.actualPeriods}/${topic.plannedPeriods} periods',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Update topic progress',
            onPressed: onEdit,
            icon: const Icon(Icons.track_changes_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyEditorState extends StatelessWidget {
  const _EmptyEditorState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TeachingPlannerDesign.space24,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colors.inkMuted),
          const SizedBox(height: TeachingPlannerDesign.space8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _TopicProgressSheet extends StatefulWidget {
  const _TopicProgressSheet({required this.topic});

  final PlannerTopic topic;

  @override
  State<_TopicProgressSheet> createState() => _TopicProgressSheetState();
}

class _TopicProgressSheetState extends State<_TopicProgressSheet> {
  late TeachingProgressStatus _status;
  late final TextEditingController _periods;

  @override
  void initState() {
    super.initState();
    _status = widget.topic.status;
    _periods = TextEditingController(
      text: widget.topic.actualPeriods.toString(),
    );
  }

  @override
  void dispose() {
    _periods.dispose();
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
          TeachingPlannerDesign.space8,
          TeachingPlannerDesign.space20,
          bottomInset + TeachingPlannerDesign.space24,
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TeachingPlannerSurfaceCard(
                    tint: true,
                    tone: TeachingPlannerTone.primary,
                    child: Row(
                      children: [
                        TeachingPlannerIconBadge(
                          icon: _statusIcon(widget.topic.status),
                          tone: _statusTone(widget.topic.status),
                        ),
                        const SizedBox(width: TeachingPlannerDesign.space12),
                        Expanded(
                          child: Text(
                            widget.topic.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space14),
                  TeachingPlannerSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<TeachingProgressStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Topic status',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: TeachingProgressStatus.values
                              .map(
                                (item) =>
                                    DropdownMenuItem<TeachingProgressStatus>(
                                      value: item,
                                      child: Text(_statusLabel(item)),
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
                        TextField(
                          controller: _periods,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Actual periods',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space14),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save topic progress'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final periods = int.tryParse(_periods.text.trim());
    if (periods == null || periods < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actual periods must be zero or more.')),
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(TopicProgressDraft(status: _status, actualPeriods: periods));
  }
}

TeachingPlannerTone _statusTone(TeachingProgressStatus status) =>
    switch (status) {
      TeachingProgressStatus.planned => TeachingPlannerTone.primary,
      TeachingProgressStatus.inProgress => TeachingPlannerTone.orange,
      TeachingProgressStatus.completed => TeachingPlannerTone.teal,
      TeachingProgressStatus.skipped => TeachingPlannerTone.neutral,
      TeachingProgressStatus.rescheduled => TeachingPlannerTone.coral,
    };

IconData _statusIcon(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => Icons.radio_button_unchecked_rounded,
  TeachingProgressStatus.inProgress => Icons.timelapse_rounded,
  TeachingProgressStatus.completed => Icons.check_circle_rounded,
  TeachingProgressStatus.skipped => Icons.remove_circle_outline_rounded,
  TeachingProgressStatus.rescheduled => Icons.event_repeat_rounded,
};

String _statusLabel(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => 'Planned',
  TeachingProgressStatus.inProgress => 'In progress',
  TeachingProgressStatus.completed => 'Completed',
  TeachingProgressStatus.skipped => 'Skipped',
  TeachingProgressStatus.rescheduled => 'Rescheduled',
};
