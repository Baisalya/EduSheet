import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_unit.dart';
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
        !state.isLoading) {
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
        onPressed: state.isLoading ? null : () => _openEditor(workspace),
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
              onCreate: state.isLoading ? null : () => _openEditor(workspace),
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
              onClassChanged: (value) => setState(() => _classFilter = value),
              onStatusChanged: (value) => setState(() => _statusFilter = value),
            ),
            const SizedBox(height: TeachingPlannerDesign.space16),
            TeachingPlannerResponsiveSplit(
              sideWidth: 280,
              sideFirstOnCompact: false,
              side: _LessonSummary(
                workspace: workspace,
                classId: _classFilter,
              ),
              primary: _LessonList(
                workspace: workspace,
                lessons: lessons,
                onOpen: _openLessonDetail,
                onEdit: (lesson) => _openEditor(workspace, lesson: lesson),
                onMarkTaught: _markLessonTaught,
                onReopen: _reopenLesson,
                onChapterStatus: _setChapterStatus,
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


  List<LessonPlan> _filteredLessons(TeachingPlannerWorkspace workspace) {
    final query = _searchController.text.trim().toLowerCase();
    return workspace.activeLessonPlans.where((lesson) {
      if (_classFilter != null && lesson.classId != _classFilter) return false;
      if (_statusFilter != null && lesson.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      final subject = workspace.subjectById(lesson.subjectId)?.name ?? '';
      final chapter = workspace.chapterById(lesson.chapterId)?.title ?? '';
      final topicText = lesson.topicIds
          .map((id) => workspace.topicById(id))
          .where((topic) => topic != null && !topic.isArchived)
          .map((topic) => topic!.title)
          .join(' ');
      return '${lesson.title} ${lesson.objective} $subject $chapter $topicText'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openEditor(
    TeachingPlannerWorkspace workspace, {
    LessonPlan? lesson,
    String? initialClassId,
    String? initialSubjectId,
    String? initialChapterId,
    DateTime? initialPlannedDate,
  }) async {
    final draft = await showAdaptiveModalBottomSheet<_LessonDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _LessonEditorSheet(
        workspace: workspace,
        lesson: lesson,
        initialClassId: lesson == null
            ? (initialClassId ?? widget.initialClassId)
            : null,
        initialSubjectId: lesson == null
            ? (initialSubjectId ?? widget.initialSubjectId)
            : null,
        initialChapterId: lesson == null
            ? (initialChapterId ?? widget.initialChapterId)
            : null,
        initialPlannedDate: lesson == null
            ? (initialPlannedDate ?? widget.initialPlannedDate)
            : null,
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
        return;
      }
      if (lesson == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lesson planned.'),
            action: SnackBarAction(
              label: 'Add another',
              onPressed: () {
                final current = ref.read(teachingPlannerProvider).workspace;
                _openEditor(
                  current,
                  initialClassId: draft.classId,
                  initialSubjectId: draft.subjectId,
                  initialChapterId: draft.chapterId,
                  initialPlannedDate: draft.plannedDate,
                );
              },
            ),
          ),
        );
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

  Future<void> _markLessonTaught(LessonPlan lesson) async {
    final notifier = ref.read(teachingPlannerProvider.notifier);
    final saved = await notifier.recordLessonProgress(
      lesson.id,
      status: TeachingProgressStatus.completed,
      actualPeriods: lesson.plannedPeriods,
      taughtAt: DateTime.now(),
      reflection: lesson.reflection,
    );
    if (!mounted) return;
    if (!saved) {
      _showSaveError();
      return;
    }
    final chapter = ref
        .read(teachingPlannerProvider)
        .workspace
        .chapterById(lesson.chapterId);
    if (chapter == null || chapter.status == TeachingProgressStatus.completed) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${chapter.title} stays in progress.'),
        action: SnackBarAction(
          label: 'Finish chapter',
          onPressed: () => _finishChapterFromLesson(lesson),
        ),
      ),
    );
  }

  Future<void> _reopenLesson(LessonPlan lesson) async {
    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .recordLessonProgress(
          lesson.id,
          status: TeachingProgressStatus.planned,
          actualPeriods: 0,
          taughtAt: null,
          reflection: lesson.reflection,
        );
    if (!mounted || saved) return;
    _showSaveError();
  }

  Future<void> _setChapterStatus(
    LessonPlan lesson,
    TeachingProgressStatus status,
  ) async {
    final saved = await ref
        .read(teachingPlannerProvider.notifier)
        .updateChapterProgress(lesson.chapterId, status: status);
    if (!mounted) return;
    if (!saved) {
      _showSaveError();
      return;
    }
    if (status == TeachingProgressStatus.completed) {
      _offerPlanNextChapter(lesson);
    }
  }

  Future<void> _finishChapterFromLesson(LessonPlan lesson) async {
    await _setChapterStatus(lesson, TeachingProgressStatus.completed);
  }

  void _offerPlanNextChapter(LessonPlan lesson) {
    final workspace = ref.read(teachingPlannerProvider).workspace;
    final nextChapterId = _nextChapterId(workspace, lesson.chapterId);
    if (nextChapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chapter completed.')),
      );
      return;
    }
    final nextChapter = workspace.chapterById(nextChapterId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextChapter == null
              ? 'Chapter completed.'
              : 'Chapter completed. Next: ${nextChapter.title}',
        ),
        action: SnackBarAction(
          label: 'Plan next',
          onPressed: () {
            final current = ref.read(teachingPlannerProvider).workspace;
            _openEditor(
              current,
              initialClassId: lesson.classId,
              initialSubjectId: lesson.subjectId,
              initialChapterId: nextChapterId,
              initialPlannedDate: lesson.plannedDate,
            );
          },
        ),
      ),
    );
  }

  String? _nextChapterId(
    TeachingPlannerWorkspace workspace,
    String chapterId,
  ) {
    final chapter = workspace.chapterById(chapterId);
    if (chapter == null) return null;
    final ordered = <PlannerChapter>[];
    for (final unit in workspace.activeUnitsForSubject(chapter.subjectId)) {
      ordered.addAll(
        workspace.activeChaptersForSubject(
          chapter.subjectId,
          unitId: unit.id,
        ),
      );
    }
    ordered.addAll(
      workspace.activeChaptersForSubject(chapter.subjectId, unitId: null),
    );
    final index = ordered.indexWhere((item) => item.id == chapterId);
    if (index < 0 || index + 1 >= ordered.length) return null;
    return ordered[index + 1].id;
  }

  void _showSaveError() {
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          final compact =
              constraints.maxWidth < TeachingPlannerBreakpoints.medium;
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: TeachingPlannerDesign.space4),
                        Text(
                          'Turn syllabus into teachable lessons',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
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
                'Keep every lesson connected to the real class, subject, chapter and topics. If something is missing, add it while planning without losing your lesson draft.',
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
            label: const Text('New lesson'),
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
            subtitle:
                'Search by lesson, objective or syllabus context, then narrow by class or status.',
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
              final statusDropdown =
                  DropdownButtonFormField<TeachingProgressStatus?>(
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
  const _LessonSummary({required this.workspace, this.classId});
  final TeachingPlannerWorkspace workspace;
  final String? classId;

  @override
  Widget build(BuildContext context) {
    final visibleClassIds = classId == null
        ? workspace.activeClasses.map((item) => item.id).toSet()
        : <String>{classId!};
    final subjects = workspace.subjects
        .where(
          (item) =>
              !item.isArchived && visibleClassIds.contains(item.classId),
        )
        .toList();
    final subjectIds = subjects.map((item) => item.id).toSet();
    final chapters = workspace.chapters
        .where(
          (item) =>
              !item.isArchived && subjectIds.contains(item.subjectId),
        )
        .toList();
    final completed = chapters
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final inProgress = chapters
        .where((item) => item.status == TeachingProgressStatus.inProgress)
        .length;
    final coverage = chapters.isEmpty ? 0.0 : completed / chapters.length;
    final units = workspace.units
        .where(
          (item) =>
              !item.isArchived && subjectIds.contains(item.subjectId),
        )
        .toList()
      ..sort((a, b) {
        final bySubject = a.subjectId.compareTo(b.subjectId);
        return bySubject != 0
            ? bySubject
            : a.sortOrder.compareTo(b.sortOrder);
      });

    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeachingPlannerSectionHeader(
            title: 'Syllabus progress',
            subtitle: 'Chapter completion rolls up automatically by unit.',
            icon: Icons.track_changes_outlined,
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          _SummaryMetric(
            label: 'Chapters complete',
            value: '$completed/${chapters.length}',
            icon: Icons.task_alt_rounded,
            tone: TeachingPlannerTone.teal,
          ),
          const SizedBox(height: TeachingPlannerDesign.space10),
          _SummaryMetric(
            label: 'In progress',
            value: '$inProgress',
            icon: Icons.timelapse_rounded,
            tone: TeachingPlannerTone.orange,
          ),
          const SizedBox(height: TeachingPlannerDesign.space12),
          LinearProgressIndicator(value: coverage),
          const SizedBox(height: TeachingPlannerDesign.space16),
          if (units.isNotEmpty) ...[
            Text(
              'Units',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: TeachingPlannerDesign.space8),
            for (final unit in units.take(6)) ...[
              _UnitProgressRow(
                label: subjects.length > 1
                    ? '${workspace.subjectById(unit.subjectId)?.name ?? 'Subject'} • ${unit.title}'
                    : unit.title,
                chapters: chapters
                    .where((item) => item.unitId == unit.id)
                    .toList(),
              ),
              const SizedBox(height: TeachingPlannerDesign.space8),
            ],
          ],
        ],
      ),
    );
  }
}

