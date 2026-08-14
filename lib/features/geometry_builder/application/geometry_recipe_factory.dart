import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../models/geometry_diagram.dart';
import '../models/geometry_mark.dart';
import '../models/geometry_point.dart';
import '../models/geometry_shape.dart';
import 'geometry_recipe.dart';

class GeometryRecipeFactory {
  const GeometryRecipeFactory();

  GeometryDiagram build(
    GeometryRecipe recipe, {
    String? diagramId,
    Size canvasSize = const Size(360, 240),
  }) {
    final id = diagramId ?? const Uuid().v4();
    switch (recipe.id) {
      case 'isosceles_triangle':
        return _isosceles(id, canvasSize);
      case 'equilateral_triangle':
        return _equilateral(id, canvasSize);
      case 'angle':
        return _angle(id, canvasSize);
      case 'parallel_lines':
        return _parallelLines(id, canvasSize);
      case 'circle_radius':
        return _circleConstruction(id, canvasSize, 'radius');
      case 'circle_diameter':
        return _circleConstruction(id, canvasSize, 'diameter');
      case 'circle_chord':
        return _circleConstruction(id, canvasSize, 'chord');
      case 'circle_tangent':
        return _circleConstruction(id, canvasSize, 'tangent');
      default:
        final type = recipe.baseShape;
        if (type == null) {
          return GeometryDiagram(id: id, canvasSize: canvasSize);
        }
        return buildShape(type, diagramId: id, canvasSize: canvasSize);
    }
  }

  GeometryDiagram buildShape(
    GeometryShapeType type, {
    String? diagramId,
    Size canvasSize = const Size(360, 240),
  }) {
    final id = diagramId ?? const Uuid().v4();
    final points = _templatePoints(type);
    final shape = GeometryShape(
      id: const Uuid().v4(),
      type: type,
      pointIds: points.map((point) => point.id).toList(),
      radius: type == GeometryShapeType.sphere ? 62 : 56,
    );
    final marks = <GeometryMark>[];
    if (type == GeometryShapeType.rightTriangle && points.length >= 3) {
      marks.add(
        GeometryMark(
          id: const Uuid().v4(),
          type: GeometryMarkType.rightAngle,
          pointIds: [points[0].id, points[1].id, points[2].id],
          position: points[0].position,
        ),
      );
    }
    if (type == GeometryShapeType.circle && points.isNotEmpty) {
      marks.add(
        GeometryMark(
          id: const Uuid().v4(),
          type: GeometryMarkType.centerPoint,
          pointIds: [points.first.id],
          position: points.first.position,
        ),
      );
    }
    return GeometryDiagram(
      id: id,
      name: _shapeTitle(type),
      canvasSize: canvasSize,
      points: points,
      shapes: [shape],
      marks: marks,
      showGrid: true,
      snapToGrid: true,
      examMode: true,
      transparentBackground: true,
    );
  }

  GeometryDiagram _isosceles(String id, Size size) {
    final points = _points(const [
      ('A', Offset(180, 48)),
      ('B', Offset(82, 196)),
      ('C', Offset(278, 196)),
    ]);
    final shape = _polygonShape(GeometryShapeType.triangle, points);
    return GeometryDiagram(
      id: id,
      name: 'Isosceles Triangle',
      canvasSize: size,
      points: points,
      shapes: [shape],
      marks: [
        _segmentMark(GeometryMarkType.equalSideTick, points[0], points[1]),
        _segmentMark(GeometryMarkType.equalSideTick, points[0], points[2]),
      ],
    );
  }

  GeometryDiagram _equilateral(String id, Size size) {
    final points = _points(const [
      ('A', Offset(180, 34)),
      ('B', Offset(90, 190)),
      ('C', Offset(270, 190)),
    ]);
    final shape = _polygonShape(GeometryShapeType.triangle, points);
    return GeometryDiagram(
      id: id,
      name: 'Equilateral Triangle',
      canvasSize: size,
      points: points,
      shapes: [shape],
      marks: [
        _segmentMark(GeometryMarkType.equalSideTick, points[0], points[1]),
        _segmentMark(GeometryMarkType.equalSideTick, points[1], points[2]),
        _segmentMark(GeometryMarkType.equalSideTick, points[2], points[0]),
      ],
    );
  }

