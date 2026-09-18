import 'dart:math' as math;

import 'package:edusheet/features/geometry_builder/painters/geometry_painter.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter/material.dart';

/// Read-only Word-like rendering for Phase 4B drawing objects.
///
/// This widget intentionally stays presentation-only. Canonical ownership and
/// persistence live in `WordShapeService` / `Question.metadata`.
class WordShapeFlowPreview extends StatelessWidget {
  final List<WordShapeObject> shapes;
  final Widget child;
  final double canvasHeight;

  const WordShapeFlowPreview({
    super.key,
    required this.shapes,
    required this.child,
    this.canvasHeight = 118,
  });

  @override
  Widget build(BuildContext context) {
    if (shapes.isEmpty) return child;

    final ordered = [...shapes]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    WordShapeObject? square;
    for (final shape in ordered) {
      if (shape.wrapMode == WordTextWrapMode.squareLeft ||
          shape.wrapMode == WordTextWrapMode.squareRight) {
        square = shape;
        break;
      }
    }
    final behind = ordered
        .where((shape) => shape.wrapMode == WordTextWrapMode.behindText)
        .toList(growable: false);
    final front = ordered
        .where((shape) => shape.wrapMode == WordTextWrapMode.inFrontOfText)
        .toList(growable: false);
    final flow = ordered
        .where((shape) {
          return shape.wrapMode == WordTextWrapMode.inline ||
              shape.wrapMode == WordTextWrapMode.topAndBottom;
        })
        .toList(growable: false);

    Widget text = child;
    final squareShape = square;
    if (squareShape != null) {
      text = LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final shapeWidth = (available * squareShape.width)
              .clamp(72.0, math.max(72.0, available * 0.48))
              .toDouble();
          final shapeHeight = (canvasHeight * squareShape.height / 0.30)
              .clamp(48.0, canvasHeight)
              .toDouble();
          final shapeWidget = SizedBox(
            width: shapeWidth,
            height: shapeHeight,
            child: WordShapeVisual(shape: squareShape),
          );
          final children = <Widget>[
            if (squareShape.wrapMode == WordTextWrapMode.squareLeft) ...[
              shapeWidget,
              const SizedBox(width: 10),
            ],
            Expanded(child: child),
            if (squareShape.wrapMode == WordTextWrapMode.squareRight) ...[
              const SizedBox(width: 10),
              shapeWidget,
            ],
          ];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      );
    }

    if (behind.isNotEmpty || front.isNotEmpty) {
      final contentBelowOverlay = text;
      text = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final shape in behind)
                _PositionedShape(
                  shape: shape,
                  canvasWidth: width,
                  canvasHeight: canvasHeight,
                  opacity: 0.24,
                ),
              contentBelowOverlay,
              for (final shape in front)
                _PositionedShape(
                  shape: shape,
                  canvasWidth: width,
                  canvasHeight: canvasHeight,
                ),
            ],
          );
        },
      );
    }

    if (flow.isEmpty) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text,
        const SizedBox(height: 6),
        _FlowShapeCanvas(shapes: flow, height: canvasHeight),
      ],
    );
  }
}

class _FlowShapeCanvas extends StatelessWidget {
  final List<WordShapeObject> shapes;
  final double height;

  const _FlowShapeCanvas({required this.shapes, required this.height});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final shape in shapes)
                _PositionedShape(
                  shape: shape,
                  canvasWidth: width,
                  canvasHeight: height,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PositionedShape extends StatelessWidget {
  final WordShapeObject shape;
  final double canvasWidth;
  final double canvasHeight;
  final double opacity;

  const _PositionedShape({
    required this.shape,
    required this.canvasWidth,
    required this.canvasHeight,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final width = (shape.width * canvasWidth)
        .clamp(34.0, canvasWidth)
        .toDouble();
    final height = (shape.height * canvasHeight)
        .clamp(20.0, canvasHeight)
        .toDouble();
    final maxLeft = math.max(0.0, canvasWidth - width);
    final maxTop = math.max(0.0, canvasHeight - height);
    return Positioned(
      left: (shape.x * canvasWidth).clamp(0.0, maxLeft).toDouble(),
      top: (shape.y * canvasHeight).clamp(0.0, maxTop).toDouble(),
      width: width,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: WordShapeVisual(shape: shape),
        ),
      ),
    );
  }
}

class WordShapeVisual extends StatelessWidget {
  final WordShapeObject shape;
  final Color? color;
  final bool selected;

