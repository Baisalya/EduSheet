import 'package:flutter/material.dart';

import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/lesson_detail_model.dart';
import 'teaching_planner_shared_components.dart';

/// Reference-style hero for a real teacher lesson.
///
/// The mockup's study-only controls are intentionally not reproduced. Every
/// value and action exposed here maps to an existing LessonPlan capability.
class LessonDetailHero extends StatelessWidget {
  const LessonDetailHero({
    super.key,
    required this.model,
    required this.onRecord,
  });

  final LessonDetailModel model;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final lesson = model.lesson;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primarySoft,
            colors.surface,
            colors.tealSoft.withValues(alpha: .62),
          ],
          stops: const [0, .56, 1],
        ),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusHero),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeachingPlannerIconBadge(
                icon: Icons.school_rounded,
                size: 52,
                iconSize: 27,
                tone: TeachingPlannerTone.primary,
              ),
              const SizedBox(width: TeachingPlannerDesign.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.subjectName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.inkMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space2),
                    Text(
                      lesson.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.35,
                          ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space4),
                    Text(
                      '${model.className} • ${model.chapterName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final action = FilledButton.icon(
            key: const ValueKey('lesson-detail-record-session'),
            onPressed: onRecord,
            icon: Icon(
              lesson.status == TeachingProgressStatus.planned
                  ? Icons.play_arrow_rounded
                  : Icons.edit_note_rounded,
            ),
            label: Text(
              lesson.status == TeachingProgressStatus.planned
                  ? 'Start teaching'
                  : 'Update session',
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                title,
                const SizedBox(height: TeachingPlannerDesign.space16),
                action,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: TeachingPlannerDesign.space20),
                    action,
                  ],
                ),
              const SizedBox(height: TeachingPlannerDesign.space16),
              Wrap(
                spacing: TeachingPlannerDesign.space8,
                runSpacing: TeachingPlannerDesign.space8,
                children: [
                  TeachingPlannerPill(
                    label: model.statusLabel,
                    icon: _statusIcon(lesson.status),
                    tone: _statusTone(lesson.status),
                  ),
                  TeachingPlannerPill(
                    label: _dateLabel(lesson.plannedDate.toLocal()),
                    icon: Icons.calendar_today_outlined,
                  ),
                  TeachingPlannerPill(
                    label: model.periodLabel,
                    icon: Icons.schedule_outlined,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class LessonProgressSummary extends StatelessWidget {
  const LessonProgressSummary({super.key, required this.model});

  final LessonDetailModel model;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final percent = (model.periodProgress * 100).round();
    final lesson = model.lesson;

    return TeachingPlannerSurfaceCard(
      tint: true,
      tone: TeachingPlannerTone.teal,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final ring = _ProgressRing(
            progress: model.periodProgress,
            label: '$percent%',
          );
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.isCompleted ? 'Lesson completed' : 'Teaching progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.teal,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space4),
              Text(
                model.hasTeachingRecord
                    ? '${lesson.actualPeriods} of ${lesson.plannedPeriods} planned periods recorded.'
                    : 'Record the session when you teach this lesson.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: TeachingPlannerDesign.space12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      value: '${lesson.plannedPeriods}',
                      label: 'Planned',
                      tone: TeachingPlannerTone.primary,
                    ),
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space8),
                  Expanded(
                    child: _SummaryMetric(
                      value: '${lesson.actualPeriods}',
                      label: 'Actual',
                      tone: TeachingPlannerTone.teal,
                    ),
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space8),
                  Expanded(
                    child: _SummaryMetric(
                      value: '${model.resourceCount}',
                      label: 'Resources',
                      tone: TeachingPlannerTone.purple,
                    ),
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
                const SizedBox(height: TeachingPlannerDesign.space16),
                summary,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: TeachingPlannerDesign.space20),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}

class LessonTopicChecklist extends StatelessWidget {
  const LessonTopicChecklist({super.key, required this.model});

  final LessonDetailModel model;

  @override
  Widget build(BuildContext context) {
    if (model.topics.isEmpty) return const SizedBox.shrink();

    final completed = model.topics
        .where((topic) => topic.status == TeachingProgressStatus.completed)
        .length;
    final colors = TeachingPlannerTheme.colorsOf(context);

    return TeachingPlannerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TeachingPlannerIconBadge(
                icon: Icons.checklist_rounded,
                size: 36,
                iconSize: 20,
                tone: TeachingPlannerTone.primary,
              ),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Text(
                  'Topics in this lesson',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$completed/${model.topics.length} complete',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          ...model.topics.map((topic) => _TopicRow(topic: topic)),
        ],
      ),
    );
  }
}

class LessonTeachingSessionCard extends StatelessWidget {
  const LessonTeachingSessionCard({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.onComplete,
    required this.onMaterials,
  });

  final LessonDetailModel model;
  final VoidCallback onUpdate;
  final VoidCallback? onComplete;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final lesson = model.lesson;

    return TeachingPlannerSurfaceCard(
      tint: true,
      tone: TeachingPlannerTone.primary,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TeachingPlannerIconBadge(
                icon: Icons.school_rounded,
                size: 42,
                tone: TeachingPlannerTone.primary,
              ),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teaching session',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      model.hasTeachingRecord
                          ? 'Keep the actual classroom record current.'
                          : 'Record the lesson after teaching.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          _SessionInfoRow(label: 'Status', value: model.statusLabel),
          _SessionInfoRow(
            label: 'Taught date',
            value: lesson.taughtAt == null
                ? 'Not recorded'
                : _dateLabel(lesson.taughtAt!.toLocal()),
          ),
          _SessionInfoRow(
            label: 'Period variance',
            value: model.hasTeachingRecord
                ? _varianceLabel(model.periodVariance)
                : 'Not recorded',
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Text(
            'Reflection / outcome',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space6),
          Text(
            lesson.reflection?.trim().isNotEmpty == true
                ? lesson.reflection!
                : 'No teaching reflection recorded yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space16),
          FilledButton.icon(
            key: const ValueKey('lesson-detail-update-session'),
            onPressed: onUpdate,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(
              model.hasTeachingRecord ? 'Update session' : 'Record session',
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space8),
          Row(
            children: [
              if (onComplete != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('lesson-detail-complete'),
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Complete'),
                  ),
                ),
                const SizedBox(width: TeachingPlannerDesign.space8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMaterials,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text('Materials (${model.resourceCount})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LessonPlanSections extends StatelessWidget {
  const LessonPlanSections({super.key, required this.model});

  final LessonDetailModel model;

  @override
  Widget build(BuildContext context) {
    final lesson = model.lesson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LessonSectionCard(
          icon: Icons.track_changes_rounded,
          title: 'Learning objective',
          tone: TeachingPlannerTone.teal,
          child: Text(lesson.objective),
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        _LessonSectionCard(
          icon: Icons.inventory_2_outlined,
          title: 'Materials & resources',
          tone: TeachingPlannerTone.primary,
          child: _OptionalText(value: lesson.materials),
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        _LessonSectionCard(
          icon: Icons.auto_stories_outlined,
          title: 'Teaching activities',
          tone: TeachingPlannerTone.purple,
          child: _OptionalText(value: lesson.activities),
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        _LessonSectionCard(
          icon: Icons.assignment_outlined,
          title: 'Homework / follow-up',
          tone: TeachingPlannerTone.orange,
          child: _OptionalText(value: lesson.homework),
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        _LessonSectionCard(
          icon: Icons.sticky_note_2_outlined,
          title: 'Teacher notes',
          tone: TeachingPlannerTone.coral,
          child: _OptionalText(value: lesson.notes),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            strokeWidth: 11,
            backgroundColor: colors.surfaceStrong,
            color: colors.teal,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'periods',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.tone,
  });

  final String value;
  final String label;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final foreground = tone.foreground(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: tone.background(colors),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final LessonDetailTopic topic;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final tone = _statusTone(topic.status);
    final foreground = tone.foreground(colors);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(topic.status), size: 21, color: foreground),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Text(
              topic.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: TeachingPlannerDesign.space8),
          Text(
            _statusLabel(topic.status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionInfoRow extends StatelessWidget {
  const _SessionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
          ),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonSectionCard extends StatelessWidget {
  const _LessonSectionCard({
    required this.icon,
    required this.title,
    required this.tone,
    required this.child,
  });

  final IconData icon;
  final String title;
  final TeachingPlannerTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TeachingPlannerIconBadge(
                icon: icon,
                size: 36,
                iconSize: 19,
                tone: tone,
              ),
              const SizedBox(width: TeachingPlannerDesign.space10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          DefaultTextStyle.merge(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.ink, height: 1.45),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _OptionalText extends StatelessWidget {
  const _OptionalText({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final clean = value?.trim();
    return Text(
      clean == null || clean.isEmpty ? 'Not added to this lesson.' : clean,
      style: TextStyle(
        color: clean == null || clean.isEmpty ? colors.inkMuted : colors.ink,
      ),
    );
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

String _varianceLabel(int variance) {
  if (variance == 0) return 'On plan';
  if (variance > 0) {
    return '+$variance period${variance == 1 ? '' : 's'}';
  }
  final absolute = variance.abs();
  return '-$absolute period${absolute == 1 ? '' : 's'}';
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