class _UnitProgressRow extends StatelessWidget {
  const _UnitProgressRow({required this.label, required this.chapters});

  final String label;
  final List<PlannerChapter> chapters;

  @override
  Widget build(BuildContext context) {
    final completed = chapters
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final inProgress = chapters
        .where((item) => item.status == TeachingProgressStatus.inProgress)
        .length;
    final progress = chapters.isEmpty ? 0.0 : completed / chapters.length;
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: TeachingPlannerDesign.space8),
            Text(
              '${chapters.isNotEmpty && completed == chapters.length ? '✓ ' : ''}$completed/${chapters.length}${inProgress > 0 ? ' • $inProgress active' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: TeachingPlannerDesign.space4),
        LinearProgressIndicator(value: progress),
      ],
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
          TeachingPlannerIconBadge(
            icon: icon,
            tone: tone,
            size: 36,
            iconSize: 19,
          ),
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
    required this.onMarkTaught,
    required this.onReopen,
    required this.onChapterStatus,
    required this.onArchive,
    required this.onMaterials,
  });
  final TeachingPlannerWorkspace workspace;
  final List<LessonPlan> lessons;
  final ValueChanged<LessonPlan> onOpen;
  final ValueChanged<LessonPlan> onEdit;
  final ValueChanged<LessonPlan> onMarkTaught;
  final ValueChanged<LessonPlan> onReopen;
  final void Function(LessonPlan, TeachingProgressStatus) onChapterStatus;
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

    final groups = <DateTime, List<LessonPlan>>{};
    for (final lesson in lessons) {
      final local = lesson.plannedDate.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => <LessonPlan>[]).add(lesson);
    }
    final days = groups.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeachingPlannerSectionHeader(
          title: 'Teaching days',
          subtitle:
              '${lessons.length} lesson${lessons.length == 1 ? '' : 's'} grouped by date. One class can finish one chapter and start another.',
          icon: Icons.today_outlined,
        ),
        const SizedBox(height: TeachingPlannerDesign.space12),
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
          _TeachingDayGroup(
            day: days[dayIndex],
            lessons: groups[days[dayIndex]]!,
            workspace: workspace,
            onOpen: onOpen,
            onEdit: onEdit,
            onMarkTaught: onMarkTaught,
            onReopen: onReopen,
            onChapterStatus: onChapterStatus,
            onArchive: onArchive,
            onMaterials: onMaterials,
          ),
          if (dayIndex != days.length - 1)
            const SizedBox(height: TeachingPlannerDesign.space16),
        ],
      ],
    );
  }
}