  const WordShapeVisual({
    super.key,
    required this.shape,
    this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final diagram = shape.geometryDiagram;
    if (shape.kind == WordShapeKind.geometry && diagram != null) {
      return Transform.rotate(
        angle: shape.rotationDegrees * math.pi / 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  )
                : shape.borderVisible
                ? Border.all(
                    color: Color(shape.strokeColorArgb),
                    width: shape.strokeWidth,
                  )
                : null,
            color: shape.fillOpacity > 0
                ? Color(shape.fillColorArgb).withValues(alpha: shape.fillOpacity)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(shape.padding),
            child: CustomPaint(
              painter: GeometryPainter(
                diagram: diagram.copyWith(showGrid: false),
                showPointHandles: false,
              ),
            ),
          ),
        ),
      );
    }
    final fallbackStroke = color ?? Theme.of(context).colorScheme.onSurface;
    final stroke = color ?? Color(shape.strokeColorArgb);
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Transform.rotate(
      angle: shape.rotationDegrees * math.pi / 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: CustomPaint(
          painter: WordShapePainter(
            kind: shape.kind,
            strokeColor: shape.borderVisible ? stroke : fallbackStroke,
            strokeWidth: shape.borderVisible ? shape.strokeWidth : 0,
            fillColor: Color(shape.fillColorArgb).withValues(
              alpha: shape.fillOpacity,
            ),
            fillOpacity: shape.fillOpacity,
          ),
          child: shape.isTextContainer && shape.text.trim().isNotEmpty
              ? Padding(
                  padding: EdgeInsets.all(shape.padding),
                  child: Center(
                    child: Text(
                      shape.text,
                      textAlign: TextAlign.center,
                      overflow: shape.textBoxSizing == WordTextBoxSizing.fixed
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
                      maxLines: shape.textBoxSizing == WordTextBoxSizing.fixed
                          ? 8
                          : null,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class WordShapePainter extends CustomPainter {
  final WordShapeKind kind;
  final Color strokeColor;
  final double strokeWidth;
  final Color fillColor;
  final double fillOpacity;

  const WordShapePainter({
    required this.kind,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillColor,
    required this.fillOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final rect = Rect.fromLTWH(
      2,
      2,
      math.max(0.0, size.width - 4),
      math.max(0.0, size.height - 4),
    );
    final canFill = fillOpacity > 0 &&
        kind != WordShapeKind.line &&
        kind != WordShapeKind.arrow &&
        kind != WordShapeKind.doubleArrow;
    final canStroke = strokeWidth > 0;

    void drawRect() {
      if (canFill) canvas.drawRect(rect, fill);
      if (canStroke) canvas.drawRect(rect, stroke);
    }

    void drawRoundRect(RRect value) {
      if (canFill) canvas.drawRRect(value, fill);
      if (canStroke) canvas.drawRRect(value, stroke);
    }

    switch (kind) {
      case WordShapeKind.rectangle:
      case WordShapeKind.textBox:
        drawRect();
        break;
      case WordShapeKind.roundedRectangle:
        drawRoundRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        );
        break;
      case WordShapeKind.ellipse:
        if (canFill) canvas.drawOval(rect, fill);
        if (canStroke) canvas.drawOval(rect, stroke);
        break;
      case WordShapeKind.line:
        if (canStroke) {
          canvas.drawLine(
            Offset(4, size.height / 2),
            Offset(math.max(4.0, size.width - 4), size.height / 2),
            stroke,
          );
        }
        break;
      case WordShapeKind.arrow:
        if (canStroke) {
          _drawArrow(
            canvas,
            Offset(4, size.height / 2),
            Offset(math.max(4.0, size.width - 4), size.height / 2),
            stroke,
            startHead: false,
            endHead: true,
          );
        }
        break;
      case WordShapeKind.doubleArrow:
        if (canStroke) {
          _drawArrow(
            canvas,
            Offset(4, size.height / 2),
            Offset(math.max(4.0, size.width - 4), size.height / 2),
            stroke,
            startHead: true,
            endHead: true,
          );
        }
        break;
      case WordShapeKind.callout:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            2,
            2,
            math.max(0.0, size.width - 4),
            math.max(0.0, size.height - 12),
          ),
          const Radius.circular(8),
        );
        drawRoundRect(body);
        if (canStroke) {
          final tail = Path()
            ..moveTo(size.width * 0.28, math.max(2.0, size.height - 10))
            ..lineTo(size.width * 0.20, math.max(2.0, size.height - 2))
            ..lineTo(size.width * 0.42, math.max(2.0, size.height - 10));
          canvas.drawPath(tail, stroke);
        }
        break;
      case WordShapeKind.geometry:
        // Geometry design objects are rendered by GeometryPainter above.
        break;
    }
  }

  static void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required bool startHead,
    required bool endHead,
  }) {
    canvas.drawLine(start, end, paint);
    const head = 8.0;
    if (endHead) {
      canvas.drawLine(end, end.translate(-head, -head / 2), paint);
      canvas.drawLine(end, end.translate(-head, head / 2), paint);
    }
    if (startHead) {
      canvas.drawLine(start, start.translate(head, -head / 2), paint);
      canvas.drawLine(start, start.translate(head, head / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WordShapePainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.fillOpacity != fillOpacity;
  }
}
