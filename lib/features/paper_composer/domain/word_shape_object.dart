import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';

/// Canonical Word-Mode drawing/floating object.
///
/// Objects remain persisted inside `Question.metadata` so the existing Paper
/// JSON contract stays the single source of truth. Placement values are
/// normalized to the local authoring surface (0.0-1.0); editor selection,
/// handles and snap guides are transient and are never serialized.
enum WordShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  line,
  arrow,
  doubleArrow,
  textBox,
  callout,
  geometry,
}

enum WordTextWrapMode {
  inline,
  squareLeft,
  squareRight,
  topAndBottom,
  behindText,
  inFrontOfText,
}

enum WordTextBoxSizing { fixed, autoHeight }

/// Controls whether a floating object follows its owning question/block or
/// keeps its page-relative placement intent. The fixed page index is persisted
/// for editor pagination/reflow diagnostics; exporters can also use the mode to
/// choose page-relative positioning where supported.
enum WordObjectAnchorMode { moveWithContent, fixedOnPage }

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

  /// Phase 4 manipulation/style properties. These are document properties,
  /// unlike selection/handles, so preview/export code may honor them.
  final bool locked;
  final bool aspectRatioLocked;
  final bool borderVisible;
  final int strokeColorArgb;
  final double strokeWidth;
  final int fillColorArgb;
  final double fillOpacity;
  final double padding;
  final WordTextBoxSizing textBoxSizing;
  final WordObjectAnchorMode anchorMode;
  final int fixedPageIndex;

  /// Phase 6 floating geometry payload. Legacy Quill geometry embeds remain
  /// fully supported; this field is only populated for true design objects.
  final GeometryDiagram? geometryDiagram;

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
    this.locked = false,
    this.aspectRatioLocked = false,
    this.borderVisible = true,
    this.strokeColorArgb = 0xFF000000,
    this.strokeWidth = 1.6,
    this.fillColorArgb = 0xFFFFFFFF,
    this.fillOpacity = 0,
    this.padding = 6,
    this.textBoxSizing = WordTextBoxSizing.fixed,
    this.anchorMode = WordObjectAnchorMode.moveWithContent,
    this.fixedPageIndex = 0,
    this.geometryDiagram,
  });

  bool get isTextContainer =>
      kind == WordShapeKind.textBox || kind == WordShapeKind.callout;

  bool get isGeometryObject =>
      kind == WordShapeKind.geometry && geometryDiagram != null;

  bool get isFixedOnPage => anchorMode == WordObjectAnchorMode.fixedOnPage;

  bool get exceedsNormalizedBounds =>
      x < 0 || y < 0 || x + width > 1 || y + height > 1;

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
    bool? locked,
    bool? aspectRatioLocked,
    bool? borderVisible,
    int? strokeColorArgb,
    double? strokeWidth,
    int? fillColorArgb,
    double? fillOpacity,
    double? padding,
    WordTextBoxSizing? textBoxSizing,
    WordObjectAnchorMode? anchorMode,
    int? fixedPageIndex,
    GeometryDiagram? geometryDiagram,
    bool clearGeometryDiagram = false,
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
      locked: locked ?? this.locked,
      aspectRatioLocked: aspectRatioLocked ?? this.aspectRatioLocked,
      borderVisible: borderVisible ?? this.borderVisible,
      strokeColorArgb: strokeColorArgb ?? this.strokeColorArgb,
      strokeWidth: _stroke(strokeWidth ?? this.strokeWidth),
      fillColorArgb: fillColorArgb ?? this.fillColorArgb,
      fillOpacity: _opacity(fillOpacity ?? this.fillOpacity),
      padding: _padding(padding ?? this.padding),
      textBoxSizing: textBoxSizing ?? this.textBoxSizing,
      anchorMode: anchorMode ?? this.anchorMode,
      fixedPageIndex: _pageIndex(fixedPageIndex ?? this.fixedPageIndex),
      geometryDiagram: clearGeometryDiagram
          ? null
          : (geometryDiagram ?? this.geometryDiagram),
    );
  }

  Map<String, dynamic> toJson() {
    final diagram = geometryDiagram;
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
      'locked': locked,
      'aspectRatioLocked': aspectRatioLocked,
      'borderVisible': borderVisible,
      'strokeColorArgb': strokeColorArgb,
      'strokeWidth': strokeWidth,
      'fillColorArgb': fillColorArgb,
      'fillOpacity': fillOpacity,
      'padding': padding,
      'textBoxSizing': textBoxSizing.name,
      'anchorMode': anchorMode.name,
      'fixedPageIndex': fixedPageIndex,
      if (diagram != null) 'geometryDiagram': diagram.toJson(),
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
      locked: json['locked'] == true,
      aspectRatioLocked: json['aspectRatioLocked'] == true,
      borderVisible: json['borderVisible'] is bool
          ? json['borderVisible'] as bool
          : true,
      strokeColorArgb:
          (json['strokeColorArgb'] as num?)?.toInt() ?? 0xFF000000,
      strokeWidth: _stroke((json['strokeWidth'] as num?)?.toDouble() ?? 1.6),
      fillColorArgb:
          (json['fillColorArgb'] as num?)?.toInt() ?? 0xFFFFFFFF,
      fillOpacity: _opacity(
        (json['fillOpacity'] as num?)?.toDouble() ?? 0,
      ),
      padding: _padding((json['padding'] as num?)?.toDouble() ?? 6),
      textBoxSizing: _enumByName(
        WordTextBoxSizing.values,
        json['textBoxSizing'],
        WordTextBoxSizing.fixed,
      ),
      anchorMode: _enumByName(
        WordObjectAnchorMode.values,
        json['anchorMode'],
        WordObjectAnchorMode.moveWithContent,
      ),
      fixedPageIndex: _pageIndex((json['fixedPageIndex'] as num?)?.toInt() ?? 0),
      geometryDiagram: _geometryFromJson(json['geometryDiagram']),
    );
  }

  static GeometryDiagram? _geometryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return GeometryDiagram.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
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
  static double _opacity(double value) => value.clamp(0.0, 1.0).toDouble();
  static double _stroke(double value) => value.clamp(0.0, 8.0).toDouble();
  static double _padding(double value) => value.clamp(0.0, 32.0).toDouble();
  static int _pageIndex(int value) => value < 0 ? 0 : value;
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
    WordShapeKind.geometry => 'Geometry',
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

extension WordTextBoxSizingLabel on WordTextBoxSizing {
  String get label => switch (this) {
    WordTextBoxSizing.fixed => 'Fixed size',
    WordTextBoxSizing.autoHeight => 'Auto height',
  };
}

extension WordObjectAnchorModeLabel on WordObjectAnchorMode {
  String get label => switch (this) {
    WordObjectAnchorMode.moveWithContent => 'Move with question',
    WordObjectAnchorMode.fixedOnPage => 'Stay on this page',
  };
}
