import 'dart:ui';

enum GeometryMarkType {
  angleArc,
  rightAngle,
  equalSideTick,
  parallelLine,
  dottedConstructionLine,
  dashedHeightLine,
  radiusLine,
  diameterLine,
  arrowHead,
  doubleArrow,
  curvedArc,
  centerPoint,
}

class GeometryMark {
  final String id;
  final GeometryMarkType type;
  final List<String> pointIds;
  final Offset position;

  const GeometryMark({
    required this.id,
    required this.type,
    this.pointIds = const [],
    this.position = Offset.zero,
  });

  GeometryMark copyWith({
    GeometryMarkType? type,
    List<String>? pointIds,
    Offset? position,
  }) {
    return GeometryMark(
      id: id,
      type: type ?? this.type,
      pointIds: pointIds ?? this.pointIds,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'pointIds': pointIds,
    'x': position.dx,
    'y': position.dy,
  };

  factory GeometryMark.fromJson(Map<String, dynamic> json) {
    return GeometryMark(
      id: json['id'] as String,
      type: GeometryMarkType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => GeometryMarkType.centerPoint,
      ),
      pointIds: (json['pointIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}
