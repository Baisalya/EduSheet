import 'package:flutter/material.dart';

import '../../domain/models/planner_priority.dart';
import '../../domain/models/teaching_status.dart';
import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_shared_components.dart';

class SyllabusEntityHero extends StatelessWidget {
  const SyllabusEntityHero({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.onEdit,
    required this.onAttach,
    this.onArchive,
    this.onMove,
    this.onDuplicate,
    this.onDelete,
    this.layerLabel,
    this.layerDetail,
    this.completion,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<SyllabusMetricData> metrics;
  final VoidCallback? onEdit;
  final VoidCallback onAttach;
  final VoidCallback? onArchive;
  final VoidCallback? onMove;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final String? layerLabel;
  final String? layerDetail;
  final double? completion;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      key: const ValueKey('syllabus-entity-hero'),
      padding: const EdgeInsets.all(TeachingPlannerDesign.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusXLarge),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              final details = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeachingPlannerIconBadge(
                    icon: icon,
                    tone: TeachingPlannerTone.primary,
                    size: 48,
                    iconSize: 24,
                  ),
                  const SizedBox(width: TeachingPlannerDesign.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.primary,
                                letterSpacing: .8,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.35,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (compact)
                    IconButton(
                      tooltip: 'Edit details',
                      onPressed: onEdit,
                      style: IconButton.styleFrom(
                        side: BorderSide(color: colors.border),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit details'),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Syllabus actions',
                    onSelected: (value) {
                      switch (value) {
                        case 'attach':
                          onAttach();
                          break;
                        case 'move':
                          onMove?.call();
                          break;
                        case 'duplicate':
                          onDuplicate?.call();
                          break;
                        case 'archive':
                          onArchive?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'attach',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.attach_file_rounded),
                          title: Text('Attach files'),
                        ),
                      ),
                      if (onMove != null)
                        const PopupMenuItem(
                          value: 'move',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.drive_file_move_outline),
                            title: Text('Move to…'),
                          ),
                        ),
                      if (onDuplicate != null)
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.copy_rounded),
                            title: Text('Duplicate structure'),
                          ),
                        ),
                      if (onArchive != null)
                        const PopupMenuItem(
                          value: 'archive',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.archive_outlined),
                            title: Text('Archive'),
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Move to Trash'),
                          ),
                        ),
                    ],
                  ),
                ],
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
          if (layerLabel != null) ...[
            const SizedBox(height: TeachingPlannerDesign.space10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLayer = constraints.maxWidth < 500;
                final badge = Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: compactLayer ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primarySoft.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        onEdit == null
                            ? Icons.lock_outline_rounded
                            : Icons.edit_note_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: compactLayer
                            ? Text(
                                layerLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: colors.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    layerLabel!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: colors.ink,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  if (layerDetail != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      layerDetail!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: colors.inkMuted),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );

                if (!compactLayer || layerDetail == null) return badge;
                return Tooltip(message: layerDetail!, child: badge);
              },
            ),
          ],
          const SizedBox(height: TeachingPlannerDesign.space14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 470;
              final children = [
                for (var index = 0; index < metrics.length; index++)
                  SyllabusMetricChip(
                    data: metrics[index],
                    tone: _metricTone(index),
                  ),
              ];
              if (compact) {
                if (children.length <= 3) {
                  return Row(
                    children: [
                      for (var index = 0; index < children.length; index++) ...[
                        if (index > 0) const SizedBox(width: 6),
                        Expanded(child: children[index]),
                      ],
                    ],
                  );
                }
                final itemWidth = (constraints.maxWidth - 12) / 2.35;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < children.length; index++) ...[
                        if (index > 0) const SizedBox(width: 6),
                        SizedBox(width: itemWidth, child: children[index]),
                      ],
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: children[index]),
                  ],
                ],
              );
            },
          ),
          if (completion != null) ...[
            const SizedBox(height: TeachingPlannerDesign.space14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      color: colors.teal,
                      backgroundColor: colors.surfaceStrong,
                      value: completion!.clamp(0.0, 1.0).toDouble(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(completion! * 100).round()}%',
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SyllabusMetricData {
  const SyllabusMetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class SyllabusMetricChip extends StatelessWidget {
  const SyllabusMetricChip({
    super.key,
    required this.data,
    this.tone = TeachingPlannerTone.primary,
  });

  final SyllabusMetricData data;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final foreground = tone.foreground(colors);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.background(colors),
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: foreground),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyllabusSectionHeader extends StatelessWidget {
  const SyllabusSectionHeader({
    super.key,
    required this.title,
    required this.helper,
  });

  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSectionHeader(title: title, subtitle: helper);
  }
}


class SyllabusCardAction {
  const SyllabusCardAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}


Future<void> _showSyllabusCardActionSheet(
  BuildContext context,
  List<SyllabusCardAction> actions,
) async {
  if (actions.isEmpty) return;
  final selected = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        for (final action in actions)
          ListTile(
            leading: Icon(action.icon),
            title: Text(action.label),
            onTap: () => Navigator.pop(sheetContext, action.id),
          ),
      ],
    ),
  );
  if (selected == null) return;
  for (final action in actions) {
    if (action.id == selected) {
      action.onSelected();
      return;
    }
  }
}

