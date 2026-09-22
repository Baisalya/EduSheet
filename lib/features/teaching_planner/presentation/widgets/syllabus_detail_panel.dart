import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering show ScrollCacheExtent;

import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../../domain/models/curriculum_layer_policy.dart';
import '../../domain/models/curriculum_merge_state.dart';
import '../../domain/models/planner_chapter.dart';
import '../../domain/models/planner_subject.dart';
import '../../domain/models/planner_topic.dart';
import '../../domain/models/planner_unit.dart';
import '../../domain/models/teaching_planner_workspace.dart';
import '../../domain/models/teaching_status.dart';
import '../../domain/models/teaching_resource.dart';
import '../../domain/models/teaching_resource_owner.dart';
import '../models/syllabus_filter.dart';
import '../models/syllabus_chapter_progress.dart';
import '../models/syllabus_node_ref.dart';
import '../models/syllabus_overview_model.dart';
import '../services/syllabus_manager_filter.dart';
import 'syllabus_attachment_section.dart';
import 'syllabus_hierarchy_cards.dart';

class SyllabusDetailPanel extends StatelessWidget {
  const SyllabusDetailPanel({
    super.key,
    required this.workspace,
    required this.mergeState,
    required this.selected,
    required this.query,
    required this.filter,
    required this.reorderEnabled,
    required this.onSelected,
    required this.onEdit,
    required this.onArchive,
    this.onMove,
    this.onDuplicate,
    this.onDelete,
    this.onCreatePaper,
    this.onAttachSavedPaper,
    this.onCreateSmartDocument,
    this.onAttachSmartDocument,
    required this.onAddAttachments,
    this.onLinkAttachments,
    required this.onOpenAttachment,
    required this.onRemoveAttachment,
    required this.onCreateSubject,
    required this.onCreateUnit,
    required this.onCreateChapter,
    required this.onCreateTopic,
    this.onPlanChapterLesson,
    this.onToggleChapterComplete,
    required this.onReorderSubjects,
    required this.onReorderUnits,
    required this.onReorderChapters,
    required this.onReorderTopics,
  });

  final TeachingPlannerWorkspace workspace;
  final CurriculumMergeState mergeState;
  final SyllabusNodeRef selected;
  final String query;
  final SyllabusFilter filter;
  final bool reorderEnabled;
  final ValueChanged<SyllabusNodeRef> onSelected;
  final ValueChanged<SyllabusNodeRef> onEdit;
  final ValueChanged<SyllabusNodeRef> onArchive;
  final ValueChanged<SyllabusNodeRef>? onMove;
  final ValueChanged<SyllabusNodeRef>? onDuplicate;
  final ValueChanged<SyllabusNodeRef>? onDelete;
  final ValueChanged<SyllabusNodeRef>? onCreatePaper;
  final ValueChanged<SyllabusNodeRef>? onAttachSavedPaper;
  final ValueChanged<SyllabusNodeRef>? onCreateSmartDocument;
  final ValueChanged<SyllabusNodeRef>? onAttachSmartDocument;
  final ValueChanged<SyllabusNodeRef> onAddAttachments;
  final ValueChanged<SyllabusNodeRef>? onLinkAttachments;
  final ValueChanged<TeachingResource> onOpenAttachment;
  final ValueChanged<TeachingResource> onRemoveAttachment;
  final ValueChanged<String> onCreateSubject;
  final ValueChanged<String> onCreateUnit;
  final void Function(String subjectId, String? unitId) onCreateChapter;
  final ValueChanged<String> onCreateTopic;
  final ValueChanged<SyllabusNodeRef>? onPlanChapterLesson;
  final ValueChanged<PlannerChapter>? onToggleChapterComplete;
  final void Function(String classId, List<String> orderedIds)
  onReorderSubjects;
  final void Function(String subjectId, List<String> orderedIds) onReorderUnits;
  final void Function(String subjectId, String? unitId, List<String> orderedIds)
  onReorderChapters;
  final void Function(String chapterId, List<String> orderedIds)
  onReorderTopics;

  CurriculumLayerPolicy get _layerPolicy => CurriculumLayerPolicy(mergeState);

  CurriculumLayerDescriptor _layer(String entityType, String localId) =>
      _layerPolicy.describe(entityType, localId);

