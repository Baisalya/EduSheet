import 'package:flutter/material.dart';

import '../application/geometry_editor_session.dart';
import '../application/geometry_freeform_tool.dart';

class GeometryFreeformToolbar extends StatelessWidget {
  final GeometryEditorSession session;

  const GeometryFreeformToolbar({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 3),
                child: Row(
                  children: [
                    for (final tool in GeometryFreeformTool.values) ...[
                      _ToolButton(
                        tool: tool,
                        selected: session.freeformTool == tool,
                        onTap: () => session.setFreeformTool(tool),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 7),
                child: Text(
                  session.freeformHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final GeometryFreeformTool tool;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (tool) {
      GeometryFreeformTool.select => Icons.near_me_outlined,
      GeometryFreeformTool.point => Icons.adjust_rounded,
      GeometryFreeformTool.line => Icons.horizontal_rule_rounded,
      GeometryFreeformTool.arrow => Icons.trending_flat_rounded,
      GeometryFreeformTool.circle => Icons.circle_outlined,
      GeometryFreeformTool.angle => Icons.architecture_rounded,
      GeometryFreeformTool.coordinateAxes => Icons.grid_3x3_rounded,
      GeometryFreeformTool.numberLine => Icons.straighten_rounded,
    };
    if (selected) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(tool.label),
        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(tool.label),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}