  GeometryDiagram _angle(String id, Size size) {
    final points = _points(const [
      ('O', Offset(150, 170)),
      ('A', Offset(282, 170)),
      ('B', Offset(225, 72)),
    ]);
    return GeometryDiagram(
      id: id,
      name: 'Angle',
      canvasSize: size,
      points: points,
      shapes: [
        GeometryShape(
          id: const Uuid().v4(),
          type: GeometryShapeType.line,
          pointIds: [points[0].id, points[1].id],
        ),
        GeometryShape(
          id: const Uuid().v4(),
          type: GeometryShapeType.line,
          pointIds: [points[0].id, points[2].id],
        ),
      ],
      marks: [
        GeometryMark(
          id: const Uuid().v4(),
          type: GeometryMarkType.angleArc,
          pointIds: [points[0].id, points[1].id, points[2].id],
          position: points[0].position,
        ),
      ],
    );
  }

  GeometryDiagram _parallelLines(String id, Size size) {
    final points = _points(const [
      ('A', Offset(72, 84)),
      ('B', Offset(288, 84)),
      ('C', Offset(72, 174)),
      ('D', Offset(288, 174)),
    ]);
    return GeometryDiagram(
      id: id,
      name: 'Parallel Lines',
      canvasSize: size,
      points: points,
      shapes: [
        GeometryShape(
          id: const Uuid().v4(),
          type: GeometryShapeType.line,
          pointIds: [points[0].id, points[1].id],
        ),
        GeometryShape(
          id: const Uuid().v4(),
          type: GeometryShapeType.line,
          pointIds: [points[2].id, points[3].id],
        ),
      ],
      marks: [
        _segmentMark(GeometryMarkType.parallelLine, points[0], points[1]),
        _segmentMark(GeometryMarkType.parallelLine, points[2], points[3]),
      ],
    );
  }

  GeometryDiagram _circleConstruction(String id, Size size, String kind) {
    final center = GeometryPoint(
      id: const Uuid().v4(),
      label: 'O',
      position: const Offset(180, 126),
    );
    final edge = GeometryPoint(
      id: const Uuid().v4(),
      label: 'A',
      position: const Offset(246, 126),
    );
    final points = <GeometryPoint>[center, edge];
    final shapes = <GeometryShape>[
      GeometryShape(
        id: const Uuid().v4(),
        type: GeometryShapeType.circle,
        pointIds: [center.id, edge.id],
      ),
    ];
    final marks = <GeometryMark>[
      GeometryMark(
        id: const Uuid().v4(),
        type: GeometryMarkType.centerPoint,
        pointIds: [center.id],
        position: center.position,
      ),
    ];

    switch (kind) {
      case 'radius':
        marks.add(
          GeometryMark(
            id: const Uuid().v4(),
            type: GeometryMarkType.radiusLine,
            pointIds: [center.id, edge.id],
            position: (center.position + edge.position) / 2,
          ),
        );
      case 'diameter':
        final left = GeometryPoint(
          id: const Uuid().v4(),
          label: 'B',
          position: const Offset(114, 126),
        );
        points.add(left);
        marks.add(
          GeometryMark(
            id: const Uuid().v4(),
            type: GeometryMarkType.diameterLine,
            pointIds: [left.id, edge.id],
            position: center.position,
          ),
        );
      case 'chord':
        final p1 = GeometryPoint(
          id: const Uuid().v4(),
          label: 'B',
          position: const Offset(140, 74),
        );
        final p2 = GeometryPoint(
          id: const Uuid().v4(),
          label: 'C',
          position: const Offset(220, 74),
        );
        points.addAll([p1, p2]);
        shapes.add(
          GeometryShape(
            id: const Uuid().v4(),
            type: GeometryShapeType.line,
            pointIds: [p1.id, p2.id],
          ),
        );
      case 'tangent':
        final top = GeometryPoint(
          id: const Uuid().v4(),
          label: '',
          position: const Offset(246, 54),
        );
        final bottom = GeometryPoint(
          id: const Uuid().v4(),
          label: '',
          position: const Offset(246, 204),
        );
        points.addAll([top, bottom]);
        shapes.add(
          GeometryShape(
            id: const Uuid().v4(),
            type: GeometryShapeType.line,
            pointIds: [top.id, bottom.id],
          ),
        );
    }

    return GeometryDiagram(
      id: id,
      name: 'Circle',
      canvasSize: size,
      points: points,
      shapes: shapes,
      marks: marks,
    );
  }