class _TeachingDayGroup extends StatelessWidget {
  const _TeachingDayGroup({
    required this.day,
    required this.lessons,
    required this.workspace,
    required this.onOpen,
    required this.onEdit,
    required this.onMarkTaught,
    required this.onReopen,
    required this.onChapterStatus,
    required this.onArchive,
    required this.onMaterials,
  });

  final DateTime day;
  final List<LessonPlan> lessons;
  final TeachingPlannerWorkspace workspace;
  final ValueChanged<LessonPlan> onOpen;
  final ValueChanged<LessonPlan> onEdit;
  final ValueChanged<LessonPlan> onMarkTaught;
  final ValueChanged<LessonPlan> onReopen;
  final void Function(LessonPlan, TeachingProgressStatus) onChapterStatus;
  final ValueChanged<LessonPlan> onArchive;
  final ValueChanged<LessonPlan> onMaterials;

  @override
  Widget build(BuildContext context) {
    final completed = lessons
        .where((item) => item.status == TeachingProgressStatus.completed)
        .length;
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _friendlyDateLabel(day),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              '$completed/${lessons.length} taught',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: TeachingPlannerDesign.space8),
        for (var index = 0; index < lessons.length; index++) ...[
          _LessonCard(
            workspace: workspace,
            lesson: lessons[index],
            onOpen: () => onOpen(lessons[index]),
            onEdit: () => onEdit(lessons[index]),
            onMarkTaught: () => onMarkTaught(lessons[index]),
            onReopen: () => onReopen(lessons[index]),
            onChapterStatus: (status) =>
                onChapterStatus(lessons[index], status),
            onArchive: () => onArchive(lessons[index]),
            onMaterials: () => onMaterials(lessons[index]),
          ),
          if (index != lessons.length - 1)
            const SizedBox(height: TeachingPlannerDesign.space10),
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
    required this.onMarkTaught,
    required this.onReopen,
    required this.onChapterStatus,
    required this.onArchive,
    required this.onMaterials,
  });

  final TeachingPlannerWorkspace workspace;
  final LessonPlan lesson;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onMarkTaught;
  final VoidCallback onReopen;
  final ValueChanged<TeachingProgressStatus> onChapterStatus;
  final VoidCallback onArchive;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final plannerClass = workspace.classById(lesson.classId)?.name ?? 'Class';
    final subject = workspace.subjectById(lesson.subjectId)?.name ?? 'Subject';
    final chapter = workspace.chapterById(lesson.chapterId);
    final chapterTitle = chapter?.title ?? 'Chapter';
    final unit = chapter?.unitId == null
        ? null
        : workspace.unitById(chapter!.unitId!);
    final tone = _toneForStatus(lesson.status);
    final taught = lesson.status == TeachingProgressStatus.completed;

    return TeachingPlannerSurfaceCard(
      key: ValueKey('lesson-card-${lesson.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: taught ? 'Mark lesson not taught' : 'Mark lesson taught',
                button: true,
                child: Checkbox(
                  key: ValueKey('lesson-taught-${lesson.id}'),
                  value: taught,
                  onChanged: (_) => taught ? onReopen() : onMarkTaught(),
                ),
              ),
              const SizedBox(width: TeachingPlannerDesign.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                            decoration:
                                taught ? TextDecoration.lineThrough : null,
                          ),
                    ),
                    const SizedBox(height: TeachingPlannerDesign.space4),
                    Text(
                      '$plannerClass • $subject${unit == null ? '' : ' • ${unit.title}'} • $chapterTitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Lesson actions',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'chapter-progress':
                      onChapterStatus(TeachingProgressStatus.inProgress);
                      break;
                    case 'chapter-complete':
                      onChapterStatus(TeachingProgressStatus.completed);
                      break;
                    case 'chapter-reopen':
                      onChapterStatus(TeachingProgressStatus.inProgress);
                      break;
                    case 'chapter-reset':
                      onChapterStatus(TeachingProgressStatus.planned);
                      break;
                    case 'archive':
                      onArchive();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit / move date'),
                  ),
                  if (chapter?.status != TeachingProgressStatus.inProgress &&
                      chapter?.status != TeachingProgressStatus.completed)
                    const PopupMenuItem(
                      value: 'chapter-progress',
                      child: Text('Chapter in progress'),
                    ),
                  if (chapter?.status != TeachingProgressStatus.completed)
                    const PopupMenuItem(
                      value: 'chapter-complete',
                      child: Text('Finish chapter'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'chapter-reopen',
                      child: Text('Reopen chapter'),
                    ),
                  if (chapter?.status == TeachingProgressStatus.inProgress)
                    const PopupMenuItem(
                      value: 'chapter-reset',
                      child: Text('Reset chapter progress'),
                    ),
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          const SizedBox(height: TeachingPlannerDesign.space8),
          Wrap(
            spacing: TeachingPlannerDesign.space8,
            runSpacing: TeachingPlannerDesign.space8,
            children: [
              TeachingPlannerPill(
                label: '${lesson.plannedPeriods} period${lesson.plannedPeriods == 1 ? '' : 's'}',
                icon: Icons.schedule_outlined,
                tone: TeachingPlannerTone.purple,
              ),
              TeachingPlannerPill(
                label: taught ? 'Taught' : _statusLabel(lesson.status),
                tone: tone,
              ),
              TeachingPlannerPill(
                label: _chapterStatusLabel(chapter?.status),
                icon: Icons.account_tree_outlined,
                tone: _toneForStatus(
                  chapter?.status ?? TeachingProgressStatus.planned,
                ),
              ),
            ],
          ),
          if (lesson.objective.trim().isNotEmpty) ...[
            const SizedBox(height: TeachingPlannerDesign.space10),
            Text(
              lesson.objective,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.ink, height: 1.35),
            ),
          ],
          const SizedBox(height: TeachingPlannerDesign.space10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onMaterials,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Materials'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonEditorSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_LessonEditorSheet> createState() => _LessonEditorSheetState();
}

