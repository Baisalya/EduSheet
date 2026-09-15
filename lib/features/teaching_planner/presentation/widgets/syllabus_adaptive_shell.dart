import 'package:flutter/material.dart';

import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_node_ref.dart';
import '../services/syllabus_manager_filter.dart';

class SyllabusAdaptiveToolbar extends StatelessWidget {
  const SyllabusAdaptiveToolbar({
    super.key,
    required this.filter,
    required this.searchController,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCreateSyllabus,
  });

  final SyllabusFilter filter;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SyllabusFilter> onFilterChanged;
  final VoidCallback onCreateSyllabus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search syllabus',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (wide)
                ...SyllabusFilter.values.map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      selected: filter == value,
                      label: Text(value.label),
                      onSelected: (_) => onFilterChanged(value),
                    ),
                  ),
                )
              else
                PopupMenuButton<SyllabusFilter>(
                  tooltip: 'Filter syllabus',
                  initialValue: filter,
                  onSelected: onFilterChanged,
                  icon: Icon(
                    filter == SyllabusFilter.all
                        ? Icons.filter_list_rounded
                        : Icons.filter_alt_rounded,
                  ),
                  itemBuilder: (context) => [
                    for (final value in SyllabusFilter.values)
                      CheckedPopupMenuItem(
                        value: value,
                        checked: filter == value,
                        child: Text(value.label),
                      ),
                  ],
                ),
              const SizedBox(width: 6),
              if (wide)
                FilledButton.icon(
                  onPressed: onCreateSyllabus,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create syllabus'),
                )
              else
                IconButton.filledTonal(
                  tooltip: 'Create syllabus',
                  onPressed: onCreateSyllabus,
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SyllabusClassBrowser extends StatelessWidget {
  const SyllabusClassBrowser({
    super.key,
    required this.workspace,
    required this.onSelected,
    required this.onCreateSyllabus,
    required this.onImportSyllabus,
  });

  final TeachingPlannerWorkspace workspace;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final VoidCallback onCreateSyllabus;
  final VoidCallback onImportSyllabus;

  @override
  Widget build(BuildContext context) {
    final classes = workspace.activeClasses;
    if (classes.isEmpty) {
      return _SyllabusEmptyState(
        onCreateSyllabus: onCreateSyllabus,
        onImportSyllabus: onImportSyllabus,
      );
    }

    return ListView(
      key: const ValueKey('syllabus-class-browser'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My syllabuses',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onCreateSyllabus,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create syllabus'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose a class syllabus. You can add subjects and chapters inside it.',
        ),
        const SizedBox(height: 14),
        for (final value in classes)
          Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
              title: Text(
                value.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  ?value.academicYear,
                  '${workspace.activeSubjectsForClass(value.id).length} subject(s)',
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelected(SyllabusNodeRef.classValue(value.id)),
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onImportSyllabus,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Import syllabus JSON'),
        ),
      ],
    );
  }
}

class SyllabusBreadcrumb extends StatelessWidget {
  const SyllabusBreadcrumb({
    super.key,
    required this.workspace,
    required this.selected,
    required this.onSelected,
    required this.onHome,
  });

  final TeachingPlannerWorkspace workspace;
  final SyllabusNodeRef selected;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final path = _path();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: path.length + 1,
        separatorBuilder: (_, _) =>
            const Icon(Icons.chevron_right_rounded, size: 18),
        itemBuilder: (context, index) {
          if (index == 0) {
            return TextButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Syllabuses'),
            );
          }
          final item = path[index - 1];
          return TextButton(
            onPressed: item.$1 == selected ? null : () => onSelected(item.$1),
            child: Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        },
      ),
    );
  }

  List<(SyllabusNodeRef, String)> _path() {
    final result = <(SyllabusNodeRef, String)>[];
    final classValue = workspace.classById(selected.classId);
    if (classValue == null) {
      return result;
    }
    result.add((SyllabusNodeRef.classValue(classValue.id), classValue.name));

    final subjectId = selected.subjectId;
    if (subjectId == null) {
      return result;
    }
    final subject = workspace.subjectById(subjectId);
    if (subject == null) {
      return result;
    }
    result.add((
      SyllabusNodeRef.subject(classId: classValue.id, subjectId: subject.id),
      subject.name,
    ));

    final unitId = selected.unitId;
    if (unitId != null) {
      final unit = workspace.unitById(unitId);
      if (unit != null) {
        result.add((
          SyllabusNodeRef.unit(
            classId: classValue.id,
            subjectId: subject.id,
            unitId: unit.id,
          ),
          unit.title,
        ));
      }
    }

    final chapterId = selected.chapterId;
    if (chapterId == null) {
      return result;
    }
    final chapter = workspace.chapterById(chapterId);
    if (chapter == null) {
      return result;
    }
    result.add((
      SyllabusNodeRef.chapter(
        classId: classValue.id,
        subjectId: subject.id,
        unitId: chapter.unitId,
        chapterId: chapter.id,
      ),
      chapter.title,
    ));

    if (selected.kind == SyllabusNodeKind.topic) {
      final topic = workspace.topicById(selected.id);
      if (topic != null) {
        result.add((selected, topic.title));
      }
    }
    return result;
  }
}