  List<GeometryPoint> _templatePoints(GeometryShapeType type) {
    final coords = switch (type) {
      GeometryShapeType.line || GeometryShapeType.arrow => const [
        ('A', Offset(80, 120)),
        ('B', Offset(280, 120)),
      ],
      GeometryShapeType.numberLine => const [
        ('', Offset(60, 126)),
        ('', Offset(300, 126)),
      ],
      GeometryShapeType.triangle => const [
        ('A', Offset(180, 48)),
        ('B', Offset(72, 196)),
        ('C', Offset(292, 196)),
      ],
      GeometryShapeType.rightTriangle => const [
        ('A', Offset(84, 196)),
        ('B', Offset(84, 68)),
        ('C', Offset(280, 196)),
      ],
      GeometryShapeType.square => const [
        ('A', Offset(104, 64)),
        ('B', Offset(256, 64)),
        ('C', Offset(256, 216)),
        ('D', Offset(104, 216)),
      ],
      GeometryShapeType.rectangle ||
      GeometryShapeType.cuboid ||
      GeometryShapeType.cylinder => const [
        ('A', Offset(76, 76)),
        ('B', Offset(284, 76)),
        ('C', Offset(284, 196)),
        ('D', Offset(76, 196)),
      ],
      GeometryShapeType.circle ||
      GeometryShapeType.semicircle ||
      GeometryShapeType.sphere ||
      GeometryShapeType.cone => const [
        ('O', Offset(180, 128)),
        ('A', Offset(236, 128)),
      ],
      GeometryShapeType.parallelogram => const [
        ('A', Offset(116, 76)),
        ('B', Offset(288, 76)),
        ('C', Offset(244, 196)),
        ('D', Offset(72, 196)),
      ],
      GeometryShapeType.trapezium => const [
        ('A', Offset(132, 76)),
        ('B', Offset(228, 76)),
        ('C', Offset(292, 196)),
        ('D', Offset(68, 196)),
      ],
      GeometryShapeType.rhombus => const [
        ('A', Offset(180, 48)),
        ('B', Offset(292, 132)),
        ('C', Offset(180, 216)),
        ('D', Offset(68, 132)),
      ],
      GeometryShapeType.pentagon => _namedPolygon(5),
      GeometryShapeType.hexagon => _namedPolygon(6),
      GeometryShapeType.coordinateAxes => const [
        ('', Offset(180, 32)),
        ('', Offset(180, 220)),
        ('', Offset(42, 126)),
        ('', Offset(318, 126)),
      ],
      GeometryShapeType.cube => const [
        ('A', Offset(88, 92)),
        ('B', Offset(220, 92)),
        ('C', Offset(220, 216)),
        ('D', Offset(88, 216)),
        ('E', Offset(140, 48)),
        ('F', Offset(272, 48)),
        ('G', Offset(272, 172)),
        ('H', Offset(140, 172)),
      ],
      GeometryShapeType.polygon => _namedPolygon(5),
    };
    return _points(coords);
  }

  List<(String, Offset)> _namedPolygon(int sides) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final coords = _regularPolygon(sides);
    return [for (var i = 0; i < coords.length; i++) (letters[i], coords[i])];
  }

  List<Offset> _regularPolygon(int sides) {
    const center = Offset(180, 132);
    const radius = 86.0;
    return [
      for (var i = 0; i < sides; i++)
        Offset(
          center.dx +
              math.cos(-math.pi / 2 + (math.pi * 2 * i / sides)) * radius,
          center.dy +
              math.sin(-math.pi / 2 + (math.pi * 2 * i / sides)) * radius,
        ),
    ];
  }

  List<GeometryPoint> _points(List<(String, Offset)> values) => [
    for (final value in values)
      GeometryPoint(
        id: const Uuid().v4(),
        label: value.$1,
        position: value.$2,
      ),
  ];

  GeometryShape _polygonShape(
    GeometryShapeType type,
    List<GeometryPoint> points,
  ) => GeometryShape(
    id: const Uuid().v4(),
    type: type,
    pointIds: points.map((point) => point.id).toList(),
  );

  GeometryMark _segmentMark(
    GeometryMarkType type,
    GeometryPoint a,
    GeometryPoint b,
  ) => GeometryMark(
    id: const Uuid().v4(),
    type: type,
    pointIds: [a.id, b.id],
    position: (a.position + b.position) / 2,
  );

  String _shapeTitle(GeometryShapeType type) {
    final words = type.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
