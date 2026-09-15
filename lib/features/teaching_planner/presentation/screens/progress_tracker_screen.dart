import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/teaching_status.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/progress_dashboard_cards.dart';

class ProgressTrackerScreen extends ConsumerStatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  ConsumerState<ProgressTrackerScreen> createState() =>
      _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends ConsumerState<ProgressTrackerScreen> {
  String? _classId;
  TeachingProgressStatus? _status;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final classes = workspace.activeClasses;
    final lessons = workspace.activeLessonPlans.where((lesson) {
      if (_classId != null && lesson.classId != _classId) return false;
      if (_status != null && lesson.status != _status) return false;
      return true;
    }).toList();
    final topics = workspace.topics.where((topic) {
      if (topic.isArchived) return false;
      if (_status != null && topic.status != _status) return false;
      if (_classId == null) return true;
      final chapter = workspace.chapterById(topic.chapterId);
      if (chapter == null) return false;
      final subject = workspace.subjectById(chapter.subjectId);
      return subject?.classId == _classId;
    }).toList();

    final allTopics = workspace.topics
        .where((item) => !item.isArchived)
        .toList();
    final activeLessons = workspace.activeLessonPlans;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: state.isLoading
                ? null
                : () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = (constraints.maxWidth * 0.035)
                .clamp(12.0, 30.0)
                .toDouble();
            final wide = constraints.maxWidth >= 900;
            String classNameFor(String classId) =>
                workspace.classById(classId)?.name ?? 'Class';
            final lessonPanel = _LessonProgressPanel(
              lessons: lessons,
              workspace: workspace,
              onEdit: _editLessonProgress,
            );
            final topicPanel = _TopicProgressPanel(
              topics: topics,
              workspace: workspace,
              onEdit: _editTopicProgress,
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModernHeader(
                        className: _classId == null
                            ? 'All classes'
                            : classNameFor(_classId!),
                        onRefresh: state.isLoading
                            ? null
                            : () => ref
                                  .read(teachingPlannerProvider.notifier)
                                  .load(),
                      ),
                      const SizedBox(height: 18),
                      ProgressDashboard(
                        topics: allTopics,
                        lessons: activeLessons,
                        classNameFor: classNameFor,
                        now: DateTime.now(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Update teaching progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use filters to focus on one class or status, then record what was actually taught.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Filters(
                        classes: classes
                            .map((item) => (item.id, item.name))
                            .toList(),
                        classId: _classId,
                        status: _status,
                        onClassChanged: (value) =>
                            setState(() => _classId = value),
                        onStatusChanged: (value) =>
                            setState(() => _status = value),
                      ),
                      const SizedBox(height: 14),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: lessonPanel),
                            const SizedBox(width: 14),
                            Expanded(child: topicPanel),
                          ],
                        )
                      else ...[
                        lessonPanel,
                        const SizedBox(height: 14),
                        topicPanel,
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

  Future<void> _editLessonProgress(LessonPlan lesson) async {
    final draft = await showAdaptiveModalBottomSheet<_LessonProgressDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LessonProgressSheet(lesson: lesson),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .recordLessonProgress(
          lesson.id,
          status: draft.status,
          actualPeriods: draft.actualPeriods,
          taughtAt: draft.taughtAt,
          reflection: draft.reflection,
        );
    if (!mounted || ok) return;
    _showSaveError();
  }

  Future<void> _editTopicProgress(PlannerTopic topic) async {
    final draft = await showAdaptiveModalBottomSheet<_TopicProgressDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TopicProgressSheet(topic: topic),
    );
    if (draft == null || !mounted) return;
    final ok = await ref
        .read(teachingPlannerProvider.notifier)
        .updateTopicProgress(
          topic.id,
          status: draft.status,
          actualPeriods: draft.actualPeriods,
        );
    if (!mounted || ok) return;
    _showSaveError();
  }

  void _showSaveError() {
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _ModernHeader extends StatelessWidget {
  const _ModernHeader({required this.className, required this.onRefresh});
  final String className;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF36A7FF), Color(0xFF246BFD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Progress Tracking',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Track teaching progress, spot delays early and stay on target.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
        final controls = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_outlined, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    className,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
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
            children: [title, const SizedBox(height: 12), controls],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            controls,
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
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
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: classId,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All classes'),
                ),
                ...classes.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.$1,
                    child: Text(item.$2),
                  ),
                ),
              ],
              onChanged: onClassChanged,
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<TeachingProgressStatus?>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
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
            ),
          ),
        ],
      ),
    ),
  );
}

