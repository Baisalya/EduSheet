import 'package:flutter/material.dart';

import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_class.dart';
import '../../domain/models/planner_priority.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../models/syllabus_filter.dart';
import '../services/syllabus_manager_filter.dart';

class SyllabusManagerToolbar extends StatelessWidget {
  const SyllabusManagerToolbar({
    super.key,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCreateClass,
  });

  final SyllabusFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SyllabusFilter> onFilterChanged;
  final VoidCallback onCreateClass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth.clamp(220.0, 520.0),
                child: TextField(
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText:
                        'Search classes, subjects, units, chapters or topics',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              for (final value in SyllabusFilter.values)
                FilterChip(
                  selected: filter == value,
                  label: Text(value.label),
                  onSelected: (_) => onFilterChanged(value),
                ),
              FilledButton.icon(
                onPressed: onCreateClass,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Class'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SyllabusClassSubjectPane extends StatelessWidget {
  const SyllabusClassSubjectPane({
    super.key,
    required this.workspace,
    required this.selectedClassId,
    required this.selectedSubjectId,
    required this.query,
    required this.filter,
    required this.onClassSelected,
    required this.onSubjectSelected,
    required this.onAddClass,
    required this.onAddSubject,
    required this.onEditClass,
    required this.onEditSubject,
    required this.onArchiveClass,
    required this.onArchiveSubject,
    required this.reorderEnabled,
    required this.onReorderSubjects,
  });

  final TeachingPlannerWorkspace workspace;
  final String? selectedClassId;
  final String? selectedSubjectId;
  final String query;
  final SyllabusFilter filter;
  final ValueChanged<String> onClassSelected;
  final ValueChanged<String> onSubjectSelected;
  final VoidCallback onAddClass;
  final VoidCallback? onAddSubject;
  final VoidCallback? onEditClass;
  final VoidCallback? onEditSubject;
  final VoidCallback? onArchiveClass;
  final VoidCallback? onArchiveSubject;
  final bool reorderEnabled;
  final Future<void> Function(List<String>)? onReorderSubjects;

  @override
  Widget build(BuildContext context) {
    final selectedClass = selectedClassId == null
        ? null
        : workspace.classById(selectedClassId!);
    final subjects = selectedClassId == null
        ? const <PlannerSubject>[]
        : visibleSyllabusSubjects(workspace, selectedClassId!, query, filter);

    return _PaneCard(
      title: 'Class & Subject',
      subtitle: selectedClass == null
          ? 'Choose a class to start the syllabus.'
          : selectedClass.name,
      actions: [
        IconButton(
          tooltip: 'Add class',
          onPressed: onAddClass,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Edit class',
          onPressed: onEditClass,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Archive class',
          onPressed: onArchiveClass,
          icon: const Icon(Icons.archive_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            title: 'My Classes',
            trailing: Text('${workspace.activeClasses.length}'),
          ),
          Expanded(
            child: _SimpleEntityList<PlannerClass>(
              items: workspace.activeClasses
                  .where(
                    (value) =>
                        syllabusClassVisible(workspace, value, query, filter),
                  )
                  .toList(),
              selectedId: selectedClassId,
              itemId: (value) => value.id,
              itemTitle: (value) => value.name,
              itemSubtitle: (value) => value.academicYear,
              icon: Icons.school_outlined,
              onSelected: onClassSelected,
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(child: _SectionLabel(title: 'Subjects')),
              IconButton(
                tooltip: 'Add subject',
                onPressed: onAddSubject,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Edit subject',
                onPressed: onEditSubject,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Archive subject',
                onPressed: onArchiveSubject,
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          Expanded(
            child: _ReorderableEntityList<PlannerSubject>(
              items: subjects,
              selectedId: selectedSubjectId,
              itemId: (value) => value.id,
              itemTitle: (value) => value.name,
              itemSubtitle: (value) => value.code,
              icon: Icons.menu_book_outlined,
              onSelected: onSubjectSelected,
              enabled: reorderEnabled,
              onReorder: onReorderSubjects,
            ),
          ),
        ],
      ),
    );
  }
}

class SyllabusUnitChapterPane extends StatelessWidget {
  const SyllabusUnitChapterPane({
    super.key,
    required this.workspace,
    required this.selectedSubject,
    required this.selectedUnitId,
    required this.rootUnitSelection,
    required this.selectedChapterId,
    required this.query,
    required this.filter,
    required this.onUnitSelected,
    required this.onChapterSelected,
    required this.onAddUnit,
    required this.onAddChapter,
    required this.onEditUnit,
    required this.onEditChapter,
    required this.onArchiveUnit,
    required this.onArchiveChapter,
    required this.reorderEnabled,
    required this.onReorderUnits,
    required this.onReorderChapters,
  });

  final TeachingPlannerWorkspace workspace;
  final PlannerSubject? selectedSubject;
  final String? selectedUnitId;
  final String rootUnitSelection;
  final String? selectedChapterId;
  final String query;
  final SyllabusFilter filter;
  final ValueChanged<String> onUnitSelected;
  final ValueChanged<String> onChapterSelected;
  final VoidCallback? onAddUnit;
  final VoidCallback? onAddChapter;
  final VoidCallback? onEditUnit;
  final VoidCallback? onEditChapter;
  final VoidCallback? onArchiveUnit;
  final VoidCallback? onArchiveChapter;
  final bool reorderEnabled;
  final Future<void> Function(List<String>)? onReorderUnits;
  final Future<void> Function(List<String>)? onReorderChapters;

  @override
  Widget build(BuildContext context) {
    if (selectedSubject == null) {
      return const _PaneCard(
        title: 'Units & Chapters',
        subtitle: 'Select a subject first.',
        child: _PaneEmpty(
          icon: Icons.menu_book_outlined,
          message: 'No subject selected',
        ),
      );
    }

    final units = visibleSyllabusUnits(
      workspace,
      selectedSubject!.id,
      query,
      filter,
    );
    final chapters = visibleSyllabusChapters(
      workspace,
      selectedSubject!.id,
      selectedUnitId,
      query,
      filter,
    );

    return _PaneCard(
      title: 'Units & Chapters',
      subtitle: selectedSubject!.name,
      actions: [
        IconButton(
          tooltip: 'Add unit',
          onPressed: onAddUnit,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
        IconButton(
          tooltip: 'Edit unit',
          onPressed: onEditUnit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Archive unit',
          onPressed: onArchiveUnit,
          icon: const Icon(Icons.archive_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel(title: 'Units')),
              TextButton.icon(
                onPressed: onAddUnit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _EntityTile(
                  selected: selectedUnitId == null,
                  title: 'Subject-level chapters',
                  subtitle: 'No unit assigned',
                  icon: Icons.layers_outlined,
                  onTap: () => onUnitSelected(rootUnitSelection),
                ),
                Expanded(
                  child: _ReorderableEntityList<PlannerUnit>(
                    items: units,
                    selectedId: selectedUnitId,
                    itemId: (value) => value.id,
                    itemTitle: (value) => value.title,
                    itemSubtitle: (value) => '${value.plannedPeriods} periods',
                    icon: Icons.folder_open_outlined,
                    onSelected: onUnitSelected,
                    enabled: reorderEnabled,
                    onReorder: onReorderUnits,
                    trailing: (value) => _PriorityDot(priority: value.priority),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(child: _SectionLabel(title: 'Chapters')),
              IconButton(
                tooltip: 'Add chapter',
                onPressed: onAddChapter,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Edit chapter',
                onPressed: onEditChapter,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Archive chapter',
                onPressed: onArchiveChapter,
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          Expanded(
            flex: 3,
            child: _ReorderableEntityList<PlannerChapter>(
              items: chapters,
              selectedId: selectedChapterId,
              itemId: (value) => value.id,
              itemTitle: (value) => value.title,
              itemSubtitle: (value) => '${value.plannedPeriods} periods',
              icon: Icons.article_outlined,
              onSelected: onChapterSelected,
              enabled: reorderEnabled,
              onReorder: onReorderChapters,
              trailing: (value) => _PriorityDot(priority: value.priority),
            ),
          ),
        ],
      ),
    );
  }
}

class SyllabusTopicPane extends StatelessWidget {
  const SyllabusTopicPane({
    super.key,
    required this.workspace,
    required this.selectedChapter,
    required this.selectedTopicId,
    required this.query,
    required this.filter,
    required this.onAddTopic,
    required this.onTopicSelected,
    required this.onEditTopic,
    required this.onArchiveTopic,
    required this.onReorderTopics,
    required this.reorderEnabled,
  });

  final TeachingPlannerWorkspace workspace;
  final PlannerChapter? selectedChapter;
  final String? selectedTopicId;
  final String query;
  final SyllabusFilter filter;
  final VoidCallback? onAddTopic;
  final ValueChanged<String> onTopicSelected;
  final VoidCallback? onEditTopic;
  final VoidCallback? onArchiveTopic;
  final Future<void> Function(List<String>)? onReorderTopics;
  final bool reorderEnabled;

  @override
  Widget build(BuildContext context) {
    if (selectedChapter == null) {
      return const _PaneCard(
        title: 'Topics',
        subtitle: 'Select a chapter first.',
        child: _PaneEmpty(
          icon: Icons.topic_outlined,
          message: 'No chapter selected',
        ),
      );
    }

    final topics = visibleSyllabusTopics(
      workspace,
      selectedChapter!.id,
      query,
      filter,
    );
    final completed = topics
        .where((value) => value.status == TeachingProgressStatus.completed)
        .length;
    final plannedPeriods = topics.fold<int>(
      0,
      (sum, value) => sum + value.plannedPeriods,
    );

    return _PaneCard(
      title: 'Topics',
      subtitle: selectedChapter!.title,
      actions: [
        IconButton(
          tooltip: 'Add topic',
          onPressed: onAddTopic,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Edit topic',
          onPressed: onEditTopic,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Archive topic',
          onPressed: onArchiveTopic,
          icon: const Icon(Icons.archive_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(label: 'Topics', value: '${topics.length}'),
              _StatPill(label: 'Completed', value: '$completed'),
              _StatPill(label: 'Planned', value: '$plannedPeriods periods'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _ReorderableEntityList<PlannerTopic>(
              items: topics,
              selectedId: selectedTopicId,
              itemId: (value) => value.id,
              itemTitle: (value) => value.title,
              itemSubtitle: (value) =>
                  '${value.plannedPeriods} periods • ${syllabusStatusLabel(value.status)}',
              icon: Icons.topic_outlined,
              onSelected: onTopicSelected,
              enabled: reorderEnabled,
              onReorder: onReorderTopics,
              trailing: (value) => _PriorityDot(priority: value.priority),
            ),
          ),
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonalIcon(
                onPressed: onAddTopic,
                icon: const Icon(Icons.add),
                label: const Text('Create first topic'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaneCard extends StatelessWidget {
  const _PaneCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SimpleEntityList<T> extends StatelessWidget {
  const _SimpleEntityList({
    required this.items,
    required this.selectedId,
    required this.itemId,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.icon,
    required this.onSelected,
  });

  final List<T> items;
  final String? selectedId;
  final String Function(T) itemId;
  final String Function(T) itemTitle;
  final String? Function(T) itemSubtitle;
  final IconData icon;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PaneEmpty(
        icon: Icons.search_off_rounded,
        message: 'Nothing matches the current view',
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final value = items[index];
        final id = itemId(value);
        return _EntityTile(
          key: ValueKey(id),
          selected: id == selectedId,
          title: itemTitle(value),
          subtitle: itemSubtitle(value),
          icon: icon,
          onTap: () => onSelected(id),
        );
      },
    );
  }
}

class _ReorderableEntityList<T> extends StatelessWidget {
  const _ReorderableEntityList({
    required this.items,
    required this.selectedId,
    required this.itemId,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.icon,
    required this.onSelected,
    required this.enabled,
    required this.onReorder,
    this.trailing,
  });

  final List<T> items;
  final String? selectedId;
  final String Function(T) itemId;
  final String Function(T) itemTitle;
  final String? Function(T) itemSubtitle;
  final IconData icon;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final Future<void> Function(List<String>)? onReorder;
  final Widget Function(T value)? trailing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PaneEmpty(
        icon: Icons.search_off_rounded,
        message: 'Nothing matches the current view',
      );
    }

    if (!enabled || onReorder == null) {
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => _tile(context, items[index], index),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: true,
      shrinkWrap: true,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) async {
        // Flutter's onReorderItem already reports the destination index after
        // removing oldIndex, so no legacy downward-move adjustment is needed.
        final reordered = items.toList();
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        await onReorder!(reordered.map(itemId).toList(growable: false));
      },
      itemBuilder: (context, index) => _tile(context, items[index], index),
    );
  }

  Widget _tile(BuildContext context, T value, int index) {
    final id = itemId(value);
    return _EntityTile(
      key: ValueKey(id),
      selected: id == selectedId,
      title: itemTitle(value),
      subtitle: itemSubtitle(value),
      icon: icon,
      trailing: trailing?.call(value),
      onTap: () => onSelected(id),
    );
  }
}

class _EntityTile extends StatelessWidget {
  const _EntityTile({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title, $subtitle',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaneEmpty extends StatelessWidget {
  const _PaneEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 120;
        final padding = compact ? 8.0 : 20.0;
        final iconSize = compact ? 28.0 : 40.0;
        final gap = compact ? 4.0 : 10.0;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize),
                SizedBox(height: gap),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 2 : null,
                  overflow: compact
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final PlannerPriority priority;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      PlannerPriority.low => 'Low priority',
      PlannerPriority.normal => 'Normal priority',
      PlannerPriority.high => 'High priority',
    };
    return Semantics(
      label: label,
      child: Icon(
        Icons.flag_rounded,
        size: 17,
        color: priority == PlannerPriority.high
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }
}
