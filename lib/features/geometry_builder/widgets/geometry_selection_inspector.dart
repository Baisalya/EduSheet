import 'package:flutter/material.dart';

import '../application/geometry_editor_session.dart';
import '../application/geometry_selection.dart';

class GeometrySelectionInspector extends StatelessWidget {
  final GeometryEditorSession session;

  const GeometrySelectionInspector({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              left: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Inspector',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.selectionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hint(session.selection.kind),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Free-form tool',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                session.freeformHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Canvas',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show grid'),
                  value: session.diagram.showGrid,
                  onChanged: (_) => session.toggleGrid(),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Snap points to grid'),
                  value: session.diagram.snapToGrid,
                  onChanged: (_) => session.toggleSnap(),
                ),
              ),
              const Divider(height: 28),
              Text(
                'Tips',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const _Tip(
                icon: Icons.touch_app_rounded,
                text: 'Tap a side or point to get relevant tools.',
              ),
              const _Tip(
                icon: Icons.open_with_rounded,
                text: 'Drag points and labels directly on the canvas.',
              ),
              const _Tip(
                icon: Icons.keyboard_rounded,
                text:
                    'Windows: Delete, Ctrl+Z, Ctrl+Y and Esc work on the canvas.',
              ),
            ],
          ),
        );
      },
    );
  }

  String _hint(GeometrySelectionKind kind) {
    return switch (kind) {
      GeometrySelectionKind.none =>
        'Tap an object to reveal only the tools that make sense for it.',
      GeometrySelectionKind.point =>
        'Rename the point, label its angle, mark 90°, or add a triangle height.',
      GeometrySelectionKind.label => 'Edit the text, drag it, or remove it.',
      GeometrySelectionKind.shape => 'Duplicate or remove the complete figure.',
      GeometrySelectionKind.side =>
        'Add a measurement, equal-side mark or parallel mark.',
      GeometrySelectionKind.mark =>
        'This construction mark can be removed independently.',
    };
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