Future<void> _showSyllabusCardContextMenu(
  BuildContext context,
  List<SyllabusCardAction> actions,
  Offset globalPosition,
) async {
  if (actions.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final action in actions)
        PopupMenuItem<String>(
          value: action.id,
          child: Row(
            children: [
              Icon(action.icon, size: 20),
              const SizedBox(width: 10),
              Flexible(child: Text(action.label)),
            ],
          ),
        ),
    ],
  );
  if (selected == null) return;
  for (final action in actions) {
    if (action.id == selected) {
      action.onSelected();
      return;
    }
  }
}

class SyllabusHierarchyCard extends StatelessWidget {
  const SyllabusHierarchyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.index,
    this.priority,
    this.status,
    this.completion,
    this.dragHandle,
    this.onStatusToggle,
    this.statusToggleTooltip,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? index;
  final PlannerPriority? priority;
  final TeachingProgressStatus? status;
  final double? completion;
  final Widget? dragHandle;
  final VoidCallback? onStatusToggle;
  final String? statusToggleTooltip;
  final List<SyllabusCardAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final radius = BorderRadius.circular(TeachingPlannerDesign.radiusLarge);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: actions.isEmpty
              ? null
              : (details) => _showSyllabusCardContextMenu(
                  context,
                  actions,
                  details.globalPosition,
                ),
          child: Material(
            color: colors.surface,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: actions.isEmpty
                  ? null
                  : () => _showSyllabusCardActionSheet(context, actions),
              borderRadius: radius,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (dragHandle != null) ...[
                    SizedBox(width: 30, child: Center(child: dragHandle)),
                    const SizedBox(width: 2),
                  ],
                  if (index != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        index!.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ] else ...[
                    TeachingPlannerIconBadge(
                      icon: icon,
                      tone: TeachingPlannerTone.primary,
                      size: 36,
                      iconSize: 19,
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackMetadata =
                                constraints.maxWidth < 210 &&
                                (priority != null || status != null);
                            final titleText = Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            );

                            if (stackMetadata) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleText,
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (priority != null)
                                        _PriorityBadge(priority: priority!),
                                      if (status != null)
                                        _StatusBadge(status: status!),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: titleText),
                                if (priority != null) ...[
                                  const SizedBox(width: 7),
                                  _PriorityBadge(priority: priority!),
                                ],
                                if (status != null) ...[
                                  const SizedBox(width: 7),
                                  _StatusBadge(status: status!),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.inkMuted, height: 1.3),
                        ),
                        if (completion != null) ...[
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              color: colors.teal,
                              backgroundColor: colors.surfaceStrong,
                              value: completion!.clamp(0.0, 1.0).toDouble(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (onStatusToggle != null)
                    IconButton(
                      key: ValueKey(
                        'syllabus-status-toggle-${title.toLowerCase().replaceAll(' ', '-')}',
                      ),
                      tooltip: statusToggleTooltip ?? 'Toggle completion',
                      onPressed: onStatusToggle,
                      icon: Icon(
                        status == TeachingProgressStatus.completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: status == TeachingProgressStatus.completed
                            ? colors.teal
                            : colors.inkMuted,
                      ),
                    ),
                  if (actions.isNotEmpty)
                    PopupMenuButton<String>(
                      key: ValueKey('syllabus-card-actions-${title.toLowerCase().replaceAll(' ', '-')}'),
                      tooltip: 'More actions',
                      onSelected: (id) {
                        for (final action in actions) {
                          if (action.id == id) {
                            action.onSelected();
                            return;
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        for (final action in actions)
                          PopupMenuItem<String>(
                            value: action.id,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(action.icon, size: 20),
                              title: Text(action.label),
                            ),
                          ),
                      ],
                    )
                  else if (dragHandle == null)
                    Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class SyllabusAddCard extends StatelessWidget {
  const SyllabusAddCard({
    super.key,
    required this.label,
    required this.helper,
    required this.onTap,
  });

  final String label;
  final String helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Material(
      color: colors.primarySoft.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(TeachingPlannerDesign.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              TeachingPlannerDesign.radiusLarge,
            ),
            border: Border.all(color: colors.primary.withValues(alpha: .16)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final PlannerPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final (label, background, foreground) = switch (priority) {
      PlannerPriority.high => ('High', colors.coralSoft, colors.coral),
      PlannerPriority.normal => ('Medium', colors.orangeSoft, colors.orange),
      PlannerPriority.low => ('Low', colors.tealSoft, colors.teal),
    };
    return _Badge(label: label, background: background, foreground: foreground);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TeachingProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final (label, background, foreground) = switch (status) {
      TeachingProgressStatus.completed => (
        'Done',
        colors.tealSoft,
        colors.teal,
      ),
      TeachingProgressStatus.inProgress => (
        'Teaching',
        colors.purpleSoft,
        colors.purple,
      ),
      TeachingProgressStatus.skipped => (
        'Skipped',
        colors.surfaceStrong,
        colors.inkMuted,
      ),
      TeachingProgressStatus.rescheduled => (
        'Moved',
        colors.orangeSoft,
        colors.orange,
      ),
      TeachingProgressStatus.planned => (
        'Planned',
        colors.primarySoft,
        colors.primary,
      ),
    };
    return _Badge(label: label, background: background, foreground: foreground);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

TeachingPlannerTone _metricTone(int index) => switch (index % 4) {
  0 => TeachingPlannerTone.teal,
  1 => TeachingPlannerTone.purple,
  2 => TeachingPlannerTone.orange,
  _ => TeachingPlannerTone.primary,
};
