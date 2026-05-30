import 'dart:ui';

class GeometryPoint {
  final String id;
  final String label;
  final Offset position;

  const GeometryPoint({
    required this.id,
    required this.label,
    required this.position,
  });

  GeometryPoint copyWith({String? label, Offset? position}) {
    return GeometryPoint(
      id: id,
      label: label ?? this.label,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'x': position.dx,
    'y': position.dy,
  };

  factory GeometryPoint.fromJson(Map<String, dynamic> json) {
    return GeometryPoint(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}
