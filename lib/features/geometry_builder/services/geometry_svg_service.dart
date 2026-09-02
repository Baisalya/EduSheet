import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/geometry_diagram.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';

/// Deterministic vector export for the canonical GeometryDiagram model.
///
/// Phase 4C intentionally makes PDF/DOCX export consume the same persisted
/// points/shapes/marks that Geometry Studio paints instead of substituting a
/// generic "[diagram]" placeholder.
class GeometrySvgService {
  String toSvg(GeometryDiagram diagram) {
    final width = diagram.canvasSize.width;
    final height = diagram.canvasSize.height;
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">',
      );
    if (!diagram.transparentBackground) {
      buffer.writeln('<rect width="100%" height="100%" fill="white"/>');
    }

    final pointMap = diagram.pointMap;
    for (final shape in diagram.shapes) {
      _writeShape(buffer, shape, pointMap);
    }
    for (final mark in diagram.marks) {
      _writeMark(buffer, mark, pointMap);
    }
    for (final point in diagram.points) {
      if (point.label.trim().isEmpty) continue;
      final label = point.labelPosition;
      final rotationDegrees = point.labelRotation * 180 / math.pi;
      buffer.writeln(
        '<text x="${_fmt(label.dx)}" y="${_fmt(label.dy)}" '
        'font-size="${_fmt(point.labelFontSize)}" font-family="Helvetica" '
        'font-weight="${point.labelBold ? '700' : '400'}" '
        'transform="rotate(${_fmt(rotationDegrees)} ${_fmt(label.dx)} ${_fmt(label.dy)})">'
        '${_escape(point.label)}</text>',
      );
    }
    for (final label in diagram.labels) {
      if (label.text.trim().isEmpty) continue;
      final rotationDegrees = label.rotation * 180 / math.pi;
      buffer.writeln(
        '<text x="${_fmt(label.position.dx)}" y="${_fmt(label.position.dy)}" '
        'font-size="${_fmt(label.fontSize)}" font-family="Helvetica" '
        'font-weight="${label.isBold ? '700' : '400'}" '
        'transform="rotate(${_fmt(rotationDegrees)} ${_fmt(label.position.dx)} ${_fmt(label.position.dy)})">'
        '${_escape(label.text)}</text>',
      );
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  void _writeShape(
    StringBuffer buffer,
    GeometryShape shape,
    Map<String, GeometryPoint> pointMap,
  ) {
    final points = shape.pointIds
        .map((id) => pointMap[id]?.position)
        .whereType<Offset>()
        .toList();
    if (points.isEmpty) return;

    switch (shape.type) {
      case GeometryShapeType.line:
        if (points.length >= 2) _line(buffer, points[0], points[1]);
      case GeometryShapeType.arrow:
        if (points.length >= 2) _arrow(buffer, points[0], points[1]);
      case GeometryShapeType.numberLine:
        if (points.length >= 2) {
          _line(buffer, points[0], points[1]);
          _numberLineTicks(buffer, points[0], points[1]);
        }
      case GeometryShapeType.circle:
      case GeometryShapeType.sphere:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        buffer.writeln(
          '<circle cx="${_fmt(points[0].dx)}" cy="${_fmt(points[0].dy)}" '
          'r="${_fmt(radius)}" fill="none" stroke="black" stroke-width="2"/>',
        );
        if (shape.type == GeometryShapeType.sphere) {
          buffer.writeln(
            '<ellipse cx="${_fmt(points[0].dx)}" cy="${_fmt(points[0].dy)}" '
            'rx="${_fmt(radius * 0.875)}" ry="${_fmt(radius * 0.275)}" '
            'fill="none" stroke="black" stroke-width="1.4"/>',
          );
        }
      case GeometryShapeType.semicircle:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        final center = points[0];
        final left = center - Offset(radius, 0);
        final right = center + Offset(radius, 0);
        buffer.writeln(
          '<path d="M ${_fmt(left.dx)} ${_fmt(left.dy)} '
          'A ${_fmt(radius)} ${_fmt(radius)} 0 0 1 ${_fmt(right.dx)} ${_fmt(right.dy)}" '
          'fill="none" stroke="black" stroke-width="2"/>',
        );
        _line(buffer, left, right);
      case GeometryShapeType.coordinateAxes:
        if (points.length >= 4) {
          _arrow(buffer, points[1], points[0]);
          _arrow(buffer, points[2], points[3]);
          _text(buffer, 'x', points[3] + const Offset(8, -8), size: 12);
          _text(buffer, 'y', points[0] + const Offset(8, 12), size: 12);
        }
      case GeometryShapeType.cube:
        if (points.length >= 8) {
          _polygon(buffer, points.take(4).toList(), close: true);
          _polygon(buffer, points.skip(4).take(4).toList(), close: true);
          for (var i = 0; i < 4; i++) {
            _line(buffer, points[i], points[i + 4]);
          }
        }
      case GeometryShapeType.cuboid:
        if (points.length >= 4) {
          _polygon(buffer, points, close: true);
          final shifted = points.map((p) => p + const Offset(44, -36)).toList();
          _polygon(buffer, shifted, close: true);
          for (var i = 0; i < points.length; i++) {
            _line(buffer, points[i], shifted[i]);
          }
        }
      case GeometryShapeType.cylinder:
        if (points.length >= 4) _cylinder(buffer, points);
      case GeometryShapeType.cone:
        final radius = points.length >= 2
            ? (points[1] - points[0]).distance
            : shape.radius;
        _cone(buffer, points[0], radius);
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
        _polygon(buffer, points, close: points.length > 2);
    }
  }

  void _writeMark(
    StringBuffer buffer,
    GeometryMark mark,
    Map<String, GeometryPoint> pointMap,
  ) {
    final points = mark.pointIds
        .map((id) => pointMap[id]?.position)
        .whereType<Offset>()
        .toList();
    switch (mark.type) {
      case GeometryMarkType.angleArc:
      case GeometryMarkType.curvedArc:
        if (points.length >= 3) {
          final vertex = points[0];
          final a1 = math.atan2(
            points[1].dy - vertex.dy,
            points[1].dx - vertex.dx,
          );
          final a2 = math.atan2(
            points[2].dy - vertex.dy,
            points[2].dx - vertex.dx,
          );
          var sweep = a2 - a1;
          while (sweep <= -math.pi) {
            sweep += math.pi * 2;
          }
          while (sweep > math.pi) {
            sweep -= math.pi * 2;
          }
          const radius = 26.0;
          final start = vertex + Offset(math.cos(a1), math.sin(a1)) * radius;
          final end =
              vertex +
              Offset(math.cos(a1 + sweep), math.sin(a1 + sweep)) * radius;
          buffer.writeln(
            '<path d="M ${_fmt(start.dx)} ${_fmt(start.dy)} '
            'A $radius $radius 0 0 ${sweep >= 0 ? 1 : 0} ${_fmt(end.dx)} ${_fmt(end.dy)}" '
            'fill="none" stroke="black" stroke-width="1.7"/>',
          );
        }
      case GeometryMarkType.rightAngle:
        if (points.length >= 3) {
          final vertex = points[0];
          final u = _unit(points[1] - vertex);
          final v = _unit(points[2] - vertex);
          if (u != Offset.zero && v != Offset.zero) {
            const size = 17.0;
            final p1 = vertex + u * size;
            final corner = p1 + v * size;
            final p2 = vertex + v * size;
            _polyline(buffer, [p1, corner, p2]);
          }
        }
      case GeometryMarkType.equalSideTick:
      case GeometryMarkType.parallelLine:
        if (points.length >= 2) {
          final a = points[0];
          final b = points[1];
          final midpoint = (a + b) / 2;
          final direction = _unit(b - a);
          final normal = Offset(-direction.dy, direction.dx);
          if (mark.type == GeometryMarkType.equalSideTick) {
            _line(
              buffer,
              midpoint - normal * 8,
              midpoint + normal * 8,
              width: 1.6,
            );
          } else {
            for (final shift in const [-5.0, 5.0]) {
              final center = midpoint + direction * shift;
              _line(
                buffer,
                center - normal * 7,
                center + normal * 7,
                width: 1.6,
              );
            }
          }
        }
      case GeometryMarkType.dottedConstructionLine:
      case GeometryMarkType.dashedHeightLine:
        if (points.length >= 2) {
          _line(buffer, points[0], points[1], width: 1.5, dash: '6 5');
        }
      case GeometryMarkType.radiusLine:
      case GeometryMarkType.diameterLine:
        if (points.length >= 2) {
          _line(buffer, points[0], points[1], width: 1.5);
        }
      case GeometryMarkType.arrowHead:
        if (points.length >= 2) {
          _arrow(buffer, points[0], points[1], width: 1.5);
        }
      case GeometryMarkType.doubleArrow:
        if (points.length >= 2) {
          _arrow(buffer, points[0], points[1], width: 1.5);
          _arrow(buffer, points[1], points[0], width: 1.5);
        }
      case GeometryMarkType.centerPoint:
        final origin = points.isNotEmpty ? points.first : mark.position;
        buffer.writeln(
          '<circle cx="${_fmt(origin.dx)}" cy="${_fmt(origin.dy)}" r="3" fill="black"/>',
        );
    }
  }

  void _line(
    StringBuffer buffer,
    Offset start,
    Offset end, {
    double width = 2,
    String? dash,
  }) {
    buffer.writeln(
      '<line x1="${_fmt(start.dx)}" y1="${_fmt(start.dy)}" '
      'x2="${_fmt(end.dx)}" y2="${_fmt(end.dy)}" '
      'stroke="black" stroke-width="${_fmt(width)}" stroke-linecap="round"'
      '${dash == null ? '' : ' stroke-dasharray="$dash"'}/>',
    );
  }

  void _arrow(
    StringBuffer buffer,
    Offset start,
    Offset end, {
    double width = 2,
  }) {
    _line(buffer, start, end, width: width);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 13.0;
    final p1 =
        end -
        Offset(math.cos(angle - math.pi / 6), math.sin(angle - math.pi / 6)) *
            length;
    final p2 =
        end -
        Offset(math.cos(angle + math.pi / 6), math.sin(angle + math.pi / 6)) *
            length;
    _line(buffer, end, p1, width: width);
    _line(buffer, end, p2, width: width);
  }

  void _numberLineTicks(StringBuffer buffer, Offset start, Offset end) {
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    for (var index = 0; index <= 10; index++) {
      final point = start + delta * (index / 10);
      _line(buffer, point - normal * 6, point + normal * 6, width: 1.4);
    }
  }

  void _polygon(
    StringBuffer buffer,
    List<Offset> points, {
    required bool close,
  }) {
    if (points.length < 2) return;
    final data = points.map((p) => '${_fmt(p.dx)},${_fmt(p.dy)}').join(' ');
    if (close) {
      buffer.writeln(
        '<polygon points="$data" fill="none" stroke="black" stroke-width="2" stroke-linejoin="round"/>',
      );
    } else {
      buffer.writeln(
        '<polyline points="$data" fill="none" stroke="black" stroke-width="2" stroke-linejoin="round"/>',
      );
    }
  }

  void _polyline(StringBuffer buffer, List<Offset> points) {
    _polygon(buffer, points, close: false);
  }

  void _cylinder(StringBuffer buffer, List<Offset> points) {
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    final top = points.map((p) => p.dy).reduce(math.min);
    final bottom = points.map((p) => p.dy).reduce(math.max);
    final width = right - left;
    final height = bottom - top;
    final capHeight = height * 0.24;
    _line(
      buffer,
      Offset(left, top + capHeight / 2),
      Offset(left, bottom - capHeight / 2),
    );
    _line(
      buffer,
      Offset(right, top + capHeight / 2),
      Offset(right, bottom - capHeight / 2),
    );
    buffer.writeln(
      '<ellipse cx="${_fmt((left + right) / 2)}" cy="${_fmt(top + capHeight / 2)}" '
      'rx="${_fmt(width / 2)}" ry="${_fmt(capHeight / 2)}" fill="none" stroke="black" stroke-width="2"/>',
    );
    buffer.writeln(
      '<ellipse cx="${_fmt((left + right) / 2)}" cy="${_fmt(bottom - capHeight / 2)}" '
      'rx="${_fmt(width / 2)}" ry="${_fmt(capHeight / 2)}" fill="none" stroke="black" stroke-width="2"/>',
    );
  }

  void _cone(StringBuffer buffer, Offset center, double radius) {
    final top = center + Offset(0, -radius);
    final baseCenter = center + Offset(0, radius * 0.7);
    final left = baseCenter + Offset(-radius, 0);
    final right = baseCenter + Offset(radius, 0);
    _line(buffer, top, left);
    _line(buffer, top, right);
    buffer.writeln(
      '<ellipse cx="${_fmt(baseCenter.dx)}" cy="${_fmt(baseCenter.dy)}" '
      'rx="${_fmt(radius)}" ry="${_fmt(radius * 0.275)}" fill="none" stroke="black" stroke-width="2"/>',
    );
  }

  void _text(
    StringBuffer buffer,
    String text,
    Offset position, {
    double size = 12,
  }) {
    buffer.writeln(
      '<text x="${_fmt(position.dx)}" y="${_fmt(position.dy)}" '
      'font-size="${_fmt(size)}" font-family="Helvetica">${_escape(text)}</text>',
    );
  }

  Offset _unit(Offset value) {
    final length = value.distance;
    if (length == 0) return Offset.zero;
    return value / length;
  }

  String toTikz(GeometryDiagram diagram) {
    final buffer = StringBuffer()..writeln(r'\begin{tikzpicture}');
    final points = diagram.pointMap;
    final names = <String, String>{};
    var generatedIndex = 0;
    for (final point in diagram.points) {
      final name = point.label.trim().isEmpty
          ? 'P${generatedIndex++}'
          : point.label;
      names[point.id] = name;
      buffer.writeln(
        '\\coordinate ($name) at (${_fmt(point.position.dx / 40)},${_fmt(-point.position.dy / 40)});',
      );
    }
    for (final shape in diagram.shapes) {
      final pointNames = shape.pointIds
          .map((id) => names[id] ?? points[id]?.label)
          .whereType<String>()
          .toList();
      if (pointNames.length >= 2) {
        if (shape.type == GeometryShapeType.circle &&
            shape.pointIds.isNotEmpty) {
          buffer.writeln(
            '\\draw (${pointNames.first}) circle (${_fmt(shape.radius / 40)});',
          );
        } else {
          final closed = pointNames.length > 2 ? ' -- cycle' : '';
          buffer.writeln(
            '\\draw ${pointNames.map((name) => '($name)').join(' -- ')}$closed;',
          );
        }
      }
    }
    for (final label in diagram.labels) {
      buffer.writeln(
        '\\node at (${_fmt(label.position.dx / 40)},${_fmt(-label.position.dy / 40)}) {${_escape(label.text)}};',
      );
    }
    buffer.writeln(r'\end{tikzpicture}');
    return buffer.toString();
  }

  String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
