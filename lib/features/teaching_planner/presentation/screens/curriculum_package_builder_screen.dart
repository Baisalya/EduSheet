import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../editor/presentation/providers/editor_provider.dart';
import '../../application/curriculum_package_builder_service.dart';
import '../../data/curriculum_eds_package_codec.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/curriculum_package.dart';
import '../../domain/models/teaching_planner_capabilities.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/repositories/curriculum_merge_repository.dart';
import '../providers/teaching_planner_provider.dart';
import '../widgets/teaching_planner_page_shell.dart';

class CurriculumPackageBuilderScreen extends ConsumerStatefulWidget {
  const CurriculumPackageBuilderScreen({
    super.key,
    this.initialClassId,
    this.initialSubjectId,
    this.initialUnitId,
    this.initialChapterId,
  });

  final String? initialClassId;
  final String? initialSubjectId;
  final String? initialUnitId;
  final String? initialChapterId;

  @override
  ConsumerState<CurriculumPackageBuilderScreen> createState() =>
      _CurriculumPackageBuilderScreenState();
}

class _CurriculumPackageBuilderScreenState
    extends ConsumerState<CurriculumPackageBuilderScreen> {
  late CurriculumPackageScopeKind _scopeKind;
  String? _classId;
  String? _subjectId;
  final Set<String> _unitIds = <String>{};
  final Set<String> _chapterIds = <String>{};
  final Set<String> _lessonIds = <String>{};
  bool _teacherAssignment = false;
  bool _includeLessonPlans = true;
  bool _includeNotes = true;
  bool _includeFiles = true;
  bool _includeLinks = true;
  bool _includeGeometry = true;
  bool _includePapers = true;
  bool _exporting = false;

  final _schoolController = TextEditingController();
  final _teacherController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _subjectId = widget.initialSubjectId;
    if (widget.initialChapterId != null) {
      _scopeKind = CurriculumPackageScopeKind.selectedChapters;
      _chapterIds.add(widget.initialChapterId!);
    } else if (widget.initialUnitId != null) {
      _scopeKind = CurriculumPackageScopeKind.selectedUnits;
      _unitIds.add(widget.initialUnitId!);
    } else if (_subjectId != null) {
      _scopeKind = CurriculumPackageScopeKind.subject;
    } else if (_classId != null) {
      _scopeKind = CurriculumPackageScopeKind.classSyllabus;
    } else {
      _scopeKind = CurriculumPackageScopeKind.schoolCurriculum;
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _teacherController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teachingPlannerProvider);
    final workspace = state.workspace;
    final capabilities = ref.watch(teachingPlannerCapabilitiesProvider);
    final canExport = capabilities.allows(
      TeachingPlannerCapability.richCurriculumExport,
    );
    _repairSelection(workspace);

    return TeachingPlannerPageShell(
      title: 'Share curriculum',
      showGlobalNavigation: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 980
                ? 920.0
                : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Curriculum package builder',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose only the curriculum a teacher or another EduSheet device should receive. Export stays offline and does not change your planner.',
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: '1. Scope',
                      child: Column(
                        children: [
                          DropdownButtonFormField<CurriculumPackageScopeKind>(
                            initialValue: _scopeKind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Package scope',
                              border: OutlineInputBorder(),
                            ),
                            items: CurriculumPackageScopeKind.values
                                .map(
                                  (kind) => DropdownMenuItem(
                                    value: kind,
                                    child: Text(_scopeLabel(kind)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _exporting
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _scopeKind = value;
                                      _unitIds.clear();
                                      _chapterIds.clear();
                                      _lessonIds.clear();
                                    });
                                  },
                          ),
                          if (_scopeKind !=
                              CurriculumPackageScopeKind.schoolCurriculum) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'curriculum-class:${_classId ?? ''}',
                              ),
                              initialValue: _classId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Class',
                                border: OutlineInputBorder(),
                              ),
                              items: workspace.activeClasses
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(
                                        item.academicYear == null
                                            ? item.name
                                            : '${item.name} · ${item.academicYear}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _exporting
                                  ? null
                                  : (value) => setState(() {
                                      _classId = value;
                                      _subjectId = null;
                                      _unitIds.clear();
                                      _chapterIds.clear();
                                      _lessonIds.clear();
                                    }),
                            ),
                          ],
                          if (_needsSubject) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'curriculum-subject:${_classId ?? ''}:${_subjectId ?? ''}',
                              ),
                              initialValue: _subjectId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                                border: OutlineInputBorder(),
                              ),
                              items: _classId == null
                                  ? const <DropdownMenuItem<String>>[]
                                  : workspace
                                        .activeSubjectsForClass(_classId!)
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item.id,
                                            child: Text(item.name),
                                          ),
                                        )
                                        .toList(growable: false),
                              onChanged: _exporting
                                  ? null
                                  : (value) => setState(() {
                                      _subjectId = value;
                                      _unitIds.clear();
                                      _chapterIds.clear();
                                      _lessonIds.clear();
                                    }),
                            ),
                          ],
                          if (_scopeKind ==
                              CurriculumPackageScopeKind.selectedUnits)
                            _UnitSelector(
                              workspace: workspace,
                              subjectId: _subjectId,
                              selected: _unitIds,
                              enabled: !_exporting,
                              onChanged: (id, selected) => setState(() {
                                selected
                                    ? _unitIds.add(id)
                                    : _unitIds.remove(id);
                              }),
                            ),
                          if (_scopeKind ==
                              CurriculumPackageScopeKind.selectedChapters)
                            _ChapterSelector(
                              workspace: workspace,
                              subjectId: _subjectId,
                              selected: _chapterIds,
                              enabled: !_exporting,
                              onChanged: (id, selected) => setState(() {
                                selected
                                    ? _chapterIds.add(id)
                                    : _chapterIds.remove(id);
                              }),
                            ),
                          if (_scopeKind ==
                              CurriculumPackageScopeKind.selectedLessons)
                            _LessonSelector(
                              workspace: workspace,
                              subjectId: _subjectId,
                              selected: _lessonIds,
                              enabled: !_exporting,
                              onChanged: (id, selected) => setState(() {
                                selected
                                    ? _lessonIds.add(id)
                                    : _lessonIds.remove(id);
                              }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: '2. Include',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _toggle(
                            'Lesson plans',
                            _scopeKind ==
                                    CurriculumPackageScopeKind.selectedLessons
                                ? true
                                : _includeLessonPlans,
                            (v) => _includeLessonPlans = v,
                            enabled:
                                _scopeKind !=
                                CurriculumPackageScopeKind.selectedLessons,
                          ),
                          _toggle(
                            'Notes',
                            _includeNotes,
                            (v) => _includeNotes = v,
                          ),
                          _toggle(
                            'Files',
                            _includeFiles,
                            (v) => _includeFiles = v,
                          ),
                          _toggle(
                            'Links',
                            _includeLinks,
                            (v) => _includeLinks = v,
                          ),
                          _toggle(
                            'Geometry',
                            _includeGeometry,
                            (v) => _includeGeometry = v,
                          ),
                          _toggle(
                            'Saved papers',
                            _includePapers,
                            (v) => _includePapers = v,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: '3. Principal / teacher assignment',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Create teacher assignment pack'),
                            subtitle: const Text(
                              'Exports the same selected scope as contentType: teacherPack. Offline metadata expresses intent; it is not server-enforced permission.',
                            ),
                            value: _teacherAssignment,
                            onChanged: _exporting
                                ? null
                                : (value) => setState(
                                    () => _teacherAssignment = value,
                                  ),
                          ),
                          TextField(
                            controller: _schoolController,
                            enabled: !_exporting,
                            decoration: const InputDecoration(
                              labelText: 'School / institution (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_teacherAssignment) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherController,
                              enabled: !_exporting,
                              decoration: const InputDecoration(
                                labelText: 'Teacher name / label (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteController,
                              enabled: !_exporting,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Assignment note (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PackageSummary(
                      workspace: workspace,
                      selection: _selection,
                      teacherAssignment: _teacherAssignment,
                    ),
                    if (!canExport) ...[
                      const SizedBox(height: 12),
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.lock_outline_rounded),
                          title: Text('Teaching Planner Pro required'),
                          subtitle: Text(
                            'Advanced curriculum and teacher-assignment sharing is a Pro convenience. Your syllabus, lessons, progress and personal backups remain available on Free.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed:
                            !canExport ||
                                _exporting ||
                                workspace.isEmpty ||
                                !_selectionReady
                            ? null
                            : () => _export(workspace),
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _teacherAssignment
                              ? 'Export teacher .eds'
                              : 'Export curriculum .eds',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _selectionReady => switch (_scopeKind) {
    CurriculumPackageScopeKind.schoolCurriculum => true,
    CurriculumPackageScopeKind.classSyllabus => _classId != null,
    CurriculumPackageScopeKind.subject =>
      _classId != null && _subjectId != null,
    CurriculumPackageScopeKind.selectedUnits =>
      _classId != null && _subjectId != null && _unitIds.isNotEmpty,
    CurriculumPackageScopeKind.selectedChapters =>
      _classId != null && _subjectId != null && _chapterIds.isNotEmpty,
    CurriculumPackageScopeKind.selectedLessons =>
      _classId != null && _subjectId != null && _lessonIds.isNotEmpty,
  };

  bool get _needsSubject =>
      _scopeKind == CurriculumPackageScopeKind.subject ||
      _scopeKind == CurriculumPackageScopeKind.selectedUnits ||
      _scopeKind == CurriculumPackageScopeKind.selectedChapters ||
      _scopeKind == CurriculumPackageScopeKind.selectedLessons;

  CurriculumPackageSelection get _selection => switch (_scopeKind) {
    CurriculumPackageScopeKind.schoolCurriculum => CurriculumPackageSelection(
      kind: _scopeKind,
    ),
    CurriculumPackageScopeKind.classSyllabus => CurriculumPackageSelection(
      kind: _scopeKind,
      classId: _classId,
    ),
    CurriculumPackageScopeKind.subject => CurriculumPackageSelection(
      kind: _scopeKind,
      classId: _classId,
      subjectId: _subjectId,
    ),
    CurriculumPackageScopeKind.selectedUnits => CurriculumPackageSelection(
      kind: _scopeKind,
      classId: _classId,
      subjectId: _subjectId,
      unitIds: _unitIds,
    ),
    CurriculumPackageScopeKind.selectedChapters => CurriculumPackageSelection(
      kind: _scopeKind,
      classId: _classId,
      subjectId: _subjectId,
      chapterIds: _chapterIds,
    ),
    CurriculumPackageScopeKind.selectedLessons => CurriculumPackageSelection(
      kind: _scopeKind,
      classId: _classId,
      subjectId: _subjectId,
      lessonPlanIds: _lessonIds,
    ),
  };

  Widget _toggle(
    String label,
    bool value,
    ValueChanged<bool> write, {
    bool enabled = true,
  }) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: _exporting || !enabled
          ? null
          : (next) => setState(() => write(next)),
    );
  }

  void _repairSelection(TeachingPlannerWorkspace workspace) {
    if (_classId != null && workspace.classById(_classId!) == null) {
      _classId = null;
      _subjectId = null;
      _unitIds.clear();
      _chapterIds.clear();
      _lessonIds.clear();
    }
    if (_subjectId != null) {
      final subject = workspace.subjectById(_subjectId!);
      if (subject == null || subject.classId != _classId) {
        _subjectId = null;
        _unitIds.clear();
        _chapterIds.clear();
        _lessonIds.clear();
      }
    }
    _unitIds.removeWhere((id) {
      final unit = workspace.unitById(id);
      return unit == null || unit.subjectId != _subjectId || unit.isArchived;
    });
    _chapterIds.removeWhere((id) {
      final chapter = workspace.chapterById(id);
      return chapter == null ||
          chapter.subjectId != _subjectId ||
          chapter.isArchived;
    });
    _lessonIds.removeWhere((id) {
      final lesson = workspace.lessonPlanById(id);
      return lesson == null ||
          lesson.subjectId != _subjectId ||
          lesson.isArchived;
    });
  }

  Future<void> _export(TeachingPlannerWorkspace workspace) async {
    setState(() => _exporting = true);
    try {
      final inclusions = CurriculumPackageInclusions(
        includeLessonPlans:
            _scopeKind == CurriculumPackageScopeKind.selectedLessons
            ? true
            : _includeLessonPlans,
        includeNotes: _includeNotes,
        includeFiles: _includeFiles,
        includeLinks: _includeLinks,
        includeGeometry: _includeGeometry,
        includePapers: _includePapers,
      );
      final plannerRepository = ref.read(teachingPlannerRepositoryProvider);
      var exportWorkspace = workspace;
      CurriculumMergeState? mergeState;
      final mergeRepository = switch (plannerRepository) {
        CurriculumMergeRepository mergeRepository => mergeRepository,
        _ => null,
      };
      if (mergeRepository != null) {
        final snapshot = await mergeRepository.loadCurriculumMergeSnapshot();
        exportWorkspace = snapshot.workspace;
        mergeState = snapshot.mergeState;
      }
      final assignment = _teacherAssignment
          ? CurriculumAssignmentMetadata(
              assignmentId: _assignmentId(exportWorkspace, _selection),
              assignedTo: _textOrNull(_teacherController.text),
              sourceSchool: _textOrNull(_schoolController.text),
              note: _textOrNull(_noteController.text),
            )
          : null;
      final service = CurriculumPackageBuilderService(
        resourceFileStore: ref.read(teachingResourceFileStoreProvider),
        paperRepository: ref.read(paperRepositoryProvider),
      );
      final sourceSchool = _textOrNull(_schoolController.text);
      final build = await service.build(
        source: exportWorkspace,
        selection: _selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: sourceSchool,
        mergeState: mergeState,
      );
      final source = const CurriculumEdsPackageCodec().encode(
        build: build,
        selection: _selection,
        inclusions: inclusions,
        assignment: assignment,
        sourceSchool: sourceSchool,
      );
      final fileName = '${_safeFileName(build.title)}.eds';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: _teacherAssignment
            ? 'Save teacher assignment pack'
            : 'Save EduSheet curriculum package',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['eds'],
      );
      if (path == null) return;
      final finalPath = path.toLowerCase().endsWith('.eds')
          ? path
          : '$path.eds';
      await File(finalPath).writeAsString(source, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _teacherAssignment
                ? 'Teacher assignment .eds saved. Recipient EduSheet can validate and merge it by canonical origin without deleting teacher-local work.'
                : 'Curriculum .eds saved successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is CurriculumPackageBuildException
                ? error.message
                : 'Curriculum package could not be created. Your planner was not changed.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _assignmentId(
    TeachingPlannerWorkspace workspace,
    CurriculumPackageSelection selection,
  ) {
    final school = _stable(_schoolController.text, fallback: 'school');
    final teacher = _stable(_teacherController.text, fallback: 'teacher');
    final year = selection.classId == null
        ? 'all-years'
        : _stable(
            workspace.classById(selection.classId!)?.academicYear ?? '',
            fallback: 'year',
          );
    final scope = switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum => 'school',
      CurriculumPackageScopeKind.classSyllabus => 'class:${selection.classId}',
      CurriculumPackageScopeKind.subject => 'subject:${selection.subjectId}',
      CurriculumPackageScopeKind.selectedUnits =>
        'units:${(_unitIds.toList()..sort()).join(',')}',
      CurriculumPackageScopeKind.selectedChapters =>
        'chapters:${(_chapterIds.toList()..sort()).join(',')}',
      CurriculumPackageScopeKind.selectedLessons =>
        'lessons:${(_lessonIds.toList()..sort()).join(',')}',
    };
    return 'assignment:$school:$teacher:$year:$scope';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.workspace,
    required this.subjectId,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final TeachingPlannerWorkspace workspace;
  final String? subjectId;
  final Set<String> selected;
  final bool enabled;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (subjectId == null) return const SizedBox.shrink();
    final units =
        workspace.units
            .where((item) => item.subjectId == subjectId && !item.isArchived)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Units', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (units.isEmpty) const Text('No active units in this subject.'),
          for (final unit in units)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(unit.id),
              onChanged: enabled
                  ? (value) => onChanged(unit.id, value ?? false)
                  : null,
              title: Text(unit.title),
            ),
        ],
      ),
    );
  }
}

