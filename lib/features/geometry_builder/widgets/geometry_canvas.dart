import 'package:flutter/material.dart';

import '../controllers/geometry_controller.dart';
import '../models/geometry_label.dart';
import '../models/geometry_point.dart';
import '../painters/geometry_painter.dart';

class GeometryCanvas extends StatefulWidget {
  final GeometryController controller;
  final GlobalKey repaintKey;
  final bool interactive;
  final ValueChanged<GeometryLabel>? onEditLabel;
  final ValueChanged<GeometryPoint>? onEditPointLabel;

  const GeometryCanvas({
    super.key,
    required this.controller,
    required this.repaintKey,
    this.interactive = true,
    this.onEditLabel,
    this.onEditPointLabel,
  });

  @override
  State<GeometryCanvas> createState() => _GeometryCanvasState();
}

class _GeometryCanvasState extends State<GeometryCanvas> {
  String? _dragPointId;
  String? _dragLabelId;
  String? _dragPointLabelId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final diagram = widget.controller.diagram;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            final height = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
            final scaleX = diagram.canvasSize.width / width;
            final scaleY = diagram.canvasSize.height / height;

            Offset toDiagram(Offset local) {
              return Offset(local.dx * scaleX, local.dy * scaleY);
            }

            void selectOrDraw(TapDownDetails details) {
              final local = toDiagram(details.localPosition);
              if (widget.controller.mode == GeometryBuilderMode.draw) {
                widget.controller.addPoint(local);
                return;
              }

              final hitLabelId = _hitLabel(local);
              if (hitLabelId != null) {
                widget.controller.selectLabel(hitLabelId);
                return;
              }

              final hitPointLabelId = _hitPointLabel(local);
              if (hitPointLabelId != null) {
                widget.controller.selectPoint(hitPointLabelId);
                return;
              }

              final hitPointId = _hitPoint(local);
              if (hitPointId != null) {
                widget.controller.selectPoint(hitPointId);
                return;
              }

              if (widget.controller.mode == GeometryBuilderMode.labels) {
                final selectedLabel = widget.controller.selectedLabel;
                if (selectedLabel != null) {
                  widget.controller.beginDrag();
                  widget.controller.moveLabel(
                    selectedLabel.id,
                    local - Offset(selectedLabel.fontSize, selectedLabel.fontSize / 2),
                  );
                  return;
                }

                final selectedPoint = widget.controller.selectedPoint;
                if (selectedPoint != null) {
                  widget.controller.beginDrag();
                  widget.controller.movePointLabel(selectedPoint.id, local);
                  return;
                }
              }

              widget.controller.clearSelection();
            }

            void editAt(Offset localPosition) {
              final diagramPosition = toDiagram(localPosition);
              final labelId = _hitLabel(diagramPosition);
              if (labelId != null) {
                widget.controller.selectLabel(labelId);
                final label = widget.controller.selectedLabel;
                if (label != null) widget.onEditLabel?.call(label);
                return;
              }

              final pointId =
                  _hitPointLabel(diagramPosition) ?? _hitPoint(diagramPosition);
              if (pointId == null) return;
              widget.controller.selectPoint(pointId);
              final point = widget.controller.selectedPoint;
              if (point != null) widget.onEditPointLabel?.call(point);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.interactive ? selectOrDraw : null,
              onDoubleTapDown: widget.interactive
                  ? (details) => editAt(details.localPosition)
                  : null,
              onLongPressStart: widget.interactive
                  ? (details) => editAt(details.localPosition)
                  : null,
              onPanStart: widget.interactive
                  ? (details) {
                      final local = toDiagram(details.localPosition);
                      _dragPointId = _hitPoint(local);
                      _dragLabelId = _dragPointId == null ? _hitLabel(local) : null;
                      _dragPointLabelId =
                          _dragPointId == null && _dragLabelId == null
                          ? _hitPointLabel(local)
                          : null;

                      if (_dragPointId != null) {
                        widget.controller.selectPoint(_dragPointId);
                      } else if (_dragLabelId != null) {
                        widget.controller.selectLabel(_dragLabelId);
                      } else if (_dragPointLabelId != null) {
                        widget.controller.selectPoint(_dragPointLabelId);
                      }

                      if (_dragPointId != null ||
                          _dragLabelId != null ||
                          _dragPointLabelId != null) {
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
                      } else if (_dragPointLabelId != null) {
                        widget.controller.movePointLabel(_dragPointLabelId!, local);
                      }
                    }
                  : null,
              onPanEnd: (_) => _clearDragState(),
              onPanCancel: _clearDragState,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: GeometryPainter(
                      diagram: diagram,
                      selectedLabelId: widget.controller.selectedLabelId,
                      selectedPointId: widget.controller.selectedPointId,
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

  void _clearDragState() {
    _dragPointId = null;
    _dragLabelId = null;
    _dragPointLabelId = null;
  }

  String? _hitPoint(Offset position) {
    for (final point in widget.controller.diagram.points.reversed) {
      if ((point.position - position).distance <= 13) return point.id;
    }
    return null;
  }

  String? _hitPointLabel(Offset position) {
    for (final point in widget.controller.diagram.points.reversed) {
      final width = (point.label.length * point.labelFontSize * 0.68)
          .clamp(18.0, 120.0)
          .toDouble();
      final rect = Rect.fromLTWH(
        point.labelPosition.dx - 9,
        point.labelPosition.dy - 8,
        width + 18,
        point.labelFontSize * 1.7 + 16,
      );
      if (rect.contains(position)) return point.id;
    }
    return null;
  }

  String? _hitLabel(Offset position) {
    for (final label in widget.controller.diagram.labels.reversed) {
      final height = label.fontSize * 1.75;
      final rect = Rect.fromLTWH(
        label.position.dx - 10,
        label.position.dy - 10,
        _labelWidth(label) + 20,
        height + 20,
      );
      if (rect.contains(position)) return label.id;
    }
    return null;
  }

  double _labelWidth(GeometryLabel label) {
    return (label.text.length * label.fontSize * 0.62)
        .clamp(34, 260)
        .toDouble();
  }
}
