import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../application/geometry_freeform_tool.dart';

class GeometryFreeformDraftPainter extends CustomPainter {
  final GeometryFreeformTool tool;
  final Size diagramSize;
  final Offset? start;
  final Offset? current;
  final List<Offset> angleDraft;

  const GeometryFreeformDraftPainter({
    required this.tool,
    required this.diagramSize,
    this.start,
    this.current,
    this.angleDraft = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (diagramSize.width <= 0 || diagramSize.height <= 0) return;
    canvas.save();
    canvas.scale(
      size.width / diagramSize.width,
      size.height / diagramSize.height,
    );

    final paint = Paint()
      ..color = const Color(0xFF1976D2).withValues(alpha: 0.72)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (tool == GeometryFreeformTool.angle && angleDraft.isNotEmpty) {
      for (final point in angleDraft) {
        canvas.drawCircle(point, 5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
      if (angleDraft.length >= 2) {
        canvas.drawLine(angleDraft[0], angleDraft[1], paint);
      }
      canvas.restore();
      return;
    }

    final a = start;
    final b = current;
    if (a == null || b == null) {
      canvas.restore();
      return;
    }

    switch (tool) {
      case GeometryFreeformTool.line:
        canvas.drawLine(a, b, paint);
      case GeometryFreeformTool.arrow:
        _drawArrow(canvas, a, b, paint);
      case GeometryFreeformTool.circle:
        canvas.drawCircle(a, (b - a).distance, paint);
      case GeometryFreeformTool.coordinateAxes:
        _drawAxes(canvas, a, b, paint);
      case GeometryFreeformTool.numberLine:
        _drawNumberLine(canvas, a, b, paint);
      case GeometryFreeformTool.select:
      case GeometryFreeformTool.point:
      case GeometryFreeformTool.angle:
        break;
    }
    canvas.restore();
  }

  void _drawAxes(Canvas canvas, Offset origin, Offset edge, Paint paint) {
    final horizontal = math.max(40.0, (edge.dx - origin.dx).abs());
    final vertical = math.max(40.0, (edge.dy - origin.dy).abs());
    _drawArrow(
      canvas,
      origin + Offset(0, vertical),
      origin - Offset(0, vertical),
      paint,
    );
    _drawArrow(
      canvas,
      origin - Offset(horizontal, 0),
      origin + Offset(horizontal, 0),
      paint,
    );
  }

  void _drawNumberLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    for (var index = 0; index <= 10; index++) {
      final point = start + delta * (index / 10);
      canvas.drawLine(point - normal * 5, point + normal * 5, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 13.0;
    final first =
        end -
        Offset(math.cos(angle - math.pi / 6), math.sin(angle - math.pi / 6)) *
            length;
    final second =
        end -
        Offset(math.cos(angle + math.pi / 6), math.sin(angle + math.pi / 6)) *
            length;
    canvas.drawLine(end, first, paint);
    canvas.drawLine(end, second, paint);
  }

  @override
  bool shouldRepaint(covariant GeometryFreeformDraftPainter oldDelegate) {
    return tool != oldDelegate.tool ||
        diagramSize != oldDelegate.diagramSize ||
        start != oldDelegate.start ||
        current != oldDelegate.current ||
        !_sameOffsets(angleDraft, oldDelegate.angleDraft);
  }

  bool _sameOffsets(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
