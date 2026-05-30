import 'dart:ui';

enum GeometryLabelType {
  side,
  angle,
  height,
  width,
  radius,
  diameter,
  area,
  perimeter,
  custom,
}

class GeometryLabel {
  final String id;
  final GeometryLabelType type;
  final String text;
  final Offset position;

  const GeometryLabel({
    required this.id,
    required this.type,
    required this.text,
    required this.position,
  });

  GeometryLabel copyWith({
    GeometryLabelType? type,
    String? text,
    Offset? position,
  }) {
    return GeometryLabel(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    'x': position.dx,
    'y': position.dy,
  };

  factory GeometryLabel.fromJson(Map<String, dynamic> json) {
    return GeometryLabel(
      id: json['id'] as String,
      type: GeometryLabelType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => GeometryLabelType.custom,
      ),
      text: json['text'] as String? ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
    );
  }
}
