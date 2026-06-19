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
  final double fontSize;
  final double rotation;
  final bool isBold;

  const GeometryLabel({
    required this.id,
    required this.type,
    required this.text,
    required this.position,
    this.fontSize = 14,
    this.rotation = 0,
    this.isBold = true,
  });

  GeometryLabel copyWith({
    GeometryLabelType? type,
    String? text,
    Offset? position,
    double? fontSize,
    double? rotation,
    bool? isBold,
  }) {
    return GeometryLabel(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      rotation: rotation ?? this.rotation,
      isBold: isBold ?? this.isBold,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    'x': position.dx,
    'y': position.dy,
    'fontSize': fontSize,
    'rotation': rotation,
    'isBold': isBold,
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
      fontSize: ((json['fontSize'] as num?)?.toDouble() ?? 14)
          .clamp(8.0, 42.0)
          .toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isBold: json['isBold'] as bool? ?? true,
    );
  }
}
