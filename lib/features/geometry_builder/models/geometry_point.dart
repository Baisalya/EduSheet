import 'dart:ui';

class GeometryPoint {
  final String id;
  final String label;
  final Offset position;
  final Offset labelOffset;
  final double labelFontSize;
  final double labelRotation;
  final bool labelBold;

  const GeometryPoint({
    required this.id,
    required this.label,
    required this.position,
    this.labelOffset = const Offset(6, -18),
    this.labelFontSize = 12,
    this.labelRotation = 0,
    this.labelBold = true,
  });

  Offset get labelPosition => position + labelOffset;

  GeometryPoint copyWith({
    String? label,
    Offset? position,
    Offset? labelOffset,
    double? labelFontSize,
    double? labelRotation,
    bool? labelBold,
  }) {
    return GeometryPoint(
      id: id,
      label: label ?? this.label,
      position: position ?? this.position,
      labelOffset: labelOffset ?? this.labelOffset,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelRotation: labelRotation ?? this.labelRotation,
      labelBold: labelBold ?? this.labelBold,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'x': position.dx,
    'y': position.dy,
    'labelOffsetX': labelOffset.dx,
    'labelOffsetY': labelOffset.dy,
    'labelFontSize': labelFontSize,
    'labelRotation': labelRotation,
    'labelBold': labelBold,
  };

  factory GeometryPoint.fromJson(Map<String, dynamic> json) {
    return GeometryPoint(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0,
        (json['y'] as num?)?.toDouble() ?? 0,
      ),
      labelOffset: Offset(
        (json['labelOffsetX'] as num?)?.toDouble() ?? 6,
        (json['labelOffsetY'] as num?)?.toDouble() ?? -18,
      ),
      labelFontSize: ((json['labelFontSize'] as num?)?.toDouble() ?? 12)
          .clamp(8.0, 42.0)
          .toDouble(),
      labelRotation: (json['labelRotation'] as num?)?.toDouble() ?? 0,
      labelBold: json['labelBold'] as bool? ?? true,
    );
  }
}
