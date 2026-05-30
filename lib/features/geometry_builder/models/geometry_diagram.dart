import 'dart:ui';

import 'geometry_label.dart';
import 'geometry_mark.dart';
import 'geometry_point.dart';
import 'geometry_shape.dart';

class GeometryDiagram {
  final String id;
  final String name;
  final Size canvasSize;
  final List<GeometryPoint> points;
  final List<GeometryShape> shapes;
  final List<GeometryLabel> labels;
  final List<GeometryMark> marks;
  final bool showGrid;
  final bool snapToGrid;
  final bool examMode;
  final bool transparentBackground;

  const GeometryDiagram({
    required this.id,
    this.name = 'Geometry Diagram',
    this.canvasSize = const Size(360, 240),
    this.points = const [],
    this.shapes = const [],
    this.labels = const [],
    this.marks = const [],
    this.showGrid = true,
    this.snapToGrid = true,
    this.examMode = true,
    this.transparentBackground = true,
  });

  String get placeholderToken => '{{geometry:$id}}';

  GeometryDiagram copyWith({
    String? name,
    Size? canvasSize,
    List<GeometryPoint>? points,
    List<GeometryShape>? shapes,
    List<GeometryLabel>? labels,
    List<GeometryMark>? marks,
    bool? showGrid,
    bool? snapToGrid,
    bool? examMode,
    bool? transparentBackground,
  }) {
    return GeometryDiagram(
      id: id,
      name: name ?? this.name,
      canvasSize: canvasSize ?? this.canvasSize,
      points: points ?? this.points,
      shapes: shapes ?? this.shapes,
      labels: labels ?? this.labels,
      marks: marks ?? this.marks,
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      examMode: examMode ?? this.examMode,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
    );
  }

  Map<String, GeometryPoint> get pointMap => {
    for (final point in points) point.id: point,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': canvasSize.width,
    'height': canvasSize.height,
    'points': points.map((point) => point.toJson()).toList(),
    'shapes': shapes.map((shape) => shape.toJson()).toList(),
    'labels': labels.map((label) => label.toJson()).toList(),
    'marks': marks.map((mark) => mark.toJson()).toList(),
    'showGrid': showGrid,
    'snapToGrid': snapToGrid,
    'examMode': examMode,
    'transparentBackground': transparentBackground,
  };

  factory GeometryDiagram.fromJson(Map<String, dynamic> json) {
    return GeometryDiagram(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Geometry Diagram',
      canvasSize: Size(
        (json['width'] as num?)?.toDouble() ?? 360,
        (json['height'] as num?)?.toDouble() ?? 240,
      ),
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeometryPoint.fromJson)
          .toList(),
      shapes: (json['shapes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeometryShape.fromJson)
          .toList(),
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeometryLabel.fromJson)
          .toList(),
      marks: (json['marks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeometryMark.fromJson)
          .toList(),
      showGrid: json['showGrid'] as bool? ?? true,
      snapToGrid: json['snapToGrid'] as bool? ?? true,
      examMode: json['examMode'] as bool? ?? true,
      transparentBackground: json['transparentBackground'] as bool? ?? true,
    );
  }
}
