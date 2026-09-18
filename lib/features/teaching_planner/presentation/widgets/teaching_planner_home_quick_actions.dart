import 'package:flutter/material.dart';

import '../../../guided_experience/guides/create_syllabus_guide.dart';
import '../../../guided_experience/presentation/widgets/guide_anchor.dart';

import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import '../navigation/teaching_planner_navigation.dart';
import 'teaching_planner_home_components.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerQuickActions extends StatelessWidget {
  const TeachingPlannerQuickActions({
    super.key,
    required this.onCreateClass,
    required this.onOpenDestination,
  });

  final VoidCallback onCreateClass;
  final ValueChanged<TeachingPlannerDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        key: const ValueKey('planner-quick-create-class'),
        icon: Icons.add_rounded,
        tone: TeachingPlannerTone.primary,
        label: 'Add class',
        subtitle: 'Start a class',
        onTap: onCreateClass,
      ),
      _QuickActionData(
        key: const ValueKey('planner-action-syllabus'),
        icon: TeachingPlannerDestination.syllabus.icon,
        tone: TeachingPlannerTone.teal,
        label: 'Syllabus',
        subtitle: 'Classes & topics',
        onTap: () => onOpenDestination(TeachingPlannerDestination.syllabus),
      ),
      _QuickActionData(
        key: const ValueKey('planner-action-lessons'),
        icon: TeachingPlannerDestination.lessons.icon,
        tone: TeachingPlannerTone.purple,
        label: 'Plan lesson',
        subtitle: 'Create a lesson',
        onTap: () => onOpenDestination(TeachingPlannerDestination.lessons),
      ),
      _QuickActionData(
        key: const ValueKey('planner-quick-week'),
        icon: Icons.calendar_view_week_rounded,
        tone: TeachingPlannerTone.orange,
        label: 'Plan week',
        subtitle: 'Open weekly planner',
        onTap: () => onOpenDestination(TeachingPlannerDestination.calendar),
      ),
    ];

    return TeachingPlannerHomeSection(
      title: 'Quick actions',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = TeachingPlannerDesign.space12;
          final columns = TeachingPlannerBreakpoints.gridColumns(
            constraints.maxWidth,
            compactColumns: 2,
            mediumColumns: 3,
            wideColumns: 4,
          );
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: actions
                .map(
                  (action) => SizedBox(
                    width: width,
                    child: _QuickActionCard(data: action),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final TeachingPlannerTone tone;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    final card = Tooltip(
      message: data.label,
      child: TeachingPlannerSurfaceCard(
        key: data.key,
        onTap: data.onTap,
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeachingPlannerIconBadge(icon: data.icon, tone: data.tone),
            const SizedBox(height: TeachingPlannerDesign.space10),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: TeachingPlannerDesign.space2),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );

    if (data.key == const ValueKey('planner-action-syllabus')) {
      return GuideAnchor(
        targetId: CreateSyllabusGuideTargets.openSyllabus,
        reportPointerActivation: true,
        child: card,
      );
    }
    return card;
  }
}