class _ChapterSelector extends StatelessWidget {
  const _ChapterSelector({
    required this.workspace,
    required this.subjectId,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final TeachingPlannerWorkspace workspace;
  final String? subjectId;
  final Set<String> selected;
  final bool enabled;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (subjectId == null) return const SizedBox.shrink();
    final chapters =
        workspace.chapters
            .where((item) => item.subjectId == subjectId && !item.isArchived)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Chapters', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (chapters.isEmpty)
            const Text('No active chapters in this subject.'),
          for (final chapter in chapters)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(chapter.id),
              onChanged: enabled
                  ? (value) => onChanged(chapter.id, value ?? false)
                  : null,
              title: Text(chapter.title),
            ),
        ],
      ),
    );
  }
}

class _LessonSelector extends StatelessWidget {
  const _LessonSelector({
    required this.workspace,
    required this.subjectId,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final TeachingPlannerWorkspace workspace;
  final String? subjectId;
  final Set<String> selected;
  final bool enabled;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (subjectId == null) return const SizedBox.shrink();
    final lessons =
        workspace.lessonPlans
            .where((item) => item.subjectId == subjectId && !item.isArchived)
            .toList()
          ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lessons', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (lessons.isEmpty) const Text('No active lessons in this subject.'),
          for (final lesson in lessons)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(lesson.id),
              onChanged: enabled
                  ? (value) => onChanged(lesson.id, value ?? false)
                  : null,
              title: Text(lesson.title),
              subtitle: Text(_dateLabel(lesson.plannedDate)),
            ),
        ],
      ),
    );
  }
}

