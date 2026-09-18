import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';

class TeachingPlannerSurfaceCard extends StatelessWidget {
  const TeachingPlannerSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TeachingPlannerDesign.space16),
    this.tone = TeachingPlannerTone.neutral,
    this.tint = false,
    this.onTap,
    this.borderRadius,
    this.constraints,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final TeachingPlannerTone tone;
  final bool tint;
  final VoidCallback? onTap;
  final double? borderRadius;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final radius = BorderRadius.circular(
      borderRadius ?? TeachingPlannerDesign.radiusLarge,
    );
    final background = tint ? tone.background(colors) : colors.surface;
    final border = tint
        ? tone.foreground(colors).withValues(alpha: .18)
        : colors.border;

    final content = Container(
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: tint ? 14 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

class TeachingPlannerIconBadge extends StatelessWidget {
  const TeachingPlannerIconBadge({
    super.key,
    required this.icon,
    this.tone = TeachingPlannerTone.primary,
    this.size = 40,
    this.iconSize = 21,
    this.circular = false,
  });

  final IconData icon;
  final TeachingPlannerTone tone;
  final double size;
  final double iconSize;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.background(colors),
        borderRadius: circular
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(TeachingPlannerDesign.radiusMedium),
      ),
      child: Icon(icon, size: iconSize, color: tone.foreground(colors)),
    );
  }
}

class TeachingPlannerPill extends StatelessWidget {
  const TeachingPlannerPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = TeachingPlannerTone.neutral,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final TeachingPlannerTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final foreground = tone.foreground(colors);
    final child = Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tone.background(colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class TeachingPlannerSectionHeader extends StatelessWidget {
  const TeachingPlannerSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null && onAction == null) ||
             (actionLabel != null && onAction != null),
       );

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = TeachingPlannerTheme.colorsOf(context);

    Widget heading() {
      final titleWidget = Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.ink,
          fontWeight: FontWeight.w900,
          letterSpacing: -.15,
        ),
      );
      if (icon == null) return titleWidget;
      return Row(
        children: [
          TeachingPlannerIconBadge(icon: icon!, size: 32, iconSize: 18),
          const SizedBox(width: TeachingPlannerDesign.space10),
          Expanded(child: titleWidget),
        ],
      );
    }

    Widget headingAndSubtitle() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(),
        if (subtitle != null) ...[
          const SizedBox(height: TeachingPlannerDesign.space4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.inkMuted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    final label = actionLabel;
    final action = onAction;
    if (label == null || action == null) return headingAndSubtitle();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headingAndSubtitle(),
              const SizedBox(height: TeachingPlannerDesign.space4),
              TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(label),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: subtitle == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Expanded(child: headingAndSubtitle()),
            const SizedBox(width: TeachingPlannerDesign.space8),
            TextButton(
              onPressed: action,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
