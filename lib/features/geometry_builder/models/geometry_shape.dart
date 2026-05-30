enum GeometryShapeType {
  line,
  arrow,
  triangle,
  rightTriangle,
  square,
  rectangle,
  circle,
  semicircle,
  parallelogram,
  trapezium,
  rhombus,
  pentagon,
  hexagon,
  coordinateAxes,
  numberLine,
  cube,
  cuboid,
  cylinder,
  cone,
  sphere,
  polygon,
}

class GeometryShape {
  final String id;
  final GeometryShapeType type;
  final List<String> pointIds;
  final double radius;

  const GeometryShape({
    required this.id,
    required this.type,
    this.pointIds = const [],
    this.radius = 56,
  });

  GeometryShape copyWith({
    GeometryShapeType? type,
    List<String>? pointIds,
    double? radius,
  }) {
    return GeometryShape(
      id: id,
      type: type ?? this.type,
      pointIds: pointIds ?? this.pointIds,
      radius: radius ?? this.radius,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'pointIds': pointIds,
    'radius': radius,
  };

  factory GeometryShape.fromJson(Map<String, dynamic> json) {
    return GeometryShape(
      id: json['id'] as String,
      type: GeometryShapeType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => GeometryShapeType.polygon,
      ),
      pointIds: (json['pointIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      radius: (json['radius'] as num?)?.toDouble() ?? 56,
    );
  }
}
