import 'package:flutter/material.dart';

import '../application/geometry_editor_session.dart';
import '../application/geometry_selection.dart';
import '../models/geometry_label.dart';
import '../models/geometry_point.dart';
import '../painters/geometry_painter.dart';

class GeometryCanvas extends StatefulWidget {
  final GeometryEditorSession session;
  final GlobalKey repaintKey;
  final bool interactive;
  final ValueChanged<GeometryLabel>? onEditLabel;
  final ValueChanged<GeometryPoint>? onEditPointLabel;

  const GeometryCanvas({
    super.key,
    required this.session,
    required this.repaintKey,
    this.interactive = true,
    this.onEditLabel,
    this.onEditPointLabel,
  });

  @override
  State<GeometryCanvas> createState() => _GeometryCanvasState();
}

class _GeometryCanvasState extends State<GeometryCanvas> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final diagram = widget.session.diagram;
        final selection = widget.session.selection;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            final height = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
            final scaleX = diagram.canvasSize.width / width;
            final scaleY = diagram.canvasSize.height / height;

            Offset toDiagram(Offset local) =>
                Offset(local.dx * scaleX, local.dy * scaleY);

            void selectAt(TapDownDetails details) {
              widget.session.selectAt(toDiagram(details.localPosition));
            }

            void editAt(Offset localPosition) {
              final selected = widget.session.selectAt(toDiagram(localPosition));
              if (selected.kind == GeometrySelectionKind.label) {
                final label = selected.label(diagram);
                if (label != null) widget.onEditLabel?.call(label);
                return;
              }
              if (selected.kind == GeometrySelectionKind.point) {
                final point = selected.point(diagram);
                if (point != null) widget.onEditPointLabel?.call(point);
                return;
              }
              if (selected.kind == GeometrySelectionKind.side && selected.shapeId != null) {
                widget.session.setSelection(GeometrySelection.shape(selected.shapeId!));
              }
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.interactive ? selectAt : null,
              onDoubleTapDown: widget.interactive
                  ? (details) => editAt(details.localPosition)
                  : null,
              onLongPressStart: widget.interactive
                  ? (details) => editAt(details.localPosition)
                  : null,
              onPanStart: widget.interactive
                  ? (details) {
                      widget.session.beginDragAt(
                        toDiagram(details.localPosition),
                      );
                    }
                  : null,
              onPanUpdate: widget.interactive
                  ? (details) {
                      widget.session.dragTo(toDiagram(details.localPosition));
                    }
                  : null,
              onPanEnd: widget.interactive ? (_) => widget.session.endDrag() : null,
              onPanCancel: widget.interactive ? widget.session.endDrag : null,
              child: RepaintBoundary(
                key: widget.repaintKey,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: diagram.transparentBackground
                        ? Colors.white.withValues(alpha: 0.01)
                        : Colors.white,
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    painter: GeometryPainter(
                      diagram: diagram,
                      selectedLabelId: selection.labelId,
                      selectedPointId: selection.pointId,
                      selectedShapeId: selection.kind == GeometrySelectionKind.shape
                          ? selection.shapeId
                          : null,
                      selectedSidePointIds: selection.sidePointIds(diagram),
                      selectedMarkId: selection.markId,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
