import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/geometry_diagram.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';

class GeometryPainter extends CustomPainter {
  final GeometryDiagram diagram;
  final bool showPointHandles;

  GeometryPainter({required this.diagram, this.showPointHandles = true});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / diagram.canvasSize.width;
    final scaleY = size.height / diagram.canvasSize.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    if (!diagram.transparentBackground) {
      canvas.drawRect(
        Offset.zero & diagram.canvasSize,
        Paint()..color = Colors.white,
      );
    }

    if (diagram.showGrid) _drawGrid(canvas);

    final points = diagram.pointMap;
    for (final shape in diagram.shapes) {
      _drawShape(canvas, shape, points);
    }
    for (final mark in diagram.marks) {
      _drawMark(canvas, mark, points);
    }
    for (final point in diagram.points) {
      _drawPoint(canvas, point);
    }
    for (final label in diagram.labels) {
      _drawText(canvas, label.text, label.position, fontSize: 13);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 0.6;
    const step = 20.0;
    for (var x = 0.0; x <= diagram.canvasSize.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, diagram.canvasSize.height),
        paint,
      );
    }
    for (var y = 0.0; y <= diagram.canvasSize.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(diagram.canvasSize.width, y), paint);
    }
  }

  void _drawShape(
    Canvas canvas,
    GeometryShape shape,
    Map<String, GeometryPoint> pointMap,
  ) {
    final points = shape.pointIds
        .map((id) => pointMap[id]?.position)
        .whereType<Offset>()
        .toList();
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape.type) {
      case GeometryShapeType.line:
      case GeometryShapeType.numberLine:
        if (points.length >= 2) {
          canvas.drawLine(points[0], points[1], paint);
          if (shape.type == GeometryShapeType.numberLine) {
            _drawNumberLineTicks(canvas, points[0], points[1], paint);
          }
        }
      case GeometryShapeType.arrow:
        if (points.length >= 2) _drawArrow(canvas, points[0], points[1], paint);
      case GeometryShapeType.circle:
      case GeometryShapeType.sphere:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        canvas.drawCircle(points[0], radius, paint);
        if (shape.type == GeometryShapeType.sphere) {
          canvas.drawOval(
            Rect.fromCenter(
              center: points[0],
              width: radius * 1.75,
              height: radius * 0.55,
            ),
            paint..color = Colors.black.withValues(alpha: 0.55),
          );
          paint.color = Colors.black;
        }
      case GeometryShapeType.semicircle:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        final rect = Rect.fromCircle(center: points[0], radius: radius);
        canvas.drawArc(rect, math.pi, math.pi, false, paint);
        canvas.drawLine(
          points[0] - Offset(radius, 0),
          points[0] + Offset(radius, 0),
          paint,
        );
      case GeometryShapeType.coordinateAxes:
        if (points.length >= 4) {
          _drawArrow(canvas, points[1], points[0], paint);
          _drawArrow(canvas, points[2], points[3], paint);
          _drawText(canvas, 'x', points[3] + const Offset(8, -12));
          _drawText(canvas, 'y', points[0] + const Offset(8, -6));
        }
      case GeometryShapeType.cube:
        if (points.length >= 8) _drawCube(canvas, points, paint);
      case GeometryShapeType.cuboid:
        if (points.length >= 4) {
          _drawPolygon(canvas, points, paint, close: true);
          final shifted = points.map((p) => p + const Offset(44, -36)).toList();
          _drawPolygon(canvas, shifted, paint, close: true);
          for (var i = 0; i < points.length; i++) {
            canvas.drawLine(points[i], shifted[i], paint);
          }
        }
      case GeometryShapeType.cylinder:
        if (points.length >= 4) _drawCylinder(canvas, points, paint);
      case GeometryShapeType.cone:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        _drawCone(canvas, points[0], radius, paint);
      case GeometryShapeType.triangle:
      case GeometryShapeType.rightTriangle:
      case GeometryShapeType.square:
      case GeometryShapeType.rectangle:
      case GeometryShapeType.parallelogram:
      case GeometryShapeType.trapezium:
      case GeometryShapeType.rhombus:
      case GeometryShapeType.pentagon:
      case GeometryShapeType.hexagon:
      case GeometryShapeType.polygon:
        _drawPolygon(canvas, points, paint, close: points.length > 2);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required bool close,
  }) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (close) path.close();
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 14.0;
    final p1 =
        end -
        Offset(math.cos(angle - math.pi / 6), math.sin(angle - math.pi / 6)) *
            length;
    final p2 =
        end -
        Offset(math.cos(angle + math.pi / 6), math.sin(angle + math.pi / 6)) *
            length;
    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  void _drawNumberLineTicks(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final point = Offset.lerp(start, end, t)!;
      canvas.drawLine(
        point + const Offset(0, -6),
        point + const Offset(0, 6),
        paint,
      );
    }
  }

  void _drawCube(Canvas canvas, List<Offset> points, Paint paint) {
    _drawPolygon(canvas, points.take(4).toList(), paint, close: true);
    _drawPolygon(canvas, points.skip(4).take(4).toList(), paint, close: true);
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(points[i], points[i + 4], paint);
    }
  }

  void _drawCylinder(Canvas canvas, List<Offset> points, Paint paint) {
    final rect = Rect.fromPoints(points[0], points[2]);
    canvas.drawLine(
      rect.topLeft + Offset(0, rect.height * 0.12),
      rect.bottomLeft - Offset(0, rect.height * 0.12),
      paint,
    );
    canvas.drawLine(
      rect.topRight + Offset(0, rect.height * 0.12),
      rect.bottomRight - Offset(0, rect.height * 0.12),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.24),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        rect.left,
        rect.bottom - rect.height * 0.24,
        rect.width,
        rect.height * 0.24,
      ),
      paint,
    );
  }

  void _drawCone(Canvas canvas, Offset center, double radius, Paint paint) {
    final top = center + Offset(0, -radius);
    final left = center + Offset(-radius, radius * 0.7);
    final right = center + Offset(radius, radius * 0.7);
    canvas.drawLine(top, left, paint);
    canvas.drawLine(top, right, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.7),
        width: radius * 2,
        height: radius * 0.55,
      ),
      paint,
    );
  }

  void _drawMark(
    Canvas canvas,
    GeometryMark mark,
    Map<String, GeometryPoint> pointMap,
  ) {
    final points = mark.pointIds
        .map((id) => pointMap[id]?.position)
        .whereType<Offset>()
        .toList();
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    switch (mark.type) {
      case GeometryMarkType.rightAngle:
        final origin = points.isNotEmpty ? points.first : mark.position;
        final path = Path()
          ..moveTo(origin.dx + 18, origin.dy)
          ..lineTo(origin.dx + 18, origin.dy - 18)
          ..lineTo(origin.dx, origin.dy - 18);
        canvas.drawPath(path, paint);
      case GeometryMarkType.angleArc:
      case GeometryMarkType.curvedArc:
        final origin = points.isNotEmpty ? points.first : mark.position;
        canvas.drawArc(
          Rect.fromCircle(center: origin, radius: 26),
          -math.pi / 2,
          math.pi / 2,
          false,
          paint,
        );
      case GeometryMarkType.equalSideTick:
      case GeometryMarkType.parallelLine:
        final origin = mark.position;
        canvas.drawLine(
          origin + const Offset(-5, -10),
          origin + const Offset(5, 10),
          paint,
        );
      case GeometryMarkType.dottedConstructionLine:
      case GeometryMarkType.dashedHeightLine:
        if (points.length >= 2) {
          _drawDashedLine(canvas, points[0], points[1], paint);
        }
      case GeometryMarkType.radiusLine:
      case GeometryMarkType.diameterLine:
      case GeometryMarkType.arrowHead:
      case GeometryMarkType.doubleArrow:
        if (points.length >= 2) _drawArrow(canvas, points[0], points[1], paint);
      case GeometryMarkType.centerPoint:
        final origin = points.isNotEmpty ? points.first : mark.position;
        canvas.drawCircle(origin, 3, paint..style = PaintingStyle.fill);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    for (var distance = 0.0; distance < total; distance += 12) {
      final dashStart = start + direction * distance;
      final dashEnd = start + direction * math.min(distance + 7, total);
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  void _drawPoint(Canvas canvas, GeometryPoint point) {
    if (showPointHandles) {
      canvas.drawCircle(point.position, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        point.position,
        4.5,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    _drawText(
      canvas,
      point.label,
      point.position + const Offset(6, -18),
      fontSize: 12,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 12,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 180);
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant GeometryPainter oldDelegate) {
    return oldDelegate.diagram != diagram ||
        oldDelegate.showPointHandles != showPointHandles;
  }
}
