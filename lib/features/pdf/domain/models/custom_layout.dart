enum ElementType {
  schoolName,
  paperTitle,
  logo,
  maxMarks,
  headerFieldsBlock,
  staticText,
  horizontalLine,
  rectangular,
}

class TemplateElement {
  final String id;
  final ElementType type;
  final double x; // X position in points (0 to 595)
  final double y; // Y position in points (0 to 842)
  final double? width;
  final double? height;
  final String content; // For staticText or specific labels
  final Map<String, dynamic> properties;

  TemplateElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.content = '',
    this.properties = const {},
  });

  String get paperBindingKey {
    final contentKey = content.trim().isEmpty ? type.name : content.trim();
    return '${type.name}:${x.toStringAsFixed(1)}:${y.toStringAsFixed(1)}:$contentKey';
  }

  TemplateElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? content,
    Map<String, dynamic>? properties,
  }) {
    return TemplateElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      content: content ?? this.content,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'content': content,
      'properties': properties,
    };
  }

  factory TemplateElement.fromJson(Map<String, dynamic> json) {
    return TemplateElement(
      id: json['id'],
      type: ElementType.values[json['type']],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: json['width']?.toDouble(),
      height: json['height']?.toDouble(),
      content: json['content'] ?? '',
      properties: json['properties'] ?? {},
    );
  }
}

class CustomLayout {
  static const double designWidth = 595.27 - 64;

  final List<TemplateElement> elements;
  final double canvasHeight; // Total height occupied by the custom header

  CustomLayout({required this.elements, this.canvasHeight = 200});

  Map<String, dynamic> toJson() {
    return {
      'elements': elements.map((e) => e.toJson()).toList(),
      'canvasHeight': canvasHeight,
    };
  }

  factory CustomLayout.fromJson(Map<String, dynamic> json) {
    return CustomLayout(
      elements: (json['elements'] as List)
          .map((e) => TemplateElement.fromJson(e))
          .toList(),
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 200,
    );
  }
}