class _PackageSummary extends StatelessWidget {
  const _PackageSummary({
    required this.workspace,
    required this.selection,
    required this.teacherAssignment,
  });

  final TeachingPlannerWorkspace workspace;
  final CurriculumPackageSelection selection;
  final bool teacherAssignment;

  @override
  Widget build(BuildContext context) {
    final className = selection.classId == null
        ? null
        : workspace.classById(selection.classId!)?.name;
    final subjectName = selection.subjectId == null
        ? null
        : workspace.subjectById(selection.subjectId!)?.name;
    final target = [?className, ?subjectName].join(' → ');
    final scopeSummary = switch (selection.kind) {
      CurriculumPackageScopeKind.schoolCurriculum =>
        'All active curriculum in this planner',
      CurriculumPackageScopeKind.classSyllabus => 'Full class syllabus',
      CurriculumPackageScopeKind.subject => 'Full subject curriculum',
      CurriculumPackageScopeKind.selectedUnits =>
        '${selection.unitIds.length} selected unit(s)',
      CurriculumPackageScopeKind.selectedChapters =>
        '${selection.chapterIds.length} selected chapter(s)',
      CurriculumPackageScopeKind.selectedLessons =>
        '${selection.lessonPlanIds.length} selected lesson(s)',
    };
    return Card(
      child: ListTile(
        leading: Icon(
          teacherAssignment
              ? Icons.assignment_ind_outlined
              : Icons.inventory_2_outlined,
        ),
        title: Text(
          teacherAssignment
              ? 'Teacher assignment pack'
              : _scopeLabel(selection.kind),
        ),
        subtitle: Text(
          target.isEmpty ? scopeSummary : '$target · $scopeSummary',
        ),
      ),
    );
  }
}

String _scopeLabel(CurriculumPackageScopeKind kind) => switch (kind) {
  CurriculumPackageScopeKind.schoolCurriculum => 'Full school curriculum',
  CurriculumPackageScopeKind.classSyllabus => 'Full class syllabus',
  CurriculumPackageScopeKind.subject => 'Full subject',
  CurriculumPackageScopeKind.selectedUnits => 'Selected units',
  CurriculumPackageScopeKind.selectedChapters => 'Selected chapters',
  CurriculumPackageScopeKind.selectedLessons => 'Selected lessons',
};

String _safeFileName(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'EduSheet_Curriculum' : cleaned;
}

String? _textOrNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _stable(String value, {required String fallback}) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s:;,/\\|]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? fallback : normalized;
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