class _LessonEditorSheetState extends ConsumerState<_LessonEditorSheet> {
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
  String? _preferredUnitId;
  String? _autoTitle;
  int _selectionRevision = 0;
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
    final requestedClassExists =
        requestedClassId != null &&
        widget.workspace.activeClasses.any(
          (item) => item.id == requestedClassId,
        );
    _classId =
        lesson?.classId ??
        (requestedClassExists
            ? requestedClassId
            : widget.workspace.activeClasses.isEmpty
            ? null
            : widget.workspace.activeClasses.first.id);
    _subjectId = lesson?.subjectId ?? widget.initialSubjectId;
    _chapterId = lesson?.chapterId ?? widget.initialChapterId;
    _topicIds = {...?lesson?.topicIds};
    _date =
        lesson?.plannedDate.toLocal() ??
        widget.initialPlannedDate?.toLocal() ??
        DateTime.now();
    _status = lesson?.status ?? TeachingProgressStatus.planned;
    _normalizeSelections(widget.workspace);
    if (lesson == null) _seedTitleFromChapter(widget.workspace);
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

  void _normalizeSelections([TeachingPlannerWorkspace? source]) {
    final workspace = source ?? ref.read(teachingPlannerProvider).workspace;
    final subjects = _classId == null
        ? const []
        : workspace.activeSubjectsForClass(_classId!);
    if (_subjectId == null || !subjects.any((item) => item.id == _subjectId)) {
      _subjectId = subjects.isEmpty ? null : subjects.first.id;
    }
    final units = _subjectId == null
        ? const []
        : workspace.activeUnitsForSubject(_subjectId!);
    if (_preferredUnitId != null &&
        !units.any((item) => item.id == _preferredUnitId)) {
      _preferredUnitId = null;
    }
    final chapters = _chaptersForSelectedSubject(workspace);
    if (_chapterId == null || !chapters.any((item) => item.id == _chapterId)) {
      _chapterId = chapters.isEmpty ? null : chapters.first.id;
    }
    final validTopicIds = _chapterId == null
        ? <String>{}
        : workspace
              .activeTopicsForChapter(_chapterId!)
              .map((item) => item.id)
              .toSet();
    _topicIds = _topicIds.intersection(validTopicIds);
  }

