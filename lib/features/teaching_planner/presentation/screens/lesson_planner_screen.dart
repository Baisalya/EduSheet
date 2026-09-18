import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../navigation/teaching_planner_navigation.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/teaching_planner_page_shell.dart';
import '../widgets/teaching_planner_responsive_content.dart';
import '../widgets/teaching_planner_shared_components.dart';
import 'lesson_detail_screen.dart';
import 'teaching_workspace_screen.dart';

class LessonPlannerScreen extends ConsumerStatefulWidget {
  const LessonPlannerScreen({
    super.key,
    this.openCreateOnStart = false,
    this.returnAfterInitialCreate = false,
    this.initialClassId,
    this.initialSubjectId,
    this.initialChapterId,
    this.initialPlannedDate,
  });

  final bool openCreateOnStart;
  final bool returnAfterInitialCreate;
  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialChapterId;
  final DateTime? initialPlannedDate;

  @override
  ConsumerState<LessonPlannerScreen> createState() =>
      _LessonPlannerScreenState();
}

class _LessonPlannerScreenState extends ConsumerState<LessonPlannerScreen> {
  final _searchController = TextEditingController();
  String? _classFilter;
  TeachingProgressStatus? _statusFilter;
  bool _initialCreateScheduled = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final lessons = _filteredLessons(workspace);