class _LessonProgressPanel extends StatelessWidget {
  const _LessonProgressPanel({
    required this.lessons,
    required this.workspace,
    required this.onEdit,
  });
  final List<LessonPlan> lessons;
  final dynamic workspace;
  final ValueChanged<LessonPlan> onEdit;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lesson execution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Record taught date, actual periods and reflection.'),
          const SizedBox(height: 12),
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No lessons match this filter.')),
            )
          else
            ...lessons.map((lesson) {
              final subject = workspace.subjectById(lesson.subjectId);
              final chapter = workspace.chapterById(lesson.chapterId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lesson.title),
                subtitle: Text(
                  '${subject?.name ?? 'Subject'} • ${chapter?.title ?? 'Chapter'}\n${_statusLabel(lesson.status)} • ${lesson.actualPeriods}/${lesson.plannedPeriods} periods',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Update lesson progress',
                  onPressed: () => onEdit(lesson),
                  icon: const Icon(Icons.edit_note_rounded),
                ),
              );
            }),
        ],
      ),
    ),
  );
}

class _TopicProgressPanel extends StatelessWidget {
  const _TopicProgressPanel({
    required this.topics,
    required this.workspace,
    required this.onEdit,
  });
  final List<PlannerTopic> topics;
  final dynamic workspace;
  final ValueChanged<PlannerTopic> onEdit;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Syllabus progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Track topic completion and actual syllabus periods.'),
          const SizedBox(height: 12),
          if (topics.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No topics match this filter.')),
            )
          else
            ...topics.map((topic) {
              final chapter = workspace.chapterById(topic.chapterId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(topic.title),
                subtitle: Text(
                  '${chapter?.title ?? 'Chapter'} • ${_statusLabel(topic.status)} • ${topic.actualPeriods}/${topic.plannedPeriods} periods',
                ),
                trailing: IconButton(
                  tooltip: 'Update topic progress',
                  onPressed: () => onEdit(topic),
                  icon: const Icon(Icons.track_changes_rounded),
                ),
              );
            }),
        ],
      ),
    ),
  );
}

class _LessonProgressDraft {
  const _LessonProgressDraft({
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

class _LessonProgressSheet extends StatefulWidget {
  const _LessonProgressSheet({required this.lesson});
  final LessonPlan lesson;

  @override
  State<_LessonProgressSheet> createState() => _LessonProgressSheetState();
}

class _LessonProgressSheetState extends State<_LessonProgressSheet> {
  late TeachingProgressStatus _status;
  late final TextEditingController _periods;
  late final TextEditingController _reflection;
  DateTime? _taughtAt;

  @override
  void initState() {
    super.initState();
    _status = widget.lesson.status;
    _periods = TextEditingController(
      text: widget.lesson.actualPeriods.toString(),
    );
    _reflection = TextEditingController(text: widget.lesson.reflection ?? '');
    _taughtAt = widget.lesson.taughtAt;
  }

  @override
  void dispose() {
    _periods.dispose();
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.lesson.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TeachingProgressStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Teaching status'),
              items: TeachingProgressStatus.values
                  .map(
                    (item) => DropdownMenuItem<TeachingProgressStatus>(
                      value: item,
                      child: Text(_statusLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _periods,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual periods'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: _taughtAt?.toLocal() ?? DateTime.now(),
                );
                if (date != null) setState(() => _taughtAt = date);
              },
              icon: const Icon(Icons.event_available_rounded),
              label: Text(
                _taughtAt == null
                    ? 'Set taught date'
                    : 'Taught: ${_taughtAt!.toLocal().toIso8601String().split('T').first}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reflection,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reflection / outcome note',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final periods = int.tryParse(_periods.text.trim());
                if (periods == null || periods < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Actual periods must be zero or more.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _LessonProgressDraft(
                    status: _status,
                    actualPeriods: periods,
                    taughtAt: _taughtAt,
                    reflection: _reflection.text.trim().isEmpty
                        ? null
                        : _reflection.text.trim(),
                  ),
                );
              },
              child: const Text('Save progress'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopicProgressDraft {
  const _TopicProgressDraft({
    required this.status,
    required this.actualPeriods,
  });
  final TeachingProgressStatus status;
  final int actualPeriods;
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.topic.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TeachingProgressStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Topic status'),
              items: TeachingProgressStatus.values
                  .map(
                    (item) => DropdownMenuItem<TeachingProgressStatus>(
                      value: item,
                      child: Text(_statusLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _periods,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual periods'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final periods = int.tryParse(_periods.text.trim());
                if (periods == null || periods < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Actual periods must be zero or more.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _TopicProgressDraft(status: _status, actualPeriods: periods),
                );
              },
              child: const Text('Save topic progress'),
            ),
          ],
        ),
      ),
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