  List<PlannerChapter> _chaptersForSelectedSubject(
    TeachingPlannerWorkspace workspace,
  ) {
    if (_subjectId == null) return <PlannerChapter>[];
    final result = <PlannerChapter>[];
    for (final unit in workspace.activeUnitsForSubject(_subjectId!)) {
      result.addAll(
        workspace.activeChaptersForSubject(
          _subjectId!,
          unitId: unit.id,
        ),
      );
    }
    result.addAll(
      workspace.activeChaptersForSubject(_subjectId!, unitId: null),
    );
    return result;
  }

  void _seedTitleFromChapter([TeachingPlannerWorkspace? source]) {
    if (widget.lesson != null || _chapterId == null) return;
    final workspace = source ?? ref.read(teachingPlannerProvider).workspace;
    final chapter = workspace.chapterById(_chapterId!);
    if (chapter == null) return;
    final current = _title.text.trim();
    if (current.isEmpty || current == _autoTitle) {
      _title.text = chapter.title;
    }
    _autoTitle = chapter.title;
  }

  String _chapterLabel(
    TeachingPlannerWorkspace workspace,
    PlannerChapter chapter,
  ) {
    final unit = chapter.unitId == null
        ? null
        : workspace.unitById(chapter.unitId!);
    return unit == null ? chapter.title : '${unit.title} · ${chapter.title}';
  }


  T? _findCreated<T>(
    Iterable<T> values,
    Set<String> beforeIds,
    String Function(T value) idOf,
  ) {
    for (final value in values.toList().reversed) {
      if (!beforeIds.contains(idOf(value))) return value;
    }
    return null;
  }

