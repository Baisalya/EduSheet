import 'package:flutter/material.dart';

import '../application/geometry_editor_session.dart';
import '../application/geometry_selection.dart';
import '../models/geometry_shape.dart';

class GeometryContextBar extends StatelessWidget {
  final GeometryEditorSession session;
  final VoidCallback onAdd;
  final VoidCallback onRenamePoint;
  final VoidCallback onEditLabel;
  final VoidCallback onSideMeasurement;
  final VoidCallback onAngleMeasurement;
  final VoidCallback onCustomText;
  final VoidCallback onCoordinatePoint;
  final ValueChanged<GeometryEditOutcome> onOutcome;

  const GeometryContextBar({
    super.key,
    required this.session,
    required this.onAdd,
    required this.onRenamePoint,
    required this.onEditLabel,
    required this.onSideMeasurement,
    required this.onAngleMeasurement,
    required this.onCustomText,
    required this.onCoordinatePoint,
    required this.onOutcome,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final actions = _actions();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.add_rounded,
                    label: 'Add',
                    primary: true,
                    onTap: onAdd,
                  ),
                  const SizedBox(width: 6),
                  for (final action in actions) ...[
                    _ActionButton(
                      icon: action.icon,
                      label: action.label,
                      onTap: action.onTap,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_ContextAction> _actions() {
    switch (session.selection.kind) {
      case GeometrySelectionKind.none:
        return [
          _ContextAction(Icons.text_fields_rounded, 'Text', onCustomText),
          _ContextAction(
            Icons.grid_4x4_rounded,
            session.diagram.showGrid ? 'Hide grid' : 'Show grid',
            session.toggleGrid,
          ),
          _ContextAction(
            Icons.grid_on_rounded,
            session.diagram.snapToGrid ? 'Snap on' : 'Snap off',
            session.toggleSnap,
          ),
        ];
      case GeometrySelectionKind.point:
        return [
          _ContextAction(Icons.drive_file_rename_outline_rounded, 'Rename', onRenamePoint),
          _ContextAction(Icons.architecture_rounded, 'Angle', onAngleMeasurement),
          _ContextAction(
            Icons.square_foot_rounded,
            '90°',
            () => onOutcome(session.markSelectedVertexRightAngle()),
          ),
          _ContextAction(
            Icons.vertical_align_bottom_rounded,
            'Height',
            () => onOutcome(session.addHeightFromSelectedVertex()),
          ),
        ];
      case GeometrySelectionKind.label:
        return [
          _ContextAction(Icons.edit_rounded, 'Edit text', onEditLabel),
          _ContextAction(
            Icons.delete_outline_rounded,
            'Delete',
            () => onOutcome(session.deleteSelected()),
          ),
        ];
      case GeometrySelectionKind.side:
        return [
          _ContextAction(Icons.straighten_rounded, 'Measure', onSideMeasurement),
          _ContextAction(
            Icons.done_all_rounded,
            'Equal',
            () => onOutcome(session.markSelectedSideEqual()),
          ),
          _ContextAction(
            Icons.drag_handle_rounded,
            'Parallel',
            () => onOutcome(session.markSelectedSideParallel()),
          ),
        ];
      case GeometrySelectionKind.shape:
        final shape = session.selection.shape(session.diagram);
        return [
          if (shape?.type == GeometryShapeType.circle)
            _ContextAction(
              Icons.radio_button_checked_rounded,
              'Radius',
              () => onOutcome(session.addRadiusToSelectedCircle()),
            ),
          if (shape?.type == GeometryShapeType.coordinateAxes)
            _ContextAction(
              Icons.add_location_alt_outlined,
              'Point',
              onCoordinatePoint,
            ),
          _ContextAction(
            Icons.copy_rounded,
            'Duplicate',
            () => onOutcome(session.duplicateSelectedShape()),
          ),
          _ContextAction(
            Icons.delete_outline_rounded,
            'Delete',
            () => onOutcome(session.deleteSelected()),
          ),
        ];
      case GeometrySelectionKind.mark:
        return [
          _ContextAction(
            Icons.delete_outline_rounded,
            'Delete mark',
            () => onOutcome(session.deleteSelected()),
          ),
        ];
    }
  }
}

class _ContextAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContextAction(this.icon, this.label, this.onTap);
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      ),
    );
  }
}