  String? _officialLayerDetail(CurriculumLayerDescriptor layer) {
    if (!layer.isOfficial) return null;
    final source = layer.sourceSchool?.trim();
    final prefix = source == null || source.isEmpty
        ? 'Received master curriculum'
        : 'Received from $source';
    return '$prefix. Official structure is protected; teacher progress and resources stay editable.';
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentForSelected();
    if (content == null) {
      return const _DetailSurface(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This syllabus item is no longer available.'),
          ),
        ),
      );
    }
    return _DetailSurface(child: content);
  }

  Widget? _contentForSelected() {
    return switch (selected.kind) {
      SyllabusNodeKind.classValue => _classPage(),
      SyllabusNodeKind.subject => _subjectPage(),
      SyllabusNodeKind.unit => _unitPage(),
      SyllabusNodeKind.chapter => _chapterPage(),
      SyllabusNodeKind.topic => _topicPage(),
    };
  }

  Widget? _classPage() {
    final value = workspace.classById(selected.id);
    if (value == null || value.isArchived) {
      return null;
    }
    final subjects = visibleSyllabusSubjects(
      workspace,
      value.id,
      query,
      filter,
    );
    final metrics = SyllabusOverviewModel.forClass(workspace, value.id);
    final coverage = SyllabusChapterProgress.forClass(workspace, value.id);
    final layer = _layer('class', value.id);

    return _EntityPage(
      hero: SyllabusEntityHero(
        icon: Icons.school_rounded,
        eyebrow: 'CLASS SYLLABUS',
        title: value.name,
        subtitle: value.academicYear ?? 'Academic year not set',
        metrics: [
          SyllabusMetricData(
            'subjects',
            '${metrics.subjects}',
            Icons.menu_book_outlined,
          ),
          SyllabusMetricData(
            'chapters',
            '${metrics.chapters}',
            Icons.article_outlined,
          ),
          SyllabusMetricData(
            'done',
            '${coverage.completedChapters}/${coverage.totalChapters}',
            Icons.task_alt_rounded,
          ),
          SyllabusMetricData(
            'topics',
            '${metrics.topics}',
            Icons.checklist_rounded,
          ),
        ],
        completion: coverage.hasChapters ? coverage.completion : null,
        layerLabel: layer.isOfficial ? layer.label : null,
        layerDetail: _officialLayerDetail(layer),
        onEdit: layer.isOfficial ? null : () => onEdit(selected),
        onAttach: () => onAddAttachments(selected),
        onArchive: layer.isOfficial ? null : () => onArchive(selected),
        onDelete: layer.isOfficial || onDelete == null ? null : () => onDelete!(selected),
      ),
      attachments: _attachmentSection(),
      children: [
        SyllabusSectionHeader(
          key: const ValueKey('syllabus-subjects-section'),
          title: 'Subjects',
          helper: 'Open a subject to add units and chapters.',
        ),
        const SizedBox(height: 10),
        _ReorderableCardList<PlannerSubject>(
          items: subjects,
          enabled:
              reorderEnabled &&
              !layer.isOfficial &&
              subjects.every(
                (item) => !_layerPolicy.isOfficial('subject', item.id),
              ),
          itemId: (item) => item.id,
          cardBuilder: (context, item, index, dragHandle) {
            final itemCoverage = SyllabusChapterProgress.forSubject(
              workspace,
              item.id,
            );
            final details = <String>[
              if (item.code != null) item.code!,
              itemCoverage.compactLabel,
              '${itemCoverage.completionPercent}% complete',
            ];
            final node = SyllabusNodeRef.subject(
              classId: value.id,
              subjectId: item.id,
            );
            return SyllabusHierarchyCard(
              icon: Icons.menu_book_outlined,
              title: item.name,
              subtitle: details.join(' • '),
              status: itemCoverage.hasChapters ? itemCoverage.rollupStatus : null,
              completion: itemCoverage.hasChapters ? itemCoverage.completion : null,
              dragHandle: dragHandle,
              actions: _cardActions(node, 'subject'),
              onTap: () => onSelected(node),
            );
          },
          onReordered: (ids) => onReorderSubjects(value.id, ids),
        ),
        const SizedBox(height: 4),
        if (!layer.isOfficial)
          GuideAnchor(
            targetId: CreateSyllabusGuideTargets.openSubject,
            reportPointerActivation: true,
            child: SyllabusAddCard(
              label: 'Add subject',
              helper: 'Create the next subject inside ${value.name}.',
              onTap: () => onCreateSubject(value.id),
            ),
          ),
      ],
    );
  }

  Widget? _subjectPage() {
    final value = workspace.subjectById(selected.id);
    if (value == null || value.isArchived) {
      return null;
    }
    final units = visibleSyllabusUnits(workspace, value.id, query, filter);
    final rootChapters = visibleSyllabusChapters(
      workspace,
      value.id,
      null,
      query,
      filter,
    );
    final metrics = SyllabusOverviewModel.forSubject(workspace, value.id);
    final coverage = SyllabusChapterProgress.forSubject(workspace, value.id);
    final layer = _layer('subject', value.id);

    return _EntityPage(
      hero: SyllabusEntityHero(
        icon: Icons.menu_book_rounded,
        eyebrow: 'SUBJECT',
        title: value.name,
        subtitle: value.code ?? 'No subject code',
        metrics: [
          SyllabusMetricData(
            'units',
            '${metrics.units}',
            Icons.folder_outlined,
          ),
          SyllabusMetricData(
            'chapters',
            '${metrics.chapters}',
            Icons.article_outlined,
          ),
          SyllabusMetricData(
            'done',
            '${coverage.completedChapters}/${coverage.totalChapters}',
            Icons.task_alt_rounded,
          ),
          SyllabusMetricData(
            'periods',
            '${metrics.plannedPeriods}',
            Icons.schedule_rounded,
          ),
        ],
        completion: coverage.hasChapters ? coverage.completion : null,
        layerLabel: layer.isOfficial ? layer.label : null,
        layerDetail: _officialLayerDetail(layer),
        onEdit: layer.isOfficial ? null : () => onEdit(selected),
        onAttach: () => onAddAttachments(selected),
        onArchive: layer.isOfficial ? null : () => onArchive(selected),
        onMove: layer.isOfficial || onMove == null ? null : () => onMove!(selected),
        onDuplicate: layer.isOfficial || onDuplicate == null ? null : () => onDuplicate!(selected),
        onDelete: layer.isOfficial || onDelete == null ? null : () => onDelete!(selected),
      ),
      attachments: _attachmentSection(),
      children: [
        SyllabusSectionHeader(
          key: const ValueKey('syllabus-units-section'),
          title: 'Units',
          helper: 'Use units only when this subject groups chapters.',
        ),
        const SizedBox(height: 10),
        _ReorderableCardList<PlannerUnit>(
          items: units,
          enabled:
              reorderEnabled &&
              !layer.isOfficial &&
              units.every((item) => !_layerPolicy.isOfficial('unit', item.id)),
          itemId: (item) => item.id,
          cardBuilder: (context, item, index, dragHandle) {
            final itemCoverage = SyllabusChapterProgress.forUnit(
              workspace,
              item.id,
            );
            final node = SyllabusNodeRef.unit(
              classId: value.classId,
              subjectId: value.id,
              unitId: item.id,
            );
            return SyllabusHierarchyCard(
              icon: Icons.folder_outlined,
              title: item.title,
              subtitle:
                  '${itemCoverage.compactLabel} • ${itemCoverage.completionPercent}% complete',
              priority: item.priority,
              status: itemCoverage.hasChapters ? itemCoverage.rollupStatus : null,
              completion: itemCoverage.hasChapters ? itemCoverage.completion : null,
              dragHandle: dragHandle,
              actions: _cardActions(node, 'unit'),
              onTap: () => onSelected(node),
            );
          },
          onReordered: (ids) => onReorderUnits(value.id, ids),
        ),
        const SizedBox(height: 4),
        if (!layer.isOfficial)
          SyllabusAddCard(
            label: 'Add unit',
            helper:
                'Group chapters into a new unit when the syllabus needs it.',
            onTap: () => onCreateUnit(value.id),
          ),
        const SizedBox(height: 20),
        SyllabusSectionHeader(
          key: const ValueKey('syllabus-root-chapters-section'),
          title: 'Chapters without a unit',
          helper: 'For a simple syllabus, chapters can live directly here.',
        ),
        const SizedBox(height: 10),
        _ReorderableCardList<PlannerChapter>(
          items: rootChapters,
          enabled:
              reorderEnabled &&
              !layer.isOfficial &&
              rootChapters.every(
                (item) => !_layerPolicy.isOfficial('chapter', item.id),
              ),
          itemId: (item) => item.id,
          cardBuilder: (context, item, index, dragHandle) => _chapterCard(
            subject: value,
            chapter: item,
            index: index,
            dragHandle: dragHandle,
          ),
          onReordered: (ids) => onReorderChapters(value.id, null, ids),
        ),
        const SizedBox(height: 4),
        if (!layer.isOfficial)
          GuideAnchor(
            targetId: CreateSyllabusGuideTargets.openChapter,
            reportPointerActivation: true,
            child: SyllabusAddCard(
              label: 'Add chapter',
              helper: 'Add a chapter directly under ${value.name}.',
              onTap: () => onCreateChapter(value.id, null),
            ),
          ),
      ],
    );
  }

  Widget? _unitPage() {
    final value = workspace.unitById(selected.id);
    if (value == null || value.isArchived) {
      return null;
    }
    final subject = workspace.subjectById(value.subjectId);
    if (subject == null || subject.isArchived) {
      return null;
    }
    final chapters = visibleSyllabusChapters(
      workspace,
      subject.id,
      value.id,
      query,
      filter,
    );
    final metrics = SyllabusOverviewModel.forUnit(workspace, value.id);
    final coverage = SyllabusChapterProgress.forUnit(workspace, value.id);
    final layer = _layer('unit', value.id);

    return _EntityPage(
      hero: SyllabusEntityHero(
        icon: Icons.folder_rounded,
        eyebrow: 'UNIT',
        title: value.title,
        subtitle: '${value.plannedPeriods} planned periods',
        metrics: [
          SyllabusMetricData(
            'chapters',
            '${metrics.chapters}',
            Icons.article_outlined,
          ),
          SyllabusMetricData(
            'done',
            '${coverage.completedChapters}/${coverage.totalChapters}',
            Icons.task_alt_rounded,
          ),
        ],
        completion: coverage.hasChapters ? coverage.completion : null,
        layerLabel: layer.isOfficial ? layer.label : null,
        layerDetail: _officialLayerDetail(layer),
        onEdit: layer.isOfficial ? null : () => onEdit(selected),
        onAttach: () => onAddAttachments(selected),
        onArchive: layer.isOfficial ? null : () => onArchive(selected),
        onMove: layer.isOfficial || onMove == null ? null : () => onMove!(selected),
        onDuplicate: layer.isOfficial || onDuplicate == null ? null : () => onDuplicate!(selected),
        onDelete: layer.isOfficial || onDelete == null ? null : () => onDelete!(selected),
      ),
      attachments: _attachmentSection(),
      children: [
        SyllabusSectionHeader(
          key: const ValueKey('syllabus-chapters-section'),
          title: 'Chapters',
          helper: 'Keep chapters in the order you plan to teach them.',
        ),
        const SizedBox(height: 10),
        _ReorderableCardList<PlannerChapter>(
          items: chapters,
          enabled:
              reorderEnabled &&
              !layer.isOfficial &&
              chapters.every(
                (item) => !_layerPolicy.isOfficial('chapter', item.id),
              ),
          itemId: (item) => item.id,
          cardBuilder: (context, item, index, dragHandle) => _chapterCard(
            subject: subject,
            chapter: item,
            index: index,
            dragHandle: dragHandle,
          ),
          onReordered: (ids) => onReorderChapters(subject.id, value.id, ids),
        ),
        const SizedBox(height: 4),
        if (!layer.isOfficial)
          GuideAnchor(
            targetId: CreateSyllabusGuideTargets.openChapter,
            reportPointerActivation: true,
            child: SyllabusAddCard(
              label: 'Add chapter',
              helper: 'Add the next chapter to ${value.title}.',
              onTap: () => onCreateChapter(subject.id, value.id),
            ),
          ),
      ],
    );
  }

  Widget? _chapterPage() {
    final value = workspace.chapterById(selected.id);
    if (value == null || value.isArchived) {
      return null;
    }
    final subject = workspace.subjectById(value.subjectId);
    if (subject == null || subject.isArchived) {
      return null;
    }
    final topics = visibleSyllabusTopics(workspace, value.id, query, filter);
    final metrics = SyllabusOverviewModel.forChapter(workspace, value.id);
    final layer = _layer('chapter', value.id);

    return _EntityPage(
      hero: SyllabusEntityHero(
        icon: Icons.article_rounded,
        eyebrow: 'CHAPTER',
        title: value.title,
        subtitle: '${value.plannedPeriods} planned periods',
        metrics: [
          SyllabusMetricData(
            'topics',
            '${metrics.topics}',
            Icons.checklist_rounded,
          ),
          SyllabusMetricData(
            'status',
            _statusLabel(value.status),
            Icons.task_alt_rounded,
          ),
        ],
        completion: value.status == TeachingProgressStatus.completed
            ? 1.0
            : value.status == TeachingProgressStatus.inProgress
            ? .5
            : 0.0,
        layerLabel: layer.isOfficial ? layer.label : null,
        layerDetail: _officialLayerDetail(layer),
        onEdit: layer.isOfficial ? null : () => onEdit(selected),
        onAttach: () => onAddAttachments(selected),
        onArchive: layer.isOfficial ? null : () => onArchive(selected),
        onMove: layer.isOfficial || onMove == null ? null : () => onMove!(selected),
        onDuplicate: layer.isOfficial || onDuplicate == null ? null : () => onDuplicate!(selected),
        onDelete: layer.isOfficial || onDelete == null ? null : () => onDelete!(selected),
      ),
      attachments: _attachmentSection(),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: ValueKey('syllabus-plan-chapter-${value.id}'),
              onPressed: onPlanChapterLesson == null
                  ? null
                  : () => onPlanChapterLesson!(selected),
              icon: const Icon(Icons.event_note_rounded),
              label: const Text('Plan lesson'),
            ),
            OutlinedButton.icon(
              key: ValueKey('syllabus-toggle-chapter-${value.id}'),
              onPressed: onToggleChapterComplete == null
                  ? null
                  : () => onToggleChapterComplete!(value),
              icon: Icon(
                value.status == TeachingProgressStatus.completed
                    ? Icons.replay_rounded
                    : Icons.task_alt_rounded,
              ),
              label: Text(
                value.status == TeachingProgressStatus.completed
                    ? 'Reopen chapter'
                    : 'Mark chapter complete',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SyllabusSectionHeader(
          key: const ValueKey('syllabus-topics-section'),
          title: 'Topics',
          helper: 'Keep topics short and teachable.',
        ),
        const SizedBox(height: 10),
        _ReorderableCardList<PlannerTopic>(
          items: topics,
          enabled:
              reorderEnabled &&
              !layer.isOfficial &&
              topics.every(
                (item) => !_layerPolicy.isOfficial('topic', item.id),
              ),
          itemId: (item) => item.id,
          cardBuilder: (context, item, index, dragHandle) {
            final node = SyllabusNodeRef.topic(
              classId: subject.classId,
              subjectId: subject.id,
              unitId: value.unitId,
              chapterId: value.id,
              topicId: item.id,
            );
            return SyllabusHierarchyCard(
              icon: Icons.check_circle_outline_rounded,
              index: index + 1,
              title: item.title,
              subtitle:
                  '${item.plannedPeriods} planned period${item.plannedPeriods == 1 ? '' : 's'} • ${item.actualPeriods} actual',
              priority: item.priority,
              status: item.status,
              dragHandle: dragHandle,
              actions: _cardActions(node, 'topic'),
              onTap: () => onSelected(node),
            );
          },
          onReordered: (ids) => onReorderTopics(value.id, ids),
        ),
        const SizedBox(height: 4),
        if (!layer.isOfficial)
          GuideAnchor(
            targetId: CreateSyllabusGuideTargets.optionalTopic,
            child: SyllabusAddCard(
              label: 'Add topic',
              helper: 'Break ${value.title} into a teachable topic.',
              onTap: () => onCreateTopic(value.id),
            ),
          ),
      ],
    );
  }

  Widget? _topicPage() {
    final value = workspace.topicById(selected.id);
    if (value == null || value.isArchived) {
      return null;
    }
    final chapter = workspace.chapterById(value.chapterId);
    if (chapter == null || chapter.isArchived) {
      return null;
    }
    final layer = _layer('topic', value.id);

    return _EntityPage(
      hero: SyllabusEntityHero(
        icon: Icons.check_circle_rounded,
        eyebrow: 'TOPIC',
        title: value.title,
        subtitle: 'Inside ${chapter.title}',
        metrics: [
          SyllabusMetricData(
            'planned',
            '${value.plannedPeriods}',
            Icons.schedule_rounded,
          ),
          SyllabusMetricData(
            'actual',
            '${value.actualPeriods}',
            Icons.timer_outlined,
          ),
          SyllabusMetricData(
            'status',
            _statusLabel(value.status),
            Icons.flag_outlined,
          ),
        ],
        layerLabel: layer.isOfficial ? layer.label : null,
        layerDetail: _officialLayerDetail(layer),
        onEdit: layer.isOfficial ? null : () => onEdit(selected),
        onAttach: () => onAddAttachments(selected),
        onArchive: layer.isOfficial ? null : () => onArchive(selected),
        onMove: layer.isOfficial || onMove == null ? null : () => onMove!(selected),
        onDuplicate: layer.isOfficial || onDuplicate == null ? null : () => onDuplicate!(selected),
        onDelete: layer.isOfficial || onDelete == null ? null : () => onDelete!(selected),
      ),
      attachments: _attachmentSection(),
      children: const [_TopicNote()],
    );
  }

  List<SyllabusCardAction> _cardActions(
    SyllabusNodeRef node,
    String entityType, {
    List<SyllabusCardAction> leading = const [],
  }) {
    if (_layerPolicy.isOfficial(entityType, node.id)) return leading;
    return [
      ...leading,
      if (onMove != null)
        SyllabusCardAction(
          id: 'move',
          label: 'Move to…',
          icon: Icons.drive_file_move_outline,
          onSelected: () => onMove!(node),
        ),
      if (onDuplicate != null)
        SyllabusCardAction(
          id: 'duplicate',
          label: 'Duplicate structure',
          icon: Icons.copy_rounded,
          onSelected: () => onDuplicate!(node),
        ),
      SyllabusCardAction(
        id: 'edit',
        label: 'Edit',
        icon: Icons.edit_outlined,
        onSelected: () => onEdit(node),
      ),
      SyllabusCardAction(
        id: 'archive',
        label: 'Archive',
        icon: Icons.archive_outlined,
        onSelected: () => onArchive(node),
      ),
      if (onDelete != null)
        SyllabusCardAction(
          id: 'trash',
          label: 'Move to Trash',
          icon: Icons.delete_outline_rounded,
          onSelected: () => onDelete!(node),
        ),
    ];
  }

  Widget _chapterCard({
    required PlannerSubject subject,
    required PlannerChapter chapter,
    required int index,
    required Widget? dragHandle,
  }) {
    final metrics = SyllabusOverviewModel.forChapter(workspace, chapter.id);
    final node = SyllabusNodeRef.chapter(
      classId: subject.classId,
      subjectId: subject.id,
      unitId: chapter.unitId,
      chapterId: chapter.id,
    );
    return SyllabusHierarchyCard(
      icon: Icons.article_outlined,
      index: index + 1,
      title: chapter.title,
      subtitle:
          '${syllabusCountLabel(metrics.topics, 'topic')} • ${syllabusCountLabel(chapter.plannedPeriods, 'planned period')}',
      priority: chapter.priority,
      status: chapter.status,
      completion: chapter.status == TeachingProgressStatus.completed
          ? 1.0
          : chapter.status == TeachingProgressStatus.inProgress
          ? .5
          : 0.0,
      dragHandle: dragHandle,
      onStatusToggle: onToggleChapterComplete == null
          ? null
          : () => onToggleChapterComplete!(chapter),
      statusToggleTooltip: chapter.status == TeachingProgressStatus.completed
          ? 'Reopen chapter'
          : 'Mark chapter complete',
      actions: _cardActions(
        node,
        'chapter',
        leading: [
          if (onPlanChapterLesson != null)
            SyllabusCardAction(
              id: 'plan',
              label: 'Plan lesson',
              icon: Icons.event_note_rounded,
              onSelected: () => onPlanChapterLesson!(node),
            ),
          if (onToggleChapterComplete != null)
            SyllabusCardAction(
              id: 'complete',
              label: chapter.status == TeachingProgressStatus.completed
                  ? 'Reopen chapter'
                  : 'Mark complete',
              icon: chapter.status == TeachingProgressStatus.completed
                  ? Icons.replay_rounded
                  : Icons.task_alt_rounded,
              onSelected: () => onToggleChapterComplete!(chapter),
            ),
        ],
      ),
      onTap: () => onSelected(node),
    );
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
        .where(
          (item) =>
              item.kind == TeachingResourceKind.file ||
              item.kind == TeachingResourceKind.paper ||
              item.kind == TeachingResourceKind.smartDocument,
        )
        .toList(growable: false);
    final createPaper = onCreatePaper;
    final attachSavedPaper = onAttachSavedPaper;
    final createSmartDocument = onCreateSmartDocument;
    final attachSmartDocument = onAttachSmartDocument;
    return SyllabusAttachmentSection(
      resources: resources,
      createPaperEnabled: createPaper != null,
      attachSavedPaperEnabled: attachSavedPaper != null,
      onCreatePaper: () {
        if (createPaper != null) createPaper(selected);
      },
      onAttachSavedPaper: () {
        if (attachSavedPaper != null) attachSavedPaper(selected);
      },
      createSmartDocumentEnabled: createSmartDocument != null,
      attachSmartDocumentEnabled: attachSmartDocument != null,
      onCreateSmartDocument: () {
        if (createSmartDocument != null) createSmartDocument(selected);
      },
      onAttachSmartDocument: () {
        if (attachSmartDocument != null) attachSmartDocument(selected);
      },
      onAddFiles: () => onAddAttachments(selected),
      onLinkFiles: onLinkAttachments == null
          ? null
          : () => onLinkAttachments!(selected),
      onOpen: onOpenAttachment,
      onRemove: onRemoveAttachment,
      canRemove: (resource) => _layerPolicy.canRemoveResource(resource.id),
    );
  }

  static String _statusLabel(TeachingProgressStatus status) {
    return switch (status) {
      TeachingProgressStatus.inProgress => 'In progress',
      TeachingProgressStatus.completed => 'Completed',
      TeachingProgressStatus.skipped => 'Skipped',
      TeachingProgressStatus.rescheduled => 'Rescheduled',
      TeachingProgressStatus.planned => 'Planned',
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
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _EntityPage extends StatelessWidget {
  const _EntityPage({
    required this.hero,
    required this.attachments,
    required this.children,
  });

  final Widget hero;
  final Widget attachments;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollCacheExtent: const rendering.ScrollCacheExtent.pixels(2000),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        hero,
        const SizedBox(height: 18),
        ...children,
        const SizedBox(height: 22),
        attachments,
      ],
    );
  }
}

typedef _CardBuilder<T> =
    Widget Function(
      BuildContext context,
      T item,
      int index,
      Widget? dragHandle,
    );

class _ReorderableCardList<T> extends StatelessWidget {
  const _ReorderableCardList({
    required this.items,
    required this.enabled,
    required this.itemId,
    required this.cardBuilder,
    required this.onReordered,
  });

  final List<T> items;
  final bool enabled;
  final String Function(T) itemId;
  final _CardBuilder<T> cardBuilder;
  final ValueChanged<List<String>> onReordered;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.inbox_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text('Nothing here yet. Add the first item below.'),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
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
        final dragHandle = enabled
            ? ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator_rounded),
                ),
              )
            : null;
        return KeyedSubtree(
          key: ValueKey(itemId(item)),
          child: cardBuilder(context, item, index, dragHandle),
        );
      },
    );
  }
}

class _TopicNote extends StatelessWidget {
  const _TopicNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is the smallest syllabus level. Lesson planning and progress tracking stay in their dedicated screens.',
            ),
          ),
        ],
      ),
    );
  }
}
