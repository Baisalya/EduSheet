import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import 'teaching_planner_shared_components.dart';

class TeachingPlannerHomeSection extends StatelessWidget {
  const TeachingPlannerHomeSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.15,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: TeachingPlannerDesign.space10),
        child,
      ],
    );
  }
}

class TeachingPlannerHomeSectionHeader extends StatelessWidget {
  const TeachingPlannerHomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return TeachingPlannerSectionHeader(
      title: title,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
