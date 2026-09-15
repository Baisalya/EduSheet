import 'package:flutter/material.dart';

import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_node_ref.dart';
import '../services/syllabus_manager_filter.dart';
import 'syllabus_attachment_section.dart';

class SyllabusDetailPanel extends StatelessWidget {
  const SyllabusDetailPanel({
    super.key,
    required this.workspace,
    required this.selected,
    required this.query,
    required this.filter,
    required this.reorderEnabled,
    required this.onSelected,
    required this.onEdit,
    required this.onArchive,
    required this.onAddAttachments,
    required this.onOpenAttachment,
    required this.onRemoveAttachment,
    required this.onCreateSubject,
    required this.onCreateUnit,
    required this.onCreateChapter,
    required this.onCreateTopic,
    required this.onReorderSubjects,
    required this.onReorderUnits,
    required this.onReorderChapters,
    required this.onReorderTopics,
  });

  final TeachingPlannerWorkspace workspace;
  final SyllabusNodeRef selected;
  final String query;
  final SyllabusFilter filter;
  final bool reorderEnabled;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final ValueChanged<SyllabusNodeRef> onEdit;
  final ValueChanged<SyllabusNodeRef> onArchive;
  final ValueChanged<SyllabusNodeRef> onAddAttachments;
  final ValueChanged<TeachingResource> onOpenAttachment;
  final ValueChanged<TeachingResource> onRemoveAttachment;
  final ValueChanged<String> onCreateSubject;
  final ValueChanged<String> onCreateUnit;
  final void Function(String subjectId, String? unitId) onCreateChapter;
  final ValueChanged<String> onCreateTopic;
  final void Function(String classId, List<String> orderedIds)
  onReorderSubjects;
  final void Function(String subjectId, List<String> orderedIds) onReorderUnits;
  final void Function(String subjectId, String? unitId, List<String> orderedIds)
  onReorderChapters;
  final void Function(String chapterId, List<String> orderedIds)
  onReorderTopics;

  @override
  Widget build(BuildContext context) {
    final content = _contentForSelected();
    if (content == null) {
      return const _DetailSurface(
        child: Center(
          child: Text('This syllabus item is no longer available.'),
        ),
      );
    }
    return _DetailSurface(child: content);
  }

