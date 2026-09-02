import 'dart:convert';

import '../models/geometry_diagram.dart';

enum GeometryEmbedWrapMode { inline, squareLeft, squareRight, topAndBottom }

extension GeometryEmbedWrapModeLabel on GeometryEmbedWrapMode {
  String get label => switch (this) {
    GeometryEmbedWrapMode.inline => 'Inline block',
    GeometryEmbedWrapMode.squareLeft => 'Square left',
    GeometryEmbedWrapMode.squareRight => 'Square right',
    GeometryEmbedWrapMode.topAndBottom => 'Top & bottom',
  };
}

/// Canonical placement metadata stored inside EduSheet's Quill geometry embed.
///
/// Older papers stored only an id/height/width/alignment tuple. Phase 4C keeps
/// those fields compatible and adds explicit wrapping plus vertical spacing so
/// Word Mode, Preview, PDF and DOCX can resolve the same placement intent.
class GeometryEmbedLayout {
  static const double defaultHeight = 200;
  static const double defaultWidthFactor = 1;
  static const double defaultMargin = 10;

  final String id;
  final GeometryDiagram? diagram;
  final double height;
  final double widthFactor;
  final double alignmentX;
  final double marginTop;
  final double marginBottom;
  final GeometryEmbedWrapMode wrapMode;

  const GeometryEmbedLayout({
    required this.id,
    this.diagram,
    this.height = defaultHeight,
    this.widthFactor = defaultWidthFactor,
    this.alignmentX = 0,
    this.marginTop = defaultMargin,
    this.marginBottom = defaultMargin,
    this.wrapMode = GeometryEmbedWrapMode.topAndBottom,
  });

  factory GeometryEmbedLayout.forDiagram(GeometryDiagram diagram) {
    return GeometryEmbedLayout(id: diagram.id, diagram: diagram);
  }

  factory GeometryEmbedLayout.fromData(Object? data) {
    if (data is Map) {
      return GeometryEmbedLayout.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is String && data.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return GeometryEmbedLayout.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        // Legacy/non-JSON data falls through to the id-only form below.
      }
    }
    return GeometryEmbedLayout(id: data?.toString() ?? '');
  }

  factory GeometryEmbedLayout.fromJson(Map<String, dynamic> json) {
    GeometryDiagram? diagram;
    final diagramJson = json['diagram'];
    if (diagramJson is Map) {
      try {
        diagram = GeometryDiagram.fromJson(
          Map<String, dynamic>.from(diagramJson),
        );
      } catch (_) {
        diagram = null;
      }
    }

    final wrapName = json['wrapMode']?.toString();
    final wrapMode = GeometryEmbedWrapMode.values.firstWhere(
      (value) => value.name == wrapName,
      orElse: () => GeometryEmbedWrapMode.topAndBottom,
    );

    final layout = GeometryEmbedLayout(
      id: json['id']?.toString() ?? diagram?.id ?? '',
      diagram: diagram,
      height: (json['height'] as num?)?.toDouble() ?? defaultHeight,
      widthFactor:
          (json['widthFactor'] as num?)?.toDouble() ?? defaultWidthFactor,
      alignmentX: (json['alignmentX'] as num?)?.toDouble() ?? 0,
      marginTop: (json['marginTop'] as num?)?.toDouble() ?? defaultMargin,
      marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? defaultMargin,
      wrapMode: wrapMode,
    );
    return layout.normalized();
  }

  double get effectiveAlignmentX => switch (wrapMode) {
    GeometryEmbedWrapMode.squareLeft => -1,
    GeometryEmbedWrapMode.squareRight => 1,
    _ => alignmentX,
  };

  GeometryEmbedLayout normalized() {
    return GeometryEmbedLayout(
      id: id,
      diagram: diagram,
      height: height.clamp(90.0, 520.0).toDouble(),
      widthFactor: widthFactor.clamp(0.35, 1.0).toDouble(),
      alignmentX: alignmentX.clamp(-1.0, 1.0).toDouble(),
      marginTop: marginTop.clamp(0.0, 36.0).toDouble(),
      marginBottom: marginBottom.clamp(0.0, 36.0).toDouble(),
      wrapMode: wrapMode,
    );
  }

  GeometryEmbedLayout copyWith({
    String? id,
    GeometryDiagram? diagram,
    double? height,
    double? widthFactor,
    double? alignmentX,
    double? marginTop,
    double? marginBottom,
    GeometryEmbedWrapMode? wrapMode,
  }) {
    return GeometryEmbedLayout(
      id: id ?? this.id,
      diagram: diagram ?? this.diagram,
      height: height ?? this.height,
      widthFactor: widthFactor ?? this.widthFactor,
      alignmentX: alignmentX ?? this.alignmentX,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      wrapMode: wrapMode ?? this.wrapMode,
    ).normalized();
  }

  Map<String, dynamic> toJson({GeometryDiagram? diagramOverride}) {
    final embedded = diagramOverride ?? diagram;
    return {
      'id': id,
      'height': height,
      'widthFactor': widthFactor,
      'alignmentX': alignmentX,
      'marginTop': marginTop,
      'marginBottom': marginBottom,
      'wrapMode': wrapMode.name,
      if (embedded != null) 'diagram': embedded.toJson(),
    };
  }

  String encode({GeometryDiagram? diagramOverride}) =>
      jsonEncode(toJson(diagramOverride: diagramOverride));
}

/// Extracts geometry embeds in canonical document order without depending on
/// the transient in-memory geometry registry.
List<GeometryEmbedLayout> geometryEmbedsFromQuillText(String text) {
  try {
    final decoded = jsonDecode(text.trimLeft());
    if (decoded is! List) return const [];
    final result = <GeometryEmbedLayout>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final operation = Map<String, dynamic>.from(raw);
      final insert = operation['insert'];
      if (insert is! Map || !insert.containsKey('geometry')) continue;
      result.add(GeometryEmbedLayout.fromData(insert['geometry']));
    }
    return result;
  } catch (_) {
    return const [];
  }
}
