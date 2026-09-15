import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../providers/teaching_planner_provider.dart';
import 'teaching_workspace_screen.dart';

class LessonPlannerScreen extends ConsumerStatefulWidget {
  const LessonPlannerScreen({super.key});

  @override
  ConsumerState<LessonPlannerScreen> createState() =>
      _LessonPlannerScreenState();
}

class _LessonPlannerScreenState extends ConsumerState<LessonPlannerScreen> {
  final _searchController = TextEditingController();
  String? _classFilter;
  TeachingProgressStatus? _statusFilter;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Planner'),
        actions: [
          IconButton(
            tooltip: 'Refresh lesson plans',
            onPressed: state.isLoading
                ? null
                : () => ref.read(teachingPlannerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: workspace.activeClasses.isEmpty
            ? null
            : () => _openEditor(workspace),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Lesson'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = (constraints.maxWidth * 0.035).clamp(12.0, 28.0);
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LessonHeader(
                        workspace: workspace,
                        onCreate: workspace.activeClasses.isEmpty
                            ? null
                            : () => _openEditor(workspace),
                      ),
                      const SizedBox(height: 16),
                      if (state.errorMessage != null) ...[
                        MaterialBanner(
                          content: Text(state.errorMessage!),
                          actions: [
                            TextButton(
                              onPressed: () => ref
                                  .read(teachingPlannerProvider.notifier)
                                  .load(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 260,
                              child: _LessonSummary(workspace: workspace),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _LessonList(
                                workspace: workspace,
                                lessons: lessons,
                                onEdit: (lesson) =>
                                    _openEditor(workspace, lesson: lesson),
                                onArchive: _archiveLesson,
                                onMaterials: (lesson) =>
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TeachingWorkspaceScreen(
                                          initialLessonId: lesson.id,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _LessonSummary(workspace: workspace),
                        const SizedBox(height: 16),
                        _LessonList(
                          workspace: workspace,
                          lessons: lessons,
                          onEdit: (lesson) =>
                              _openEditor(workspace, lesson: lesson),
                          onArchive: _archiveLesson,
                          onMaterials: (lesson) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeachingWorkspaceScreen(
                                initialLessonId: lesson.id,
                              ),
                            ),
                          ),
                        ),
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
      builder: (context) =>
          _LessonEditorSheet(workspace: workspace, lesson: lesson),
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
    if (!mounted || saved) return;
    final message = ref.read(teachingPlannerProvider).errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 38, color: scheme.secondary),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turn syllabus into teachable lessons',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Attach every lesson to the real class, subject, chapter and topics. Plan objectives, periods, materials, activities, homework and notes.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                workspace.activeClasses.isEmpty
                    ? 'Add syllabus first'
                    : 'New lesson',
              ),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 430),
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search lessons',
                  isDense: true,
                ),
              ),
            ),
            DropdownButton<String?>(
              value: classFilter,
              hint: const Text('All classes'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All classes'),
                ),
                ...workspace.activeClasses.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: onClassChanged,
            ),
            DropdownButton<TeachingProgressStatus?>(
              value: statusFilter,
              hint: const Text('All statuses'),
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
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Lesson overview',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 14),
            _SummaryRow(label: 'Active lessons', value: '${lessons.length}'),
            _SummaryRow(label: 'Completed', value: '$completed'),
            _SummaryRow(label: 'Planned periods', value: '$plannedPeriods'),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _LessonList extends StatelessWidget {
  const _LessonList({
    required this.workspace,
    required this.lessons,
    required this.onEdit,
    required this.onArchive,
    required this.onMaterials,
  });
  final TeachingPlannerWorkspace workspace;
  final List<LessonPlan> lessons;
  final ValueChanged<LessonPlan> onEdit;
  final ValueChanged<LessonPlan> onArchive;
  final ValueChanged<LessonPlan> onMaterials;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined, size: 42),
              SizedBox(height: 10),
              Text(
                'No matching lessons',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Create a lesson or change the current filters.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: lessons.map((lesson) {
        final plannerClass =
            workspace.classById(lesson.classId)?.name ?? 'Class';
        final subject =
            workspace.subjectById(lesson.subjectId)?.name ?? 'Subject';
        final chapter =
            workspace.chapterById(lesson.chapterId)?.title ?? 'Chapter';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$plannerClass • $subject • $chapter'),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          value == 'edit' ? onEdit(lesson) : onArchive(lesson),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'archive', child: Text('Archive')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(_dateLabel(lesson.plannedDate)),
                      avatar: const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                      ),
                    ),
                    Chip(
                      label: Text('${lesson.plannedPeriods} periods'),
                      avatar: const Icon(Icons.schedule_outlined, size: 16),
                    ),
                    Chip(label: Text(_statusLabel(lesson.status))),
                    if (lesson.topicIds.isNotEmpty)
                      Chip(label: Text('${lesson.topicIds.length} topics')),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lesson.objective,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => onMaterials(lesson),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Teaching materials'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LessonEditorSheet extends StatefulWidget {
  const _LessonEditorSheet({required this.workspace, this.lesson});
  final TeachingPlannerWorkspace workspace;
  final LessonPlan? lesson;
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
    _classId =
        lesson?.classId ??
        (widget.workspace.activeClasses.isEmpty
            ? null
            : widget.workspace.activeClasses.first.id);
    _subjectId = lesson?.subjectId;
    _chapterId = lesson?.chapterId;
    _topicIds = {...?lesson?.topicIds};
    _date = lesson?.plannedDate.toLocal() ?? DateTime.now();
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.lesson == null ? 'Create lesson' : 'Edit lesson',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Class'),
                items: widget.workspace.activeClasses
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
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
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: subjects
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _subjectId = value;
                  _chapterId = null;
                  _topicIds.clear();
                  _normalizeSelections();
                }),
                validator: (value) =>
                    value == null ? 'Choose a subject.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _chapterId,
                decoration: const InputDecoration(labelText: 'Chapter'),
                items: chapters
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _chapterId = value;
                  _topicIds.clear();
                }),
                validator: (value) =>
                    value == null ? 'Choose a chapter.' : null,
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Topics (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Lesson title'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _objective,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Learning objective',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_dateLabel(_date)),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      controller: _periods,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Periods'),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed < 0
                            ? 'Enter 0 or more.'
                            : null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<TeachingProgressStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _optionalField(_materials, 'Materials / resources'),
              const SizedBox(height: 12),
              _optionalField(_activities, 'Teaching activities'),
              const SizedBox(height: 12),
              _optionalField(_homework, 'Homework / follow-up'),
              const SizedBox(height: 12),
              _optionalField(_notes, 'Teacher notes'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  widget.lesson == null ? 'Create lesson' : 'Save lesson',
                ),
              ),
            ],
          ),
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
        _chapterId == null)
      return;
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
