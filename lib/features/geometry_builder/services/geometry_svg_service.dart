import 'package:flutter/material.dart';

import '../models/geometry_diagram.dart';
import '../models/geometry_shape.dart';

class GeometrySvgService {
  String toSvg(GeometryDiagram diagram) {
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="${diagram.canvasSize.width}" height="${diagram.canvasSize.height}" viewBox="0 0 ${diagram.canvasSize.width} ${diagram.canvasSize.height}">',
      );
    if (!diagram.transparentBackground) {
      buffer.writeln('<rect width="100%" height="100%" fill="white"/>');
    }
    final points = diagram.pointMap;
    for (final shape in diagram.shapes) {
      final offsets = shape.pointIds
          .map((id) => points[id]?.position)
          .whereType<Offset>()
          .toList();
      if (offsets.isEmpty) continue;
      switch (shape.type) {
        case GeometryShapeType.circle:
        case GeometryShapeType.sphere:
          final radius = offsets.length > 1
              ? (offsets[1] - offsets[0]).distance
              : shape.radius;
          buffer.writeln(
            '<circle cx="${offsets[0].dx}" cy="${offsets[0].dy}" r="$radius" fill="none" stroke="black" stroke-width="2"/>',
          );
        case GeometryShapeType.line:
        case GeometryShapeType.arrow:
        case GeometryShapeType.numberLine:
          if (offsets.length > 1) {
            buffer.writeln(
              '<line x1="${offsets[0].dx}" y1="${offsets[0].dy}" x2="${offsets[1].dx}" y2="${offsets[1].dy}" stroke="black" stroke-width="2"/>',
            );
          }
        default:
          final data = offsets
              .map((point) => '${point.dx},${point.dy}')
              .join(' ');
          buffer.writeln(
            '<polygon points="$data" fill="none" stroke="black" stroke-width="2"/>',
          );
      }
    }
    for (final point in diagram.points) {
      buffer.writeln(
        '<circle cx="${point.position.dx}" cy="${point.position.dy}" r="3" fill="white" stroke="black"/>',
      );
      buffer.writeln(
        '<text x="${point.position.dx + 6}" y="${point.position.dy - 8}" font-size="12" font-family="Arial">${_escape(point.label)}</text>',
      );
    }
    for (final label in diagram.labels) {
      buffer.writeln(
        '<text x="${label.position.dx}" y="${label.position.dy}" font-size="13" font-family="Arial" font-weight="600">${_escape(label.text)}</text>',
      );
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  String toTikz(GeometryDiagram diagram) {
    final buffer = StringBuffer()..writeln(r'\begin{tikzpicture}');
    final points = diagram.pointMap;
    for (final point in diagram.points) {
      buffer.writeln(
        '\\coordinate (${point.label}) at (${_fmt(point.position.dx / 40)},${_fmt(-point.position.dy / 40)});',
      );
    }
    for (final shape in diagram.shapes) {
      final names = shape.pointIds
          .map((id) => points[id]?.label)
          .whereType<String>()
          .toList();
      if (names.length >= 2) {
        if (shape.type == GeometryShapeType.circle &&
            shape.pointIds.isNotEmpty) {
          buffer.writeln(
            '\\draw (${names.first}) circle (${_fmt(shape.radius / 40)});',
          );
        } else {
          final closed = names.length > 2 ? ' -- cycle' : '';
          buffer.writeln(
            '\\draw ${names.map((name) => '($name)').join(' -- ')}$closed;',
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

  String _fmt(double value) => value.toStringAsFixed(2);

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