  void _showMutationError() {
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _quickAddClass() async {
    final input = await showDialog<_QuickNameDraft>(
      context: context,
      builder: (context) => const _QuickNameDialog(
        title: 'Add class',
        label: 'Class name',
        hintText: 'For example, Class 8A',
        secondaryLabel: 'Academic year (optional)',
        secondaryHintText: 'For example, 2026–27',
      ),
    );
    if (input == null || !mounted) return;

    final before = ref.read(teachingPlannerProvider).workspace;
    final beforeIds = before.classes.map((item) => item.id).toSet();
    final saved = await ref.read(teachingPlannerProvider.notifier).createClass(
          name: input.name,
          academicYear: input.secondary,
        );
    if (!mounted) return;
    if (!saved) {
      _showMutationError();
      return;
    }
    final fresh = ref.read(teachingPlannerProvider).workspace;
    final created = _findCreated(
      fresh.activeClasses,
      beforeIds,
      (item) => item.id,
    );
    if (created == null) return;
    setState(() {
      _classId = created.id;
      _subjectId = null;
      _chapterId = null;
      _preferredUnitId = null;
      _topicIds.clear();
      _selectionRevision++;
      _normalizeSelections(fresh);
    });
  }

  Future<void> _quickAddSubject() async {
    if (_classId == null) return;
    final input = await showDialog<_QuickNameDraft>(
      context: context,
      builder: (context) => const _QuickNameDialog(
        title: 'Add subject',
        label: 'Subject name',
        hintText: 'For example, Mathematics',
      ),
    );
    if (input == null || !mounted) return;

    final before = ref.read(teachingPlannerProvider).workspace;
    final beforeIds = before.subjects.map((item) => item.id).toSet();
    final saved = await ref.read(teachingPlannerProvider.notifier).createSubject(
          classId: _classId!,
          name: input.name,
        );
    if (!mounted) return;
    if (!saved) {
      _showMutationError();
      return;
    }
    final fresh = ref.read(teachingPlannerProvider).workspace;
    final created = _findCreated(
      fresh.activeSubjectsForClass(_classId!),
      beforeIds,
      (item) => item.id,
    );
    if (created == null) return;
    setState(() {
      _subjectId = created.id;
      _chapterId = null;
      _preferredUnitId = null;
      _topicIds.clear();
      _selectionRevision++;
      _normalizeSelections(fresh);
    });
  }

  Future<void> _quickAddUnit() async {
    if (_subjectId == null) return;
    final input = await showDialog<_QuickNameDraft>(
      context: context,
      builder: (context) => const _QuickNameDialog(
        title: 'Add unit',
        label: 'Unit name',
        hintText: 'For example, Algebra',
      ),
    );
    if (input == null || !mounted) return;

    final before = ref.read(teachingPlannerProvider).workspace;
    final beforeIds = before.units.map((item) => item.id).toSet();
    final saved = await ref.read(teachingPlannerProvider.notifier).createUnit(
          subjectId: _subjectId!,
          title: input.name,
        );
    if (!mounted) return;
    if (!saved) {
      _showMutationError();
      return;
    }
    final fresh = ref.read(teachingPlannerProvider).workspace;
    final created = _findCreated(
      fresh.activeUnitsForSubject(_subjectId!),
      beforeIds,
      (item) => item.id,
    );
    if (created == null) return;
    setState(() {
      _preferredUnitId = created.id;
    });
  }

  Future<void> _quickAddChapter() async {
    if (_subjectId == null) return;
    final current = ref.read(teachingPlannerProvider).workspace;
    final currentChapter = _chapterId == null
        ? null
        : current.chapterById(_chapterId!);
    final input = await showDialog<_QuickChapterDraft>(
      context: context,
      builder: (context) => _QuickChapterDialog(
        units: current.activeUnitsForSubject(_subjectId!),
        initialUnitId: _preferredUnitId ?? currentChapter?.unitId,
      ),
    );
    if (input == null || !mounted) return;

    final before = ref.read(teachingPlannerProvider).workspace;
    final beforeIds = before.chapters.map((item) => item.id).toSet();
    final saved = await ref.read(teachingPlannerProvider.notifier).createChapter(
          subjectId: _subjectId!,
          unitId: input.unitId,
          title: input.title,
        );
    if (!mounted) return;
    if (!saved) {
      _showMutationError();
      return;
    }
    final fresh = ref.read(teachingPlannerProvider).workspace;
    final created = _findCreated(
      _chaptersForSelectedSubject(fresh),
      beforeIds,
      (item) => item.id,
    );
    if (created == null) return;
    setState(() {
      _chapterId = created.id;
      _preferredUnitId = input.unitId;
      _topicIds.clear();
      _selectionRevision++;
      _seedTitleFromChapter(fresh);
    });
  }

  Future<void> _quickAddTopic() async {
    if (_chapterId == null) return;
    final input = await showDialog<_QuickNameDraft>(
      context: context,
      builder: (context) => const _QuickNameDialog(
        title: 'Add topic',
        label: 'Topic name',
        hintText: 'For example, Solving one-step equations',
      ),
    );
    if (input == null || !mounted) return;

    final before = ref.read(teachingPlannerProvider).workspace;
    final beforeIds = before.topics.map((item) => item.id).toSet();
    final saved = await ref.read(teachingPlannerProvider.notifier).createTopic(
          chapterId: _chapterId!,
          title: input.name,
        );
    if (!mounted) return;
    if (!saved) {
      _showMutationError();
      return;
    }
    final fresh = ref.read(teachingPlannerProvider).workspace;
    final created = _findCreated(
      fresh.activeTopicsForChapter(_chapterId!),
      beforeIds,
      (item) => item.id,
    );
    if (created == null) return;
    setState(() {
      _topicIds.add(created.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plannerState = ref.watch(teachingPlannerProvider);
    final workspace = plannerState.workspace;
    final subjects = _classId == null
        ? const []
        : workspace.activeSubjectsForClass(_classId!);
    final chapters = _chaptersForSelectedSubject(workspace);
    final topics = _chapterId == null
        ? const []
        : workspace.activeTopicsForChapter(_chapterId!);
    final editing = widget.lesson != null;

    return TeachingPlannerSheetFrame(
      title: editing ? 'Edit lesson' : 'Plan lesson',
      subtitle: editing
          ? 'Adjust the chapter, date or details. Your syllabus structure stays unchanged.'
          : 'Pick what you will teach and when. If something is missing, add it here without leaving the lesson.',
      icon: Icons.edit_calendar_rounded,
      action: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check_rounded),
        label: Text(editing ? 'Save changes' : 'Plan lesson'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeachingPlannerSectionHeader(
              title: 'What will you teach?',
              subtitle: 'Select the syllabus chapter. Unit is inferred automatically.',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            LayoutBuilder(
              key: ValueKey('lesson-editor-hierarchy-$_selectionRevision'),
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 660;
                final classField = DropdownButtonFormField<String>(
                  key: const ValueKey('lesson-editor-class-field'),
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: workspace.activeClasses
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
                    _preferredUnitId = null;
                    _normalizeSelections(workspace);
                    _seedTitleFromChapter(workspace);
                  }),
                  validator: (value) =>
                      value == null ? 'Choose a class.' : null,
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
                    _preferredUnitId = null;
                    _normalizeSelections(workspace);
                    _seedTitleFromChapter(workspace);
                  }),
                  validator: (value) =>
                      value == null ? 'Choose a subject.' : null,
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
                            _chapterLabel(workspace, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _chapterId = value;
                    _topicIds.clear();
                    _seedTitleFromChapter(workspace);
                  }),
                  validator: (value) =>
                      value == null ? 'Choose a chapter.' : null,
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
            if (!editing) ...[
              const SizedBox(height: TeachingPlannerDesign.space10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Missing something? Add it here — this lesson draft stays open.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: TeachingPlannerTheme.colorsOf(context).inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: TeachingPlannerDesign.space8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: TeachingPlannerDesign.space6,
                  runSpacing: TeachingPlannerDesign.space6,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('lesson-quick-add-class'),
                      onPressed: _quickAddClass,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Class'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('lesson-quick-add-subject'),
                      onPressed: _classId == null ? null : _quickAddSubject,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Subject'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('lesson-quick-add-unit'),
                      onPressed: _subjectId == null ? null : _quickAddUnit,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Unit'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('lesson-quick-add-chapter'),
                      onPressed: _subjectId == null ? null : _quickAddChapter,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Chapter'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('lesson-quick-add-topic'),
                      onPressed: _chapterId == null ? null : _quickAddTopic,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Topic'),
                    ),
                  ],
                ),
              ),
              if (_preferredUnitId != null &&
                  workspace.unitById(_preferredUnitId!) != null) ...[
                const SizedBox(height: TeachingPlannerDesign.space6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TeachingPlannerPill(
                    label:
                        'New chapter unit: ${workspace.unitById(_preferredUnitId!)!.title}',
                    icon: Icons.folder_outlined,
                    tone: TeachingPlannerTone.primary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: TeachingPlannerDesign.space18),
            const TeachingPlannerSectionHeader(
              title: 'When?',
              subtitle: 'Today and one period are the default.',
              icon: Icons.today_outlined,
            ),
            const SizedBox(height: TeachingPlannerDesign.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 500;
                final dateButton = OutlinedButton.icon(
                  key: const ValueKey('lesson-editor-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateLabel(_date)),
                );
                final periodsField = TextFormField(
                  key: const ValueKey('lesson-editor-periods'),
                  controller: _periods,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Periods',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 1
                        ? 'Enter 1 or more.'
                        : null;
                  },
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateButton,
                      const SizedBox(height: TeachingPlannerDesign.space10),
                      periodsField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: dateButton),
                    const SizedBox(width: TeachingPlannerDesign.space10),
                    SizedBox(width: 180, child: periodsField),
                  ],
                );
              },
            ),
            const SizedBox(height: TeachingPlannerDesign.space16),
            ExpansionTile(
              key: const ValueKey('lesson-editor-more-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(
                bottom: TeachingPlannerDesign.space8,
              ),
              title: const Text('Add teaching details (optional)'),
              subtitle: const Text(
                'Title, objective, topics, materials, activities, homework and notes',
              ),
              leading: const Icon(Icons.tune_rounded),
              children: [
                TextFormField(
                  key: const ValueKey('lesson-editor-title'),
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Lesson title (optional)',
                    helperText: 'Defaults to the selected chapter name.',
                  ),
                ),
                const SizedBox(height: TeachingPlannerDesign.space10),
                TextFormField(
                  controller: _objective,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Learning objective (optional)',
                  ),
                ),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: TeachingPlannerDesign.space12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Topics (optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
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
                  ),
                ],
                if (editing) ...[
                  const SizedBox(height: TeachingPlannerDesign.space10),
                  DropdownButtonFormField<TeachingProgressStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Lesson status'),
                    items: TeachingProgressStatus.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_statusLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                ],
                const SizedBox(height: TeachingPlannerDesign.space10),
                _optionalField(_materials, 'Materials / resources'),
                const SizedBox(height: TeachingPlannerDesign.space10),
                _optionalField(_activities, 'Teaching activities'),
                const SizedBox(height: TeachingPlannerDesign.space10),
                _optionalField(_homework, 'Homework / follow-up'),
                const SizedBox(height: TeachingPlannerDesign.space10),
                _optionalField(_notes, 'Teacher notes'),
              ],
            ),
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
    final chapterTitle = ref
            .read(teachingPlannerProvider)
            .workspace
            .chapterById(_chapterId!)
            ?.title ??
        'Lesson';
    final title = _title.text.trim().isEmpty ? chapterTitle : _title.text.trim();
    Navigator.pop(
      context,
      _LessonDraft(
        classId: _classId!,
        subjectId: _subjectId!,
        chapterId: _chapterId!,
        topicIds: _topicIds.toList(),
        title: title,
        plannedDate: _date,
        plannedPeriods: int.parse(_periods.text.trim()),
        objective: _objective.text.trim().isEmpty
            ? 'Teach $chapterTitle.'
            : _objective.text.trim(),
        materials: _nullIfBlank(_materials.text),
        activities: _nullIfBlank(_activities.text),
        homework: _nullIfBlank(_homework.text),
        notes: _nullIfBlank(_notes.text),
        status: _status,
      ),
    );
  }
}


