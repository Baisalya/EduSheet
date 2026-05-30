import 'package:flutter/material.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_label.dart';
import '../painters/geometry_painter.dart';

class GeometryCanvas extends StatefulWidget {
  final GeometryController controller;
  final GlobalKey repaintKey;
  final bool interactive;

  const GeometryCanvas({
    super.key,
    required this.controller,
    required this.repaintKey,
    this.interactive = true,
  });

  @override
  State<GeometryCanvas> createState() => _GeometryCanvasState();
}

class _GeometryCanvasState extends State<GeometryCanvas> {
  String? _dragPointId;
  String? _dragLabelId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final diagram = widget.controller.diagram;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final scaleX = diagram.canvasSize.width / width;
            final scaleY = diagram.canvasSize.height / height;

            Offset toDiagram(Offset local) {
              return Offset(local.dx * scaleX, local.dy * scaleY);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown:
                  widget.interactive &&
                      widget.controller.mode == GeometryBuilderMode.draw
                  ? (details) => widget.controller.addPoint(
                      toDiagram(details.localPosition),
                    )
                  : null,
              onPanStart: widget.interactive
                  ? (details) {
                      final local = toDiagram(details.localPosition);
                      _dragPointId = _hitPoint(local);
                      _dragLabelId = _dragPointId == null
                          ? _hitLabel(local)
                          : null;
                      if (_dragPointId != null || _dragLabelId != null) {
                        widget.controller.beginDrag();
                      }
                    }
                  : null,
              onPanUpdate: widget.interactive
                  ? (details) {
                      final local = toDiagram(details.localPosition);
                      if (_dragPointId != null) {
                        widget.controller.movePoint(_dragPointId!, local);
                      } else if (_dragLabelId != null) {
                        widget.controller.moveLabel(_dragLabelId!, local);
                      }
                    }
                  : null,
              onPanEnd: (_) {
                _dragPointId = null;
                _dragLabelId = null;
              },
              child: RepaintBoundary(
                key: widget.repaintKey,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: diagram.transparentBackground
                        ? Colors.white.withValues(alpha: 0.01)
                        : Colors.white,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: GeometryPainter(diagram: diagram),
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

  String? _hitPoint(Offset position) {
    for (final point in widget.controller.diagram.points.reversed) {
      if ((point.position - position).distance <= 18) return point.id;
    }
    return null;
  }

  String? _hitLabel(Offset position) {
    for (final label in widget.controller.diagram.labels.reversed) {
      final rect = Rect.fromLTWH(
        label.position.dx - 8,
        label.position.dy - 8,
        _labelWidth(label) + 16,
        30,
      );
      if (rect.contains(position)) return label.id;
    }
    return null;
  }

  double _labelWidth(GeometryLabel label) {
    return (label.text.length * 8).clamp(40, 180).toDouble();
  }
}
