import 'package:flutter/material.dart';

import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_chapter_progress.dart';
import '../models/syllabus_node_ref.dart';
import '../models/syllabus_overview_model.dart';
import '../services/syllabus_manager_filter.dart';
import 'teaching_planner_shared_components.dart';

class SyllabusOutline extends StatelessWidget {
  const SyllabusOutline({
    super.key,
    required this.workspace,
    required this.selected,
    required this.query,
    required this.filter,
    required this.onSelected,
    required this.onCreateSyllabus,
  });

  final TeachingPlannerWorkspace workspace;
  final SyllabusNodeRef? selected;
  final String query;
  final SyllabusFilter filter;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final VoidCallback onCreateSyllabus;

  bool get _forceExpanded =>
      query.trim().isNotEmpty || filter != SyllabusFilter.all;

  @override
  Widget build(BuildContext context) {
    final classes = workspace.activeClasses
        .where((value) => syllabusClassVisible(workspace, value, query, filter))
        .toList();

    final colors = TeachingPlannerTheme.colorsOf(context);
    return Material(
      color: colors.surface,
      elevation: 2,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusXLarge),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 11),
            child: Row(
              children: [
                const Expanded(
                  child: TeachingPlannerSectionHeader(
                    title: 'Syllabus outline',
                    subtitle: 'Class → Subject → Unit → Chapter → Topic',
                    icon: Icons.account_tree_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Create syllabus',
                  onPressed: onCreateSyllabus,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: classes.isEmpty
                ? _OutlineEmpty(
                    filtered: workspace.activeClasses.isNotEmpty,
                    onCreateSyllabus: onCreateSyllabus,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final classValue = classes[index];
                      return _classTile(context, classValue.id);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _classTile(BuildContext context, String classId) {
    final classValue = workspace.classById(classId)!;
    final subjects = workspace.activeSubjectsForClass(classId).where((subject) {
      if (filter != SyllabusFilter.all &&
          !syllabusMatchesSubjectFilter(workspace, subject.id, filter)) {
        return false;
      }
      return syllabusSubjectVisible(workspace, subject, query, filter);
    }).toList();
    final node = SyllabusNodeRef.classValue(classId);
    final coverage = SyllabusChapterProgress.forClass(workspace, classId);

    return ExpansionTile(
      key: ValueKey('class-$classId-${query.trim()}-${filter.name}'),
      initiallyExpanded: _forceExpanded || selected?.classId == classId,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 10),
      leading: Icon(_outlineIcon(coverage.rollupStatus)),
      title: Text(
        classValue.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (classValue.academicYear != null) classValue.academicYear!,
          syllabusCountLabel(
            workspace.activeSubjectsForClass(classId).length,
            'subject',
          ),
          if (coverage.hasChapters) coverage.compactLabel,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (expanded) {
        if (expanded) {
          onSelected(node);
        }
      },
      trailing: const Icon(Icons.expand_more_rounded),
      children: [
        _SelectableNodeTile(
          node: node,
          selected: selected == node,
          icon: Icons.dashboard_outlined,
          title: 'Class overview',
          onSelected: onSelected,
        ),
        for (final subject in subjects) _subjectTile(subject),
      ],
    );
  }

  Widget _subjectTile(PlannerSubject subject) {
    final units = visibleSyllabusUnits(workspace, subject.id, query, filter);
    final rootChapters = visibleSyllabusChapters(
      workspace,
      subject.id,
      null,
      query,
      filter,
    );
    final node = SyllabusNodeRef.subject(
      classId: subject.classId,
      subjectId: subject.id,
    );
    final coverage = SyllabusChapterProgress.forSubject(workspace, subject.id);

    return ExpansionTile(
      key: ValueKey('subject-${subject.id}-${query.trim()}-${filter.name}'),
      initiallyExpanded: _forceExpanded || selected?.subjectId == subject.id,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 12),
      leading: Icon(_outlineIcon(coverage.rollupStatus), size: 20),
      title: Text(subject.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (subject.code != null) subject.code!,
          coverage.compactLabel,
          if (coverage.hasChapters) '${coverage.completionPercent}%',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (expanded) {
        if (expanded) {
          onSelected(node);
        }
      },
      children: [
        _SelectableNodeTile(
          node: node,
          selected: selected == node,
          icon: Icons.dashboard_customize_outlined,
          title: 'Subject overview',
          onSelected: onSelected,
        ),
        for (final unit in units) _unitTile(subject, unit),
        for (final chapter in rootChapters)
          _chapterTile(subject, chapter, unitId: null),
      ],
    );
  }

  Widget _unitTile(PlannerSubject subject, PlannerUnit unit) {
    final chapters = visibleSyllabusChapters(
      workspace,
      subject.id,
      unit.id,
      query,
      filter,
    );
    final node = SyllabusNodeRef.unit(
      classId: subject.classId,
      subjectId: subject.id,
      unitId: unit.id,
    );
    final coverage = SyllabusChapterProgress.forUnit(workspace, unit.id);

    return ExpansionTile(
      key: ValueKey('unit-${unit.id}-${query.trim()}-${filter.name}'),
      initiallyExpanded: _forceExpanded || selected?.unitId == unit.id,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 12),
      leading: Icon(_outlineIcon(coverage.rollupStatus), size: 19),
      title: Text(unit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        coverage.hasChapters
            ? '${coverage.compactLabel} • ${coverage.completionPercent}%'
            : 'No chapters yet',
      ),
      onExpansionChanged: (expanded) {
        if (expanded) {
          onSelected(node);
        }
      },
      children: [
        _SelectableNodeTile(
          node: node,
          selected: selected == node,
          icon: Icons.folder_open_outlined,
          title: 'Unit overview',
          onSelected: onSelected,
        ),
        for (final chapter in chapters)
          _chapterTile(subject, chapter, unitId: unit.id),
      ],
    );
  }

  Widget _chapterTile(
    PlannerSubject subject,
    PlannerChapter chapter, {
    required String? unitId,
  }) {
    final topics = visibleSyllabusTopics(workspace, chapter.id, query, filter);
    final node = SyllabusNodeRef.chapter(
      classId: subject.classId,
      subjectId: subject.id,
      unitId: unitId,
      chapterId: chapter.id,
    );

    return ExpansionTile(
      key: ValueKey('chapter-${chapter.id}-${query.trim()}-${filter.name}'),
      initiallyExpanded: _forceExpanded || selected?.chapterId == chapter.id,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 12),
      leading: Icon(_outlineIcon(chapter.status), size: 18),
      title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_outlineStatusLabel(chapter.status)} • ${syllabusCountLabel(workspace.activeTopicsForChapter(chapter.id).length, 'topic')} • ${syllabusCountLabel(chapter.plannedPeriods, 'period')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (expanded) {
        if (expanded) {
          onSelected(node);
        }
      },
      children: [
        _SelectableNodeTile(
          node: node,
          selected: selected == node,
          icon: Icons.description_outlined,
          title: 'Chapter overview',
          onSelected: onSelected,
        ),
        for (final topic in topics)
          _SelectableNodeTile(
            node: SyllabusNodeRef.topic(
              classId: subject.classId,
              subjectId: subject.id,
              unitId: unitId,
              chapterId: chapter.id,
              topicId: topic.id,
            ),
            selected:
                selected?.kind == SyllabusNodeKind.topic &&
                selected?.id == topic.id,
            icon: Icons.circle_outlined,
            title: topic.title,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

IconData _outlineIcon(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.completed => Icons.check_circle_rounded,
  TeachingProgressStatus.inProgress => Icons.timelapse_rounded,
  TeachingProgressStatus.skipped => Icons.remove_circle_outline_rounded,
  TeachingProgressStatus.rescheduled => Icons.event_repeat_rounded,
  TeachingProgressStatus.planned => Icons.radio_button_unchecked_rounded,
};

String _outlineStatusLabel(TeachingProgressStatus status) => switch (status) {
  TeachingProgressStatus.completed => 'Done',
  TeachingProgressStatus.inProgress => 'In progress',
  TeachingProgressStatus.skipped => 'Skipped',
  TeachingProgressStatus.rescheduled => 'Moved',
  TeachingProgressStatus.planned => 'Not started',
};

class _SelectableNodeTile extends StatelessWidget {
  const _SelectableNodeTile({
    required this.node,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onSelected,
  });

  final SyllabusNodeRef node;
  final bool selected;
  final IconData icon;
  final String title;
  final ValueChanged<SyllabusNodeRef> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: colors.primarySoft,
      iconColor: selected ? colors.primary : colors.inkMuted,
      textColor: selected ? colors.primary : colors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, size: 18),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: () => onSelected(node),
    );
  }
}

class _OutlineEmpty extends StatelessWidget {
  const _OutlineEmpty({required this.filtered, required this.onCreateSyllabus});

  final bool filtered;
  final VoidCallback onCreateSyllabus;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off_rounded : Icons.school_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              filtered ? 'No matching syllabus items' : 'No syllabus yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (!filtered) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onCreateSyllabus,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create syllabus'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