class _QuickNameDraft {
  const _QuickNameDraft({required this.name, this.secondary});

  final String name;
  final String? secondary;
}

class _QuickNameDialog extends StatefulWidget {
  const _QuickNameDialog({
    required this.title,
    required this.label,
    this.hintText,
    this.secondaryLabel,
    this.secondaryHintText,
  });

  final String title;
  final String label;
  final String? hintText;
  final String? secondaryLabel;
  final String? secondaryHintText;

  @override
  State<_QuickNameDialog> createState() => _QuickNameDialogState();
}

class _QuickNameDialogState extends State<_QuickNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _secondary = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _secondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('lesson-quick-add-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hintText,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '${widget.label} is required.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (widget.secondaryLabel != null) ...[
                const SizedBox(height: TeachingPlannerDesign.space12),
                TextFormField(
                  key: const ValueKey('lesson-quick-add-secondary'),
                  controller: _secondary,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.secondaryLabel,
                    hintText: widget.secondaryHintText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('lesson-quick-add-save'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _QuickNameDraft(
        name: _name.text.trim(),
        secondary: _secondary.text.trim().isEmpty
            ? null
            : _secondary.text.trim(),
      ),
    );
  }
}

class _QuickChapterDraft {
  const _QuickChapterDraft({required this.title, this.unitId});

  final String title;
  final String? unitId;
}

class _QuickChapterDialog extends StatefulWidget {
  const _QuickChapterDialog({
    required this.units,
    this.initialUnitId,
  });

  final List<PlannerUnit> units;
  final String? initialUnitId;

  @override
  State<_QuickChapterDialog> createState() => _QuickChapterDialogState();
}

class _QuickChapterDialogState extends State<_QuickChapterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String? _unitId;

  @override
  void initState() {
    super.initState();
    _unitId = widget.units.any((item) => item.id == widget.initialUnitId)
        ? widget.initialUnitId
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add chapter'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('lesson-quick-add-chapter-name'),
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Chapter name',
                  hintText: 'For example, Linear Equations',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Chapter name is required.'
                    : null,
              ),
              const SizedBox(height: TeachingPlannerDesign.space12),
              DropdownButtonFormField<String?>(
                key: const ValueKey('lesson-quick-add-chapter-unit'),
                initialValue: _unitId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  helperText: 'Leave empty if this chapter is not inside a unit.',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No unit'),
                  ),
                  ...widget.units.map(
                    (unit) => DropdownMenuItem<String?>(
                      value: unit.id,
                      child: Text(
                        unit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('lesson-quick-add-chapter-save'),
          onPressed: _submit,
          child: const Text('Add chapter'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _QuickChapterDraft(title: _title.text.trim(), unitId: _unitId),
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

TeachingPlannerTone _toneForStatus(TeachingProgressStatus status) =>
    switch (status) {
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

String _chapterStatusLabel(TeachingProgressStatus? status) => switch (status) {
  TeachingProgressStatus.completed => 'Chapter complete',
  TeachingProgressStatus.inProgress => 'Chapter in progress',
  TeachingProgressStatus.skipped => 'Chapter skipped',
  TeachingProgressStatus.rescheduled => 'Chapter moved',
  _ => 'Chapter not started',
};

String _friendlyDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = DateTime(date.year, date.month, date.day);
  if (value == today) return 'Today';
  if (value == today.add(const Duration(days: 1))) return 'Tomorrow';
  if (value == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return _dateLabel(value);
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String? _nullIfBlank(String value) =>
    value.trim().isEmpty ? null : value.trim();