    if (widget.openCreateOnStart &&
        !_initialCreateScheduled &&
        _canCreateLesson(workspace)) {
      _initialCreateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openEditor(ref.read(teachingPlannerProvider).workspace);
      });
    }

    return TeachingPlannerPageShell(
      title: 'Lesson Planner',
      currentDestination: TeachingPlannerDestination.lessons,
      showGlobalNavigation:
          !widget.returnAfterInitialCreate && widget.initialPlannedDate == null,
      actions: [
        IconButton(
          tooltip: 'Refresh lesson plans',
          onPressed: state.isLoading
              ? null
              : () => ref.read(teachingPlannerProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: workspace.activeClasses.isEmpty
            ? null
            : () => _openEditor(workspace),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Lesson'),
      ),
      body: TeachingPlannerResponsiveContent(
        bottomPadding: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LessonHeader(
              workspace: workspace,
              onCreate: workspace.activeClasses.isEmpty
                  ? null
                  : () => _openEditor(workspace),
            ),
            const SizedBox(height: TeachingPlannerDesign.space16),
            if (state.errorMessage != null) ...[
              TeachingPlannerSurfaceCard(
                tone: TeachingPlannerTone.coral,
                tint: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TeachingPlannerIconBadge(
                      icon: Icons.error_outline_rounded,
                      tone: TeachingPlannerTone.coral,
                    ),
                    const SizedBox(width: TeachingPlannerDesign.space12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(teachingPlannerProvider.notifier).load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space16),
            ],
            _Filters(
              workspace: workspace,
              controller: _searchController,
              classFilter: _classFilter,
              statusFilter: _statusFilter,
              onSearchChanged: (_) => setState(() {}),
              onClassChanged: (value) =>
                  setState(() => _classFilter = value),
              onStatusChanged: (value) =>
                  setState(() => _statusFilter = value),
            ),
            const SizedBox(height: TeachingPlannerDesign.space16),
            TeachingPlannerResponsiveSplit(
              sideWidth: 280,
              side: _LessonSummary(workspace: workspace),
              primary: _LessonList(
                workspace: workspace,
                lessons: lessons,
                onOpen: _openLessonDetail,
                onEdit: (lesson) => _openEditor(workspace, lesson: lesson),
                onArchive: _archiveLesson,
                onMaterials: (lesson) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TeachingWorkspaceScreen(initialLessonId: lesson.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateLesson(TeachingPlannerWorkspace workspace) {
    final activeClassIds = workspace.activeClasses.map((item) => item.id).toSet();
    final activeSubjects = workspace.subjects.where(
      (item) => !item.isArchived && activeClassIds.contains(item.classId),
    );
    final activeSubjectIds = activeSubjects.map((item) => item.id).toSet();
    return workspace.chapters.any(
      (item) => !item.isArchived && activeSubjectIds.contains(item.subjectId),
    );
  }

  List<LessonPlan> _filteredLessons(TeachingPlannerWorkspace workspace) {
    final query = _searchController.text.trim().toLowerCase();
    return workspace.activeLessonPlans.where((lesson) {
      if (_classFilter != null && lesson.classId != _classFilter) return false;
      if (_statusFilter != null && lesson.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      final subject = workspace.subjectById(lesson.subjectId)?.name ?? '';
      final chapter = workspace.chapterById(lesson.chapterId)?.title ?? '';
      final topicText = lesson.topicIds
          .map((id) => workspace.topicById(id)?.title ?? '')
          .join(' ');
      return '${lesson.title} ${lesson.objective} $subject $chapter $topicText'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openEditor(
    TeachingPlannerWorkspace workspace, {
    LessonPlan? lesson,
  }) async {
    final draft = await showAdaptiveModalBottomSheet<_LessonDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _LessonEditorSheet(
        workspace: workspace,
        lesson: lesson,
        initialClassId: lesson == null ? widget.initialClassId : null,
        initialSubjectId: lesson == null ? widget.initialSubjectId : null,
        initialChapterId: lesson == null ? widget.initialChapterId : null,
        initialPlannedDate: lesson == null ? widget.initialPlannedDate : null,
      ),
    );
    if (draft == null || !mounted) return;
    final notifier = ref.read(teachingPlannerProvider.notifier);
    final saved = lesson == null
        ? await notifier.createLessonPlan(
            classId: draft.classId,
            subjectId: draft.subjectId,
            chapterId: draft.chapterId,
            topicIds: draft.topicIds,
            title: draft.title,
            plannedDate: draft.plannedDate,
            plannedPeriods: draft.plannedPeriods,
            objective: draft.objective,
            materials: draft.materials,
            activities: draft.activities,
            homework: draft.homework,
            notes: draft.notes,
            status: draft.status,
          )
        : await notifier.updateLessonPlan(
            lesson,
            classId: draft.classId,
            subjectId: draft.subjectId,
            chapterId: draft.chapterId,
            topicIds: draft.topicIds,
            title: draft.title,
            plannedDate: draft.plannedDate,
            plannedPeriods: draft.plannedPeriods,
            objective: draft.objective,
            materials: draft.materials,
            activities: draft.activities,
            homework: draft.homework,
            notes: draft.notes,
            status: draft.status,
          );
    if (!mounted) return;
    if (saved) {
      if (lesson == null &&
          widget.openCreateOnStart &&
          widget.returnAfterInitialCreate) {
        Navigator.of(context).pop();
      }
      return;
    }
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openLessonDetail(LessonPlan lesson) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonDetailScreen(lessonId: lesson.id),
      ),
    );
  }

  Future<void> _archiveLesson(LessonPlan lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive lesson?'),
        content: Text(
          '“${lesson.title}” will be hidden from active lesson plans but kept in local data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(teachingPlannerProvider.notifier)
        .archiveLessonPlan(lesson.id);
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.workspace, required this.onCreate});
  final TeachingPlannerWorkspace workspace;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      tone: TeachingPlannerTone.primary,
      tint: true,
      borderRadius: TeachingPlannerDesign.radiusHero,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < TeachingPlannerBreakpoints.medium;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const TeachingPlannerIconBadge(
                    icon: Icons.menu_book_rounded,
                    size: 46,
                    iconSize: 24,
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan lessons',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space4),
                        Text(
                          'Turn syllabus into teachable lessons',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TeachingPlannerDesign.space12),
              Text(
                'Keep every lesson connected to the real class, subject, chapter and topics. Plan objectives, periods, materials, activities, homework and notes without changing the syllabus structure.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space14),
              Wrap(
                spacing: TeachingPlannerDesign.space8,
                runSpacing: TeachingPlannerDesign.space8,
                children: [
                  TeachingPlannerPill(
                    label: '${workspace.activeClasses.length} classes',
                    icon: Icons.school_outlined,
                    tone: TeachingPlannerTone.primary,
                  ),
                  TeachingPlannerPill(
                    label: '${workspace.activeLessonPlans.length} lessons',
                    icon: Icons.event_note_rounded,
                    tone: TeachingPlannerTone.teal,
                  ),
                ],
              ),
            ],
          );

          final action = FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              workspace.activeClasses.isEmpty ? 'Add syllabus first' : 'New lesson',
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: TeachingPlannerDesign.space16),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: TeachingPlannerDesign.space20),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.workspace,
    required this.controller,
    required this.classFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onClassChanged,
    required this.onStatusChanged,
  });
  final TeachingPlannerWorkspace workspace;
  final TextEditingController controller;
  final String? classFilter;
  final TeachingProgressStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<TeachingProgressStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Find a lesson',
            subtitle: 'Search by lesson, objective or syllabus context, then narrow by class or status.',
            icon: Icons.filter_alt_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final search = TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search lessons',
                ),
              );
              final classDropdown = DropdownButtonFormField<String?>(
                initialValue: classFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  ...workspace.activeClasses.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onClassChanged,
              );
              final statusDropdown = DropdownButtonFormField<TeachingProgressStatus?>(
                initialValue: statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<TeachingProgressStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  ...TeachingProgressStatus.values.map(
                    (status) => DropdownMenuItem<TeachingProgressStatus?>(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  ),
                ],
                onChanged: onStatusChanged,
              );

              if (compact) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: TeachingPlannerDesign.space10),
                    Row(
                      children: [
                        Expanded(child: classDropdown),
                        const SizedBox(width: TeachingPlannerDesign.space10),
                        Expanded(child: statusDropdown),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: search),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(child: classDropdown),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(child: statusDropdown),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LessonSummary extends StatelessWidget {
  const _LessonSummary({required this.workspace});
  final TeachingPlannerWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final lessons = workspace.activeLessonPlans;
    final completed = lessons
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final plannedPeriods = lessons.fold<int>(
      0,
      (sum, item) => sum + item.plannedPeriods,
    );
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Lesson overview',
            subtitle: 'Live totals from your active lesson plans.',
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          _SummaryMetric(
            label: 'Active lessons',
            value: '${lessons.length}',
            icon: Icons.menu_book_outlined,
            tone: TeachingPlannerTone.primary,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryMetric(
            label: 'Completed',
            value: '$completed',
            icon: Icons.task_alt_rounded,
            tone: TeachingPlannerTone.teal,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryMetric(
            label: 'Planned periods',
            value: '$plannedPeriods',
            icon: Icons.schedule_outlined,
            tone: TeachingPlannerTone.purple,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space12),
      decoration: BoxDecoration(
        color: tone.background(colors),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
        border: Border.all(
          color: tone.foreground(colors).withValues(alpha: .14),
        ),
      ),
      child: Row(
        children: [
          TeachingPlannerIconBadge(icon: icon, tone: tone, size: 36, iconSize: 19),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({
    required this.workspace,
    required this.lessons,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onMaterials,
  });
  final TeachingPlannerWorkspace workspace;
  final List<LessonPlan> lessons;
  final ValueChanged<LessonPlan> onOpen;
  final ValueChanged<LessonPlan> onEdit;
  final ValueChanged<LessonPlan> onArchive;
  final ValueChanged<LessonPlan> onMaterials;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const TeachingPlannerEmptyState(
        icon: Icons.event_note_outlined,
        title: 'No matching lessons',
        message: 'Create a lesson or change the current filters.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeachingPlannerSectionHeader(
          title: 'Lessons',
          subtitle: '${lessons.length} matching lesson${lessons.length == 1 ? '' : 's'}',
          icon: Icons.view_agenda_outlined,
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        for (var index = 0; index < lessons.length; index++) ...[
          _LessonCard(
            workspace: workspace,
            lesson: lessons[index],
            onOpen: () => onOpen(lessons[index]),
            onEdit: () => onEdit(lessons[index]),
            onArchive: () => onArchive(lessons[index]),
            onMaterials: () => onMaterials(lessons[index]),
          ),
          if (index != lessons.length - 1)
            const SizedBox(height: TeachingPlannerDesign.space12),
        ],
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.workspace,
    required this.lesson,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onMaterials,
  });

  final TeachingPlannerWorkspace workspace;
  final LessonPlan lesson;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final plannerClass = workspace.classById(lesson.classId)?.name ?? 'Class';
    final subject = workspace.subjectById(lesson.subjectId)?.name ?? 'Subject';
    final chapter = workspace.chapterById(lesson.chapterId)?.title ?? 'Chapter';
    final tone = _toneForStatus(lesson.status);

    return TeachingPlannerSurfaceCard(
      key: ValueKey('lesson-card-${lesson.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeachingPlannerIconBadge(
                icon: Icons.menu_book_rounded,
                tone: tone,
                size: 42,
                iconSize: 21,
              ),
              const SizedBox(width: TeachingPlannerDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space4),
                    Text(
                      '$plannerClass • $subject • $chapter',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Lesson actions',
                onSelected: (value) => value == 'edit' ? onEdit() : onArchive(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Wrap(
            spacing: TeachingPlannerDesign.space8,
            runSpacing: TeachingPlannerDesign.space8,
            children: [
              TeachingPlannerPill(
                label: _dateLabel(lesson.plannedDate),
                icon: Icons.calendar_today_outlined,
              ),
              TeachingPlannerPill(
                label: '${lesson.plannedPeriods} periods',
                icon: Icons.schedule_outlined,
                tone: TeachingPlannerTone.purple,
              ),
              TeachingPlannerPill(
                label: _statusLabel(lesson.status),
                tone: tone,
              ),
              if (lesson.topicIds.isNotEmpty)
                TeachingPlannerPill(
                  label: '${lesson.topicIds.length} topics',
                  icon: Icons.topic_outlined,
                  tone: TeachingPlannerTone.teal,
                ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Text(
            lesson.objective,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onMaterials,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Teaching materials'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonEditorSheet extends StatefulWidget {
  const _LessonEditorSheet({
    required this.workspace,
    this.lesson,
    this.initialClassId,
    this.initialSubjectId,
    this.initialChapterId,
    this.initialPlannedDate,
  });
  final TeachingPlannerWorkspace workspace;
  final LessonPlan? lesson;
  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialChapterId;
  final DateTime? initialPlannedDate;
  @override
  State<_LessonEditorSheet> createState() => _LessonEditorSheetState();
}

class _LessonEditorSheetState extends State<_LessonEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _periods;
  late final TextEditingController _objective;
  late final TextEditingController _materials;
  late final TextEditingController _activities;
  late final TextEditingController _homework;
  late final TextEditingController _notes;
  String? _classId;
  String? _subjectId;
  String? _chapterId;
  late Set<String> _topicIds;
  late DateTime _date;
  late TeachingProgressStatus _status;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _title = TextEditingController(text: lesson?.title ?? '');
    _periods = TextEditingController(text: '${lesson?.plannedPeriods ?? 1}');
    _objective = TextEditingController(text: lesson?.objective ?? '');
    _materials = TextEditingController(text: lesson?.materials ?? '');
    _activities = TextEditingController(text: lesson?.activities ?? '');
    _homework = TextEditingController(text: lesson?.homework ?? '');
    _notes = TextEditingController(text: lesson?.notes ?? '');
    final requestedClassId = widget.initialClassId;
    final requestedClassExists = requestedClassId != null &&
        widget.workspace.activeClasses.any((item) => item.id == requestedClassId);
    _classId = lesson?.classId ??
        (requestedClassExists
            ? requestedClassId
            : widget.workspace.activeClasses.isEmpty
                ? null
                : widget.workspace.activeClasses.first.id);
    _subjectId = lesson?.subjectId ?? widget.initialSubjectId;
    _chapterId = lesson?.chapterId ?? widget.initialChapterId;
    _topicIds = {...?lesson?.topicIds};
    _date = lesson?.plannedDate.toLocal() ??
        widget.initialPlannedDate?.toLocal() ??
        DateTime.now();
    _status = lesson?.status ?? TeachingProgressStatus.planned;
    _normalizeSelections();
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _periods,
      _objective,
      _materials,
      _activities,
      _homework,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _normalizeSelections() {
    final subjects = _classId == null
        ? const []
        : widget.workspace.activeSubjectsForClass(_classId!);
    if (_subjectId == null || !subjects.any((item) => item.id == _subjectId)) {
      _subjectId = subjects.isEmpty ? null : subjects.first.id;
    }
    final chapters = _chaptersForSelectedSubject();
    if (_chapterId == null || !chapters.any((item) => item.id == _chapterId)) {
      _chapterId = chapters.isEmpty ? null : chapters.first.id;
    }
    final validTopicIds = _chapterId == null
        ? <String>{}
        : widget.workspace
              .activeTopicsForChapter(_chapterId!)
              .map((item) => item.id)
              .toSet();
    _topicIds = _topicIds.intersection(validTopicIds);
  }

  List<PlannerChapter> _chaptersForSelectedSubject() {
    if (_subjectId == null) return <PlannerChapter>[];
    final result = widget.workspace.chapters
        .where((item) => item.subjectId == _subjectId && !item.isArchived)
        .toList();
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _classId == null
        ? const []
        : widget.workspace.activeSubjectsForClass(_classId!);
    final chapters = _chaptersForSelectedSubject();
    final topics = _chapterId == null
        ? const []
        : widget.workspace.activeTopicsForChapter(_chapterId!);
    final editing = widget.lesson != null;

    return TeachingPlannerSheetFrame(
      title: editing ? 'Edit lesson' : 'Create lesson',
      subtitle:
          'Link the lesson to the existing syllabus, then add only the teaching details you actually need.',
      icon: Icons.edit_calendar_rounded,
      action: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.save_outlined),
        label: Text(editing ? 'Save lesson' : 'Create lesson'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeachingPlannerSectionHeader(
              title: 'Syllabus link',
              subtitle: 'Choose the real class, subject and chapter for this lesson.',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 660;
                final classField = DropdownButtonFormField<String>(
                  key: const ValueKey('lesson-editor-class-field'),
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.workspace.activeClasses
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _classId = value;
                    _subjectId = null;
                    _chapterId = null;
                    _topicIds.clear();
                    _normalizeSelections();
                  }),
                  validator: (value) => value == null ? 'Choose a class.' : null,
                );
                final subjectField = DropdownButtonFormField<String>(
                  key: const ValueKey('lesson-editor-subject-field'),
                  initialValue: _subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _subjectId = value;
                    _chapterId = null;
                    _topicIds.clear();
                    _normalizeSelections();
                  }),
                  validator: (value) => value == null ? 'Choose a subject.' : null,
                );
                final chapterField = DropdownButtonFormField<String>(
                  key: const ValueKey('lesson-editor-chapter-field'),
                  initialValue: _chapterId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chapter'),
                  items: chapters
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _chapterId = value;
                    _topicIds.clear();
                  }),
                  validator: (value) => value == null ? 'Choose a chapter.' : null,
                );

                if (compact) {
                  return Column(
                    children: [
                      classField,
                      const SizedBox(height: TeachingPlannerDesign.space10),
                      subjectField,
                      const SizedBox(height: TeachingPlannerDesign.space10),
                      chapterField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: classField),
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    Expanded(child: subjectField),
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    Expanded(child: chapterField),
                  ],
                );
              },
            ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: TeachingPlannerDesign.space14),
              Text(
                'Topics (optional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space8),
              Wrap(
                spacing: TeachingPlannerDesign.space8,
                runSpacing: TeachingPlannerDesign.space8,
                children: topics
                    .map(
                      (topic) => FilterChip(
                        selected: _topicIds.contains(topic.id),
                        label: Text(topic.title),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _topicIds.add(topic.id)
                              : _topicIds.remove(topic.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: TeachingPlannerDesign.space20),
            const TeachingPlannerSectionHeader(
              title: 'Teaching plan',
              subtitle: 'Title, objective, timing and status stay editable without changing syllabus data.',
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Lesson title'),
              validator: _required,
            ),
            const SizedBox(height: TeachingPlannerDesign.space10),
            TextFormField(
              controller: _objective,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Learning objective'),
              validator: _required,
            ),
            const SizedBox(height: TeachingPlannerDesign.space10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final dateButton = OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateLabel(_date)),
                );
                final periodsField = TextFormField(
                  controller: _periods,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Periods'),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0
                        ? 'Enter 0 or more.'
                        : null;
                  },
                );
                final statusField = DropdownButtonFormField<TeachingProgressStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: TeachingProgressStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            _statusLabel(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateButton,
                      const SizedBox(height: TeachingPlannerDesign.space10),
                      Row(
                        children: [
                          Expanded(child: periodsField),
                          const SizedBox(width: TeachingPlannerDesign.space10),
                          Expanded(child: statusField),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    dateButton,
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    SizedBox(width: 150, child: periodsField),
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    Expanded(child: statusField),
                  ],
                );
              },
            ),
            const SizedBox(height: TeachingPlannerDesign.space20),
            const TeachingPlannerSectionHeader(
              title: 'Optional teaching details',
              subtitle: 'Use the fields that are useful for this lesson; blank fields remain blank.',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            _optionalField(_materials, 'Materials / resources'),
            const SizedBox(height: TeachingPlannerDesign.space10),
            _optionalField(_activities, 'Teaching activities'),
            const SizedBox(height: TeachingPlannerDesign.space10),
            _optionalField(_homework, 'Homework / follow-up'),
            const SizedBox(height: TeachingPlannerDesign.space10),
            _optionalField(_notes, 'Teacher notes'),
          ],
        ),
      ),
    );
  }

  Widget _optionalField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(labelText: label),
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required.' : null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        _classId == null ||
        _subjectId == null ||
        _chapterId == null) {
      return;
    }
    Navigator.pop(
      context,
      _LessonDraft(
        classId: _classId!,
        subjectId: _subjectId!,
        chapterId: _chapterId!,
        topicIds: _topicIds.toList(),
        title: _title.text.trim(),
        plannedDate: _date,
        plannedPeriods: int.parse(_periods.text.trim()),
        objective: _objective.text.trim(),
        materials: _nullIfBlank(_materials.text),
        activities: _nullIfBlank(_activities.text),
        homework: _nullIfBlank(_homework.text),
        notes: _nullIfBlank(_notes.text),
        status: _status,
      ),
    );
  }
}

class _LessonDraft {
  const _LessonDraft({
    required this.classId,
    required this.subjectId,
    required this.chapterId,
    required this.topicIds,
    required this.title,
    required this.plannedDate,
    required this.plannedPeriods,
    required this.objective,
    this.materials,
    this.activities,
    this.homework,
    this.notes,
    required this.status,
  });
  final String classId;
  final String subjectId;
  final String chapterId;
  final List<String> topicIds;
  final String title;
  final DateTime plannedDate;
  final int plannedPeriods;
  final String objective;
  final String? materials;
  final String? activities;
  final String? homework;
  final String? notes;
  final TeachingProgressStatus status;
}

TeachingPlannerTone _toneForStatus(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => TeachingPlannerTone.primary,
  TeachingProgressStatus.inProgress => TeachingPlannerTone.orange,
  TeachingProgressStatus.completed => TeachingPlannerTone.teal,
  TeachingProgressStatus.skipped => TeachingPlannerTone.neutral,
  TeachingProgressStatus.rescheduled => TeachingPlannerTone.purple,
};

String _statusLabel(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.planned => 'Planned',
  TeachingProgressStatus.inProgress => 'In progress',
  TeachingProgressStatus.completed => 'Completed',
  TeachingProgressStatus.skipped => 'Skipped',
  TeachingProgressStatus.rescheduled => 'Rescheduled',
};

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String? _nullIfBlank(String value) =>
    value.trim().isEmpty ? null : value.trim();
