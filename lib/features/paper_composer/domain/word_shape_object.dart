/// Canonical Word-Mode drawing object used by Phase 4B.
///
/// The object is intentionally persisted inside `Question.metadata` rather
/// than introducing a parallel document schema. Coordinates are normalized to
/// the local Word object canvas (0.0-1.0), which keeps placement stable across
/// phone/desktop widths and different paper sizes.
enum WordShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  line,
  arrow,
  doubleArrow,
  textBox,
  callout,
}

enum WordTextWrapMode {
  inline,
  squareLeft,
  squareRight,
  topAndBottom,
  behindText,
  inFrontOfText,
}

class WordShapeObject {
  final String id;
  final WordShapeKind kind;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotationDegrees;
  final WordTextWrapMode wrapMode;
  final int zIndex;
  final String text;

  const WordShapeObject({
    required this.id,
    required this.kind,
    this.x = 0.08,
    this.y = 0.08,
    this.width = 0.36,
    this.height = 0.30,
    this.rotationDegrees = 0,
    this.wrapMode = WordTextWrapMode.topAndBottom,
    this.zIndex = 0,
    this.text = '',
  });

  WordShapeObject copyWith({
    String? id,
    WordShapeKind? kind,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    WordTextWrapMode? wrapMode,
    int? zIndex,
    String? text,
  }) {
    return WordShapeObject(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      x: _unit(x ?? this.x),
      y: _unit(y ?? this.y),
      width: _size(width ?? this.width),
      height: _size(height ?? this.height),
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      wrapMode: wrapMode ?? this.wrapMode,
      zIndex: zIndex ?? this.zIndex,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotationDegrees': rotationDegrees,
      'wrapMode': wrapMode.name,
      'zIndex': zIndex,
      'text': text,
    };
  }

  factory WordShapeObject.fromJson(Map<String, dynamic> json) {
    return WordShapeObject(
      id: json['id']?.toString() ?? '',
      kind: _enumByName(
        WordShapeKind.values,
        json['kind'],
        WordShapeKind.rectangle,
      ),
      x: _unit((json['x'] as num?)?.toDouble() ?? 0.08),
      y: _unit((json['y'] as num?)?.toDouble() ?? 0.08),
      width: _size((json['width'] as num?)?.toDouble() ?? 0.36),
      height: _size((json['height'] as num?)?.toDouble() ?? 0.30),
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
      wrapMode: _enumByName(
        WordTextWrapMode.values,
        json['wrapMode'],
        WordTextWrapMode.topAndBottom,
      ),
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
    );
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    Object? raw,
    T fallback,
  ) {
    final name = raw?.toString();
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static double _unit(double value) => value.clamp(0.0, 1.0).toDouble();
  static double _size(double value) => value.clamp(0.08, 1.0).toDouble();
}

extension WordShapeKindLabel on WordShapeKind {
  String get label => switch (this) {
    WordShapeKind.rectangle => 'Rectangle',
    WordShapeKind.roundedRectangle => 'Rounded rectangle',
    WordShapeKind.ellipse => 'Ellipse',
    WordShapeKind.line => 'Line',
    WordShapeKind.arrow => 'Arrow',
    WordShapeKind.doubleArrow => 'Double arrow',
    WordShapeKind.textBox => 'Text box',
    WordShapeKind.callout => 'Callout',
  };
}

extension WordTextWrapModeLabel on WordTextWrapMode {
  String get label => switch (this) {
    WordTextWrapMode.inline => 'Inline',
    WordTextWrapMode.squareLeft => 'Square · left',
    WordTextWrapMode.squareRight => 'Square · right',
    WordTextWrapMode.topAndBottom => 'Top & bottom',
    WordTextWrapMode.behindText => 'Behind text',
    WordTextWrapMode.inFrontOfText => 'In front of text',
  };
}
