import 'package:flutter/material.dart';

import '../design/teaching_planner_design_system.dart';
import '../layout/teaching_planner_breakpoints.dart';
import 'teaching_planner_shared_components.dart';

/// Shared page body used by secondary Teaching Planner workflows.
///
/// Keeps the same phone-first spacing as the reference screens while giving
/// resizable Windows surfaces a bounded, centered content area. It deliberately
/// avoids vertical cross-axis stretching because these pages live inside a
/// vertical scroll view where maxHeight is unbounded.
class TeachingPlannerResponsiveContent extends StatelessWidget {
  const TeachingPlannerResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = TeachingPlannerDesign.contentMaxWidth,
    this.bottomPadding = 40,
    this.topPadding = 16,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final Widget child;
  final double maxWidth;
  final double bottomPadding;
  final double topPadding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = TeachingPlannerBreakpoints.pagePadding(
            constraints.maxWidth,
          );
          return SingleChildScrollView(
            keyboardDismissBehavior: keyboardDismissBehavior,
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topPadding,
              horizontal,
              bottomPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A bounded responsive split that becomes a vertical stack on compact widths.
///
/// [side] gets a predictable desktop width; on phone/tablet both children use
/// their natural height. The row uses CrossAxisAlignment.start so it is safe in
/// a vertically scrolling parent with unbounded height.
class TeachingPlannerResponsiveSplit extends StatelessWidget {
  const TeachingPlannerResponsiveSplit({
    super.key,
    required this.primary,
    required this.side,
    this.breakpoint = TeachingPlannerBreakpoints.twoPane,
    this.sideWidth = 280,
    this.gap = TeachingPlannerDesign.space16,
    this.sideFirstOnCompact = true,
  });

  final Widget primary;
  final Widget side;
  final double breakpoint;
  final double sideWidth;
  final double gap;
  final bool sideFirstOnCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          final children = sideFirstOnCompact
              ? <Widget>[side, SizedBox(height: gap), primary]
              : <Widget>[primary, SizedBox(height: gap), side];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: sideWidth, child: side),
            SizedBox(width: gap),
            Expanded(child: primary),
          ],
        );
      },
    );
  }
}

class TeachingPlannerActionTile extends StatelessWidget {
  const TeachingPlannerActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tone = TeachingPlannerTone.primary,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      onTap: onTap,
      tone: tone,
      tint: true,
      padding: const EdgeInsets.all(TeachingPlannerDesign.space14),
      child: Row(
        children: [
          TeachingPlannerIconBadge(icon: icon, tone: tone),
          const SizedBox(width: TeachingPlannerDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: TeachingPlannerDesign.space4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TeachingPlannerDesign.space8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15,
            color: tone.foreground(colors),
          ),
        ],
      ),
    );
  }
}

class TeachingPlannerEmptyState extends StatelessWidget {
  const TeachingPlannerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = TeachingPlannerTone.primary,
  }) : assert(
         (actionLabel == null && onAction == null) ||
             (actionLabel != null && onAction != null),
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final TeachingPlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    return TeachingPlannerSurfaceCard(
      padding: const EdgeInsets.all(TeachingPlannerDesign.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TeachingPlannerIconBadge(
            icon: icon,
            tone: tone,
            size: 54,
            iconSize: 27,
          ),
          const SizedBox(height: TeachingPlannerDesign.space14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: TeachingPlannerDesign.space6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.inkMuted,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: TeachingPlannerDesign.space16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Consistent form container for planner bottom sheets.
///
/// It constrains desktop/free-form windows, accounts for the keyboard on mobile,
/// and keeps the action button reachable without introducing nested Expanded
/// widgets in an unbounded sheet.
class TeachingPlannerSheetFrame extends StatelessWidget {
  const TeachingPlannerSheetFrame({
    super.key,
    required this.title,
    required this.child,
    required this.action,
    this.subtitle,
    this.icon = Icons.edit_note_rounded,
    this.maxWidth = 760,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget action;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = TeachingPlannerTheme.colorsOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < TeachingPlannerBreakpoints.compact ? 16.0 : 22.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        TeachingPlannerDesign.space8,
        horizontal,
        TeachingPlannerDesign.space16 + viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TeachingPlannerSurfaceCard(
                    tint: true,
                    tone: TeachingPlannerTone.primary,
                    padding: const EdgeInsets.all(
                      TeachingPlannerDesign.space16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TeachingPlannerIconBadge(icon: icon),
                        const SizedBox(width: TeachingPlannerDesign.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(
                                  height: TeachingPlannerDesign.space4,
                                ),
                                Text(
                                  subtitle!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.inkMuted,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TeachingPlannerDesign.space16),
                  child,
                  const SizedBox(height: TeachingPlannerDesign.space18),
                  action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