  Widget? _contentForSelected() {
    switch (selected.kind) {
      case SyllabusNodeKind.classValue:
        final value = workspace.classById(selected.id);
        if (value == null || value.isArchived) return null;
        final subjects = visibleSyllabusSubjects(
          workspace,
          value.id,
          query,
          filter,
        );
        return _EntityPage(
          icon: Icons.school_outlined,
          eyebrow: 'SYLLABUS',
          title: value.name,
          subtitle: value.academicYear ?? 'Academic year not set',
          onEdit: () => onEdit(selected),
          onArchive: () => onArchive(selected),
          onAddAttachment: () => onAddAttachments(selected),
          attachments: _attachmentSection(),
          children: [
            _SummaryStrip(
              values: [
                _SummaryValue(
                  'Subjects',
                  workspace.activeSubjectsForClass(value.id).length,
                ),
                _SummaryValue(
                  'Chapters',
                  workspace.chapters.where((chapter) {
                    final subject = workspace.subjectById(chapter.subjectId);
                    return !chapter.isArchived &&
                        subject != null &&
                        !subject.isArchived &&
                        subject.classId == value.id;
                  }).length,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              key: const ValueKey('syllabus-subjects-section'),
              title: 'Subjects',
              helper:
                  'Start with subjects. Open one to add units and chapters.',
              addLabel: 'Add subject',
              onAdd: () => onCreateSubject(value.id),
            ),
            _ReorderableNodeList<PlannerSubject>(
              items: subjects,
              enabled: reorderEnabled,
              itemId: (item) => item.id,
              title: (item) => item.name,
              subtitle: (item) => item.code,
              icon: Icons.menu_book_outlined,
              onTap: (item) => onSelected(
                SyllabusNodeRef.subject(classId: value.id, subjectId: item.id),
              ),
              onReordered: (ids) => onReorderSubjects(value.id, ids),
            ),
          ],
        );

      case SyllabusNodeKind.subject:
        final value = workspace.subjectById(selected.id);
        if (value == null || value.isArchived) return null;
        final units = visibleSyllabusUnits(workspace, value.id, query, filter);
        final rootChapters = visibleSyllabusChapters(
          workspace,
          value.id,
          null,
          query,
          filter,
        );
        return _EntityPage(
          icon: Icons.menu_book_outlined,
          eyebrow: 'SUBJECT',
          title: value.name,
          subtitle: value.code ?? 'No subject code',
          onEdit: () => onEdit(selected),
          onArchive: () => onArchive(selected),
          onAddAttachment: () => onAddAttachments(selected),
          attachments: _attachmentSection(),
          children: [
            _SummaryStrip(
              values: [
                _SummaryValue(
                  'Units',
                  workspace.activeUnitsForSubject(value.id).length,
                ),
                _SummaryValue(
                  'Chapters',
                  workspace.chapters
                      .where(
                        (chapter) =>
                            chapter.subjectId == value.id &&
                            !chapter.isArchived,
                      )
                      .length,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              key: const ValueKey('syllabus-units-section'),
              title: 'Units',
              helper:
                  'Use units when the syllabus groups chapters into larger sections.',
              addLabel: 'Add unit',
              onAdd: () => onCreateUnit(value.id),
            ),
            _ReorderableNodeList<PlannerUnit>(
              items: units,
              enabled: reorderEnabled,
              itemId: (item) => item.id,
              title: (item) => item.title,
              subtitle: (item) => _periodLabel(item.plannedPeriods),
              icon: Icons.folder_outlined,
              onTap: (item) => onSelected(
                SyllabusNodeRef.unit(
                  classId: value.classId,
                  subjectId: value.id,
                  unitId: item.id,
                ),
              ),
              onReordered: (ids) => onReorderUnits(value.id, ids),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              key: const ValueKey('syllabus-root-chapters-section'),
              title: 'Chapters without a unit',
              helper:
                  'For simple syllabuses, chapters can live directly under a subject.',
              addLabel: 'Add chapter',
              onAdd: () => onCreateChapter(value.id, null),
            ),
            _ReorderableNodeList<PlannerChapter>(
              items: rootChapters,
              enabled: reorderEnabled,
              itemId: (item) => item.id,
              title: (item) => item.title,
              subtitle: (item) => _periodLabel(item.plannedPeriods),
              icon: Icons.article_outlined,
              onTap: (item) => onSelected(
                SyllabusNodeRef.chapter(
                  classId: value.classId,
                  subjectId: value.id,
                  chapterId: item.id,
                ),
              ),
              onReordered: (ids) => onReorderChapters(value.id, null, ids),
            ),
          ],
        );

      case SyllabusNodeKind.unit:
        final value = workspace.unitById(selected.id);
        if (value == null || value.isArchived) return null;
        final subject = workspace.subjectById(value.subjectId);
        if (subject == null || subject.isArchived) return null;
        final chapters = visibleSyllabusChapters(
          workspace,
          subject.id,
          value.id,
          query,
          filter,
        );
        return _EntityPage(
          icon: Icons.folder_outlined,
          eyebrow: 'UNIT',
          title: value.title,
          subtitle:
              '${_periodLabel(value.plannedPeriods)} • ${_priorityLabel(value.priority)} priority',
          onEdit: () => onEdit(selected),
          onArchive: () => onArchive(selected),
          onAddAttachment: () => onAddAttachments(selected),
          attachments: _attachmentSection(),
          children: [
            _SectionHeader(
              key: const ValueKey('syllabus-chapters-section'),
              title: 'Chapters',
              helper: 'Add chapters in the order you plan to teach them.',
              addLabel: 'Add chapter',
              onAdd: () => onCreateChapter(subject.id, value.id),
            ),
            _ReorderableNodeList<PlannerChapter>(
              items: chapters,
              enabled: reorderEnabled,
              itemId: (item) => item.id,
              title: (item) => item.title,
              subtitle: (item) => _periodLabel(item.plannedPeriods),
              icon: Icons.article_outlined,
              onTap: (item) => onSelected(
                SyllabusNodeRef.chapter(
                  classId: subject.classId,
                  subjectId: subject.id,
                  unitId: value.id,
                  chapterId: item.id,
                ),
              ),
              onReordered: (ids) =>
                  onReorderChapters(subject.id, value.id, ids),
            ),
          ],
        );

      case SyllabusNodeKind.chapter:
        final value = workspace.chapterById(selected.id);
        if (value == null || value.isArchived) return null;
        final subject = workspace.subjectById(value.subjectId);
        if (subject == null || subject.isArchived) return null;
        final topics = visibleSyllabusTopics(
          workspace,
          value.id,
          query,
          filter,
        );
        return _EntityPage(
          icon: Icons.article_outlined,
          eyebrow: 'CHAPTER',
          title: value.title,
          subtitle:
              '${_periodLabel(value.plannedPeriods)} • ${_priorityLabel(value.priority)} priority',
          onEdit: () => onEdit(selected),
          onArchive: () => onArchive(selected),
          onAddAttachment: () => onAddAttachments(selected),
          attachments: _attachmentSection(),
          children: [
            _SectionHeader(
              key: const ValueKey('syllabus-topics-section'),
              title: 'Topics',
              helper:
                  'Keep topics short and teachable. Progress tracking remains separate.',
              addLabel: 'Add topic',
              onAdd: () => onCreateTopic(value.id),
            ),
            _ReorderableNodeList<PlannerTopic>(
              items: topics,
              enabled: reorderEnabled,
              itemId: (item) => item.id,
              title: (item) => item.title,
              subtitle: (item) => _periodLabel(item.plannedPeriods),
              icon: Icons.circle_outlined,
              onTap: (item) => onSelected(
                SyllabusNodeRef.topic(
                  classId: subject.classId,
                  subjectId: subject.id,
                  unitId: value.unitId,
                  chapterId: value.id,
                  topicId: item.id,
                ),
              ),
              onReordered: (ids) => onReorderTopics(value.id, ids),
            ),
          ],
        );

      case SyllabusNodeKind.topic:
        final value = workspace.topicById(selected.id);
        if (value == null || value.isArchived) return null;
        return _EntityPage(
          icon: Icons.circle_outlined,
          eyebrow: 'TOPIC',
          title: value.title,
          subtitle:
              '${_periodLabel(value.plannedPeriods)} • ${_priorityLabel(value.priority)} priority',
          onEdit: () => onEdit(selected),
          onArchive: () => onArchive(selected),
          onAddAttachment: () => onAddAttachments(selected),
          attachments: _attachmentSection(),
          children: const [_TopicNote()],
        );
    }
  }

  Widget _attachmentSection() {
    final owner = switch (selected.kind) {
      SyllabusNodeKind.classValue => TeachingResourceOwner.plannerClass(
        selected.id,
      ),
      SyllabusNodeKind.subject => TeachingResourceOwner.subject(selected.id),
      SyllabusNodeKind.unit => TeachingResourceOwner.unit(selected.id),
      SyllabusNodeKind.chapter => TeachingResourceOwner.chapter(selected.id),
      SyllabusNodeKind.topic => TeachingResourceOwner.topic(selected.id),
    };
    final resources = workspace
        .activeResourcesForOwner(owner)
        .where((item) => item.kind == TeachingResourceKind.file)
        .toList(growable: false);
    return SyllabusAttachmentSection(
      resources: resources,
      onAddFiles: () => onAddAttachments(selected),
      onOpen: onOpenAttachment,
      onRemove: onRemoveAttachment,
    );
  }

  static String _periodLabel(int periods) {
    return periods == 0
        ? 'Periods not set'
        : '$periods planned period${periods == 1 ? '' : 's'}';
  }

  static String _priorityLabel(PlannerPriority priority) {
    return switch (priority) {
      PlannerPriority.low => 'Low',
      PlannerPriority.normal => 'Normal',
      PlannerPriority.high => 'High',
    };
  }
}

class _DetailSurface extends StatelessWidget {
  const _DetailSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _EntityPage extends StatelessWidget {
  const _EntityPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onArchive,
    required this.onAddAttachment,
    required this.attachments,
    required this.children,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onAddAttachment;
  final Widget attachments;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 24, child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Attach files',
              onPressed: onAddAttachment,
              icon: const Icon(Icons.attach_file_rounded),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (value) {
                if (value == 'archive') onArchive();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.archive_outlined),
                    title: Text('Archive'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...children,
        const SizedBox(height: 22),
        attachments,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    required this.helper,
    required this.addLabel,
    required this.onAdd,
  });

  final String title;
  final String helper;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(helper),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }
}

class _ReorderableNodeList<T> extends StatelessWidget {
  const _ReorderableNodeList({
    required this.items,
    required this.enabled,
    required this.itemId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.onReordered,
  });

  final List<T> items;
  final bool enabled;
  final String Function(T) itemId;
  final String Function(T) title;
  final String? Function(T) subtitle;
  final IconData icon;
  final ValueChanged<T> onTap;
  final ValueChanged<List<String>> onReordered;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Nothing here yet.'),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: enabled,
      itemCount: items.length,
      onReorderItem: enabled
          ? (oldIndex, newIndex) {
              final ids = items.map(itemId).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              onReordered(ids);
            }
          : (_, _) {},
      itemBuilder: (context, index) {
        final item = items[index];
        final itemSubtitle = subtitle(item);
        return Card(
          key: ValueKey(itemId(item)),
          margin: const EdgeInsets.only(bottom: 7),
          child: ListTile(
            leading: Icon(icon),
            title: Text(title(item)),
            subtitle: itemSubtitle == null ? null : Text(itemSubtitle),
            trailing: enabled
                ? const Icon(Icons.drag_handle_rounded)
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => onTap(item),
          ),
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.values});

  final List<_SummaryValue> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in values)
          Container(
            constraints: const BoxConstraints(minWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value.value}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(value.label),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryValue {
  final String label;
  final int value;

  const _SummaryValue(this.label, this.value);
}

class _TopicNote extends StatelessWidget {
  const _TopicNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is the smallest syllabus level. Lesson planning and progress tracking stay in their existing dedicated screens.',
            ),
          ),
        ],
      ),
    );
  }
}