class SyllabusSearchResults extends StatelessWidget {
  const SyllabusSearchResults({
    super.key,
    required this.workspace,
    required this.query,
    required this.filter,
    required this.onSelected,
  });

  final TeachingPlannerWorkspace workspace;
  final String query;
  final SyllabusFilter filter;
  final ValueChanged<SyllabusNodeRef> onSelected;

  @override
  Widget build(BuildContext context) {
    final results = _results();
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No syllabus items match this search or filter.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 7),
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.path),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onSelected(item.node),
          ),
        );
      },
    );
  }

  List<_SearchItem> _results() {
    final result = <_SearchItem>[];
    for (final classValue in workspace.activeClasses) {
      if (!syllabusClassVisible(workspace, classValue, query, filter)) {
        continue;
      }
      if (_directMatch(classValue.name, classValue.academicYear)) {
        result.add(
          _SearchItem(
            node: SyllabusNodeRef.classValue(classValue.id),
            icon: Icons.school_outlined,
            title: classValue.name,
            path: 'Syllabus',
          ),
        );
      }
      for (final subject in workspace.activeSubjectsForClass(classValue.id)) {
        if (filter != SyllabusFilter.all &&
            !syllabusMatchesSubjectFilter(workspace, subject.id, filter)) {
          continue;
        }
        if (!syllabusSubjectVisible(workspace, subject, query, filter)) {
          continue;
        }
        if (_directMatch(subject.name, subject.code)) {
          result.add(
            _SearchItem(
              node: SyllabusNodeRef.subject(
                classId: classValue.id,
                subjectId: subject.id,
              ),
              icon: Icons.menu_book_outlined,
              title: subject.name,
              path: classValue.name,
            ),
          );
        }

        for (final unit in visibleSyllabusUnits(
          workspace,
          subject.id,
          query,
          filter,
        )) {
          if (_directMatch(unit.title, null)) {
            result.add(
              _SearchItem(
                node: SyllabusNodeRef.unit(
                  classId: classValue.id,
                  subjectId: subject.id,
                  unitId: unit.id,
                ),
                icon: Icons.folder_outlined,
                title: unit.title,
                path: '${classValue.name} › ${subject.name}',
              ),
            );
          }
          for (final chapter in visibleSyllabusChapters(
            workspace,
            subject.id,
            unit.id,
            query,
            filter,
          )) {
            _addChapterAndTopics(
              result,
              classValue.id,
              classValue.name,
              subject.id,
              subject.name,
              unit.id,
              unit.title,
              chapter,
            );
          }
        }

        for (final chapter in visibleSyllabusChapters(
          workspace,
          subject.id,
          null,
          query,
          filter,
        )) {
          _addChapterAndTopics(
            result,
            classValue.id,
            classValue.name,
            subject.id,
            subject.name,
            null,
            null,
            chapter,
          );
        }
      }
    }
    return result;
  }

  void _addChapterAndTopics(
    List<_SearchItem> result,
    String classId,
    String className,
    String subjectId,
    String subjectName,
    String? unitId,
    String? unitName,
    PlannerChapter chapter,
  ) {
    if (_directMatch(chapter.title, null)) {
      result.add(
        _SearchItem(
          node: SyllabusNodeRef.chapter(
            classId: classId,
            subjectId: subjectId,
            unitId: unitId,
            chapterId: chapter.id,
          ),
          icon: Icons.article_outlined,
          title: chapter.title,
          path: [className, subjectName, ?unitName].join(' › '),
        ),
      );
    }
    for (final topic in visibleSyllabusTopics(
      workspace,
      chapter.id,
      query,
      filter,
    )) {
      if (!_directMatch(topic.title, null)) {
        continue;
      }
      result.add(
        _SearchItem(
          node: SyllabusNodeRef.topic(
            classId: classId,
            subjectId: subjectId,
            unitId: unitId,
            chapterId: chapter.id,
            topicId: topic.id,
          ),
          icon: Icons.circle_outlined,
          title: topic.title,
          path: [className, subjectName, ?unitName, chapter.title].join(' › '),
        ),
      );
    }
  }

  bool _directMatch(String primary, String? secondary) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    return syllabusMatches(trimmed, primary) ||
        (secondary != null && syllabusMatches(trimmed, secondary));
  }
}

class SyllabusSelectionPlaceholder extends StatelessWidget {
  const SyllabusSelectionPlaceholder({
    super.key,
    required this.onCreateSyllabus,
  });

  final VoidCallback onCreateSyllabus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_tree_outlined, size: 46),
              const SizedBox(height: 12),
              const Text(
                'Select a syllabus item from the outline',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 6),
              const Text(
                'Or create a new syllabus and build it one level at a time.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreateSyllabus,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create syllabus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyllabusEmptyState extends StatelessWidget {
  const _SyllabusEmptyState({
    required this.onCreateSyllabus,
    required this.onImportSyllabus,
  });

  final VoidCallback onCreateSyllabus;
  final VoidCallback onImportSyllabus;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Create your first syllabus',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start with only the class name and academic year. Then add subjects, units, chapters and topics from one simple editor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateSyllabus,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create syllabus'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onImportSyllabus,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import existing syllabus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchItem {
  final SyllabusNodeRef node;
  final IconData icon;
  final String title;
  final String path;

  const _SearchItem({
    required this.node,
    required this.icon,
    required this.title,
    required this.path,
  });
}
