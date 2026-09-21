import 'package:flutter/material.dart';

import '../../domain/models/planner_chapter.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../design/teaching_planner_design_system.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_chapter_progress.dart';
import '../models/syllabus_node_ref.dart';
import '../models/syllabus_overview_model.dart';
import '../services/syllabus_manager_filter.dart';
import 'syllabus_hierarchy_cards.dart';
import 'teaching_planner_shared_components.dart';

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
    final colors = TeachingPlannerTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showInlineFilters = constraints.maxWidth >= 980;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.primary,
                    ),
                    hintText: 'Search syllabus',
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (showInlineFilters)
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
                        ? Icons.tune_rounded
                        : Icons.filter_alt_rounded,
                    color: filter == SyllabusFilter.all
                        ? colors.inkMuted
                        : colors.primary,
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
    this.actionsForNode,
  });

  final TeachingPlannerWorkspace workspace;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final VoidCallback onCreateSyllabus;
  final VoidCallback onImportSyllabus;
  final List<SyllabusCardAction> Function(SyllabusNodeRef node)? actionsForNode;

  @override
  Widget build(BuildContext context) {
    final classes = workspace.activeClasses;
    if (classes.isEmpty) {
      return _SyllabusEmptyState(
        onCreateSyllabus: onCreateSyllabus,
        onImportSyllabus: onImportSyllabus,
      );
    }

    final colors = TeachingPlannerTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return ListView(
          key: const ValueKey('syllabus-class-browser'),
          padding: EdgeInsets.fromLTRB(14, compact ? 2 : 4, 14, 30),
          children: [
            if (!compact) ...[
              TeachingPlannerSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TeachingPlannerSectionHeader(
                      title: 'Your syllabuses',
                      subtitle:
                          'Choose a class to open its subjects, chapters and topics.',
                      icon: Icons.auto_stories_rounded,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SyllabusActionTile(
                            icon: Icons.add_rounded,
                            title: 'Create syllabus',
                            subtitle: 'Start with a class and academic year',
                            tone: TeachingPlannerTone.primary,
                            onTap: onCreateSyllabus,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SyllabusActionTile(
                            icon: Icons.file_upload_outlined,
                            title: 'Import syllabus',
                            subtitle: 'Use your existing EduSheet JSON file',
                            tone: TeachingPlannerTone.teal,
                            onTap: onImportSyllabus,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Classes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TeachingPlannerPill(
                  label: '${classes.length} active',
                  icon: Icons.school_outlined,
                  tone: TeachingPlannerTone.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final value in classes)
              Builder(
                builder: (context) {
                  final metrics = SyllabusOverviewModel.forClass(
                    workspace,
                    value.id,
                  );
                  final coverage = SyllabusChapterProgress.forClass(
                    workspace,
                    value.id,
                  );
                  final node = SyllabusNodeRef.classValue(value.id);
                  return SyllabusHierarchyCard(
                    icon: Icons.school_outlined,
                    title: value.name,
                    subtitle: [
                      if (value.academicYear != null) value.academicYear!,
                      syllabusCountLabel(metrics.subjects, 'subject'),
                      coverage.compactLabel,
                      '${coverage.completionPercent}% complete',
                    ].join(' • '),
                    status: coverage.hasChapters ? coverage.rollupStatus : null,
                    completion: coverage.hasChapters ? coverage.completion : null,
                    actions: actionsForNode?.call(node) ?? const [],
                    onTap: () => onSelected(node),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SyllabusActionTile extends StatelessWidget {
  const _SyllabusActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final TeachingPlannerTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Material(
      color: colors.surfaceSoft,
      borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusLarge,
            ),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              TeachingPlannerIconBadge(icon: icon, tone: tone, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
            ],
          ),
        ),
      ),
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
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TeachingPlannerSurfaceCard(
            tint: true,
            tone: TeachingPlannerTone.primary,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TeachingPlannerIconBadge(
                  icon: Icons.auto_stories_rounded,
                  tone: TeachingPlannerTone.primary,
                  size: 54,
                  iconSize: 28,
                  circular: true,
                ),
                const SizedBox(height: 14),
                Text(
                  'Choose a syllabus from the outline',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open a class or subject to manage chapters and topics, or create a new syllabus.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.inkMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onCreateSyllabus,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create syllabus'),
                ),
              ],
            ),
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
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TeachingPlannerSurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TeachingPlannerIconBadge(
                  icon: Icons.school_outlined,
                  tone: TeachingPlannerTone.primary,
                  size: 58,
                  iconSize: 30,
                  circular: true,
                ),
                const SizedBox(height: 14),
                Text(
                  'Create your first syllabus',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Start with the class name and academic year. Then add the syllabus levels already supported by EduSheet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.inkMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
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
