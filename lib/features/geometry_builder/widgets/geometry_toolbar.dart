import 'package:flutter/material.dart';

import '../controllers/geometry_controller.dart';

class GeometryToolbar extends StatelessWidget {
  final GeometryController controller;
  final VoidCallback onAddSideLabel;
  final VoidCallback onAddAngleLabel;
  final VoidCallback onAddTextLabel;
  final VoidCallback onAddRightAngle;
  final VoidCallback onAddHeightLine;

  const GeometryToolbar({
    super.key,
    required this.controller,
    required this.onAddSideLabel,
    required this.onAddAngleLabel,
    required this.onAddTextLabel,
    required this.onAddRightAngle,
    required this.onAddHeightLine,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ToolButton(
                icon: Icons.undo,
                label: 'Undo',
                onTap: controller.canUndo ? controller.undo : null,
              ),
              _ToolButton(
                icon: Icons.redo,
                label: 'Redo',
                onTap: controller.canRedo ? controller.redo : null,
              ),
              _ToolButton(
                icon: Icons.copy,
                label: 'Copy',
                onTap: controller.duplicate,
              ),
              _ToolButton(
                icon: Icons.delete_outline,
                label: 'Clear',
                onTap: controller.clear,
              ),
              _ToolButton(
                icon: Icons.grid_on,
                label: 'Grid',
                selected: controller.diagram.showGrid,
                onTap: controller.toggleGrid,
              ),
              _ToolButton(
                icon: Icons.grid_3x3,
                label: 'Snap',
                selected: controller.diagram.snapToGrid,
                onTap: controller.toggleSnap,
              ),
              _ToolButton(
                icon: Icons.straighten,
                label: 'Side',
                onTap: onAddSideLabel,
              ),
              _ToolButton(
                icon: Icons.architecture,
                label: 'Angle',
                onTap: onAddAngleLabel,
              ),
              _ToolButton(
                icon: Icons.text_fields,
                label: 'Text',
                onTap: onAddTextLabel,
              ),
              _ToolButton(
                icon: Icons.crop_square,
                label: 'Right',
                onTap: onAddRightAngle,
              ),
              _ToolButton(
                icon: Icons.more_vert,
                label: 'Height',
                onTap: onAddHeightLine,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 58,
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: onTap == null
                      ? theme.disabledColor
                      : selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
