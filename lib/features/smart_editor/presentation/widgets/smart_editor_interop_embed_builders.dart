import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class _BoundedInteropPayloadCache<T> {
  _BoundedInteropPayloadCache(this.maxEntries);

  final int maxEntries;
  final LinkedHashMap<String, T> _values = LinkedHashMap<String, T>();

  T resolve(String key, T Function() create) {
    final cached = _values.remove(key);
    if (cached != null) {
      _values[key] = cached;
      return cached;
    }
    final value = create();
    _values[key] = value;
    while (_values.length > maxEntries) {
      _values.remove(_values.keys.first);
    }
    return value;
  }
}

final _interopImagePayloadCache =
    _BoundedInteropPayloadCache<SmartEditorInteropImagePayload>(6);
final _interopShapePayloadCache =
    _BoundedInteropPayloadCache<SmartEditorInteropShapePayload>(12);
final _interopTablePayloadCache =
    _BoundedInteropPayloadCache<SmartEditorInteropTablePayload>(12);

class SmartEditorInteropObjectPlacement {
  const SmartEditorInteropObjectPlacement({
    this.floating = false,
    this.horizontalRelativeFrom,
    this.verticalRelativeFrom,
    this.horizontalOffsetPoints,
    this.verticalOffsetPoints,
    this.horizontalAlignment,
    this.verticalAlignment,
    this.behindText = false,
    this.allowOverlap = true,
    this.wrapStyle,
    this.wrapText,
    this.distanceTopPoints = 0,
    this.distanceBottomPoints = 0,
    this.distanceLeftPoints = 0,
    this.distanceRightPoints = 0,
    this.relativeHeight = 0,
    this.layoutInCell = true,
    this.locked = false,
  });

  final bool floating;
  final String? horizontalRelativeFrom;
  final String? verticalRelativeFrom;
  final double? horizontalOffsetPoints;
  final double? verticalOffsetPoints;
  final String? horizontalAlignment;
  final String? verticalAlignment;
  final bool behindText;
  final bool allowOverlap;
  final String? wrapStyle;
  final String? wrapText;

  /// Logical Smart Editor points (96dpi). Export converts them back to Word pt.
  final double distanceTopPoints;
  final double distanceBottomPoints;
  final double distanceLeftPoints;
  final double distanceRightPoints;

  /// Word DrawingML z-order key. Keep the exact integer instead of normalizing.
  final int relativeHeight;
  final bool layoutInCell;
  final bool locked;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (floating) 'floating': true,
        if (horizontalRelativeFrom != null)
          'horizontalRelativeFrom': horizontalRelativeFrom,
        if (verticalRelativeFrom != null)
          'verticalRelativeFrom': verticalRelativeFrom,
        if (horizontalOffsetPoints != null)
          'horizontalOffsetPoints': horizontalOffsetPoints,
        if (verticalOffsetPoints != null)
          'verticalOffsetPoints': verticalOffsetPoints,
        if (horizontalAlignment != null)
          'horizontalAlignment': horizontalAlignment,
        if (verticalAlignment != null) 'verticalAlignment': verticalAlignment,
        if (behindText) 'behindText': true,
        if (!allowOverlap) 'allowOverlap': false,
        if (wrapStyle != null) 'wrapStyle': wrapStyle,
        if (wrapText != null) 'wrapText': wrapText,
        if (distanceTopPoints != 0) 'distanceTopPoints': distanceTopPoints,
        if (distanceBottomPoints != 0)
          'distanceBottomPoints': distanceBottomPoints,
        if (distanceLeftPoints != 0) 'distanceLeftPoints': distanceLeftPoints,
        if (distanceRightPoints != 0)
          'distanceRightPoints': distanceRightPoints,
        if (relativeHeight != 0) 'relativeHeight': relativeHeight,
        if (!layoutInCell) 'layoutInCell': false,
        if (locked) 'locked': true,
      };

  factory SmartEditorInteropObjectPlacement.fromData(Object? data) {
    if (data is! Map) return const SmartEditorInteropObjectPlacement();
    final map = Map<String, dynamic>.from(data);
    return SmartEditorInteropObjectPlacement(
      floating: map['floating'] == true,
      horizontalRelativeFrom: _nullableString(map['horizontalRelativeFrom']),
      verticalRelativeFrom: _nullableString(map['verticalRelativeFrom']),
      horizontalOffsetPoints: map['horizontalOffsetPoints'] is num
          ? (map['horizontalOffsetPoints'] as num).toDouble()
          : null,
      verticalOffsetPoints: map['verticalOffsetPoints'] is num
          ? (map['verticalOffsetPoints'] as num).toDouble()
          : null,
      horizontalAlignment: _nullableString(map['horizontalAlignment']),
      verticalAlignment: _nullableString(map['verticalAlignment']),
      behindText: map['behindText'] == true,
      allowOverlap: map['allowOverlap'] != false,
      wrapStyle: _nullableString(map['wrapStyle']),
      wrapText: _nullableString(map['wrapText']),
      distanceTopPoints: _double(map['distanceTopPoints'], 0),
      distanceBottomPoints: _double(map['distanceBottomPoints'], 0),
      distanceLeftPoints: _double(map['distanceLeftPoints'], 0),
      distanceRightPoints: _double(map['distanceRightPoints'], 0),
      relativeHeight: map['relativeHeight'] is num
          ? (map['relativeHeight'] as num).toInt()
          : int.tryParse(map['relativeHeight']?.toString() ?? '') ?? 0,
      layoutInCell: map['layoutInCell'] != false,
      locked: map['locked'] == true,
    );
  }
}

class SmartEditorInteropImagePayload {
  const SmartEditorInteropImagePayload({
    required this.bytes,
    this.objectId,
    this.widthPoints = 160,
    this.heightPoints = 120,
    this.altText,
    this.hyperlink,
    this.placement = const SmartEditorInteropObjectPlacement(),
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final Uint8List bytes;
  final String? objectId;
  final double widthPoints;
  final double heightPoints;
  final String? altText;
  final String? hyperlink;
  final SmartEditorInteropObjectPlacement placement;

  /// Normalized Word crop fractions retained from DrawingML/VML.
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;

  bool get hasCrop =>
      cropLeft > 0 || cropTop > 0 || cropRight > 0 || cropBottom > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bytes': base64Encode(bytes),
        if (objectId != null) 'objectId': objectId,
        'widthPoints': widthPoints,
        'heightPoints': heightPoints,
        if (altText != null) 'altText': altText,
        if (hyperlink != null) 'hyperlink': hyperlink,
        if (placement.floating) 'placement': placement.toJson(),
        if (cropLeft != 0) 'cropLeft': cropLeft,
        if (cropTop != 0) 'cropTop': cropTop,
        if (cropRight != 0) 'cropRight': cropRight,
        if (cropBottom != 0) 'cropBottom': cropBottom,
        if (rotationDegrees != 0) 'rotationDegrees': rotationDegrees,
        if (flipHorizontal) 'flipHorizontal': true,
        if (flipVertical) 'flipVertical': true,
      };

  String encode() => jsonEncode(toJson());

  factory SmartEditorInteropImagePayload.fromData(Object? data) {
    if (data is String) {
      return _interopImagePayloadCache.resolve(
        data,
        () => SmartEditorInteropImagePayload._parse(data),
      );
    }
    return SmartEditorInteropImagePayload._parse(data);
  }

  static SmartEditorInteropImagePayload _parse(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid image payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorInteropImagePayload(
        bytes: Uint8List.fromList(base64Decode(map['bytes']?.toString() ?? '')),
        objectId: _nullableString(map['objectId']),
        widthPoints: _double(map['widthPoints'], 160),
        heightPoints: _double(map['heightPoints'], 120),
        altText: _nullableString(map['altText']),
        hyperlink: _nullableString(map['hyperlink']),
        placement: SmartEditorInteropObjectPlacement.fromData(map['placement']),
        cropLeft: _double(map['cropLeft'], 0).clamp(0.0, 0.999).toDouble(),
        cropTop: _double(map['cropTop'], 0).clamp(0.0, 0.999).toDouble(),
        cropRight: _double(map['cropRight'], 0).clamp(0.0, 0.999).toDouble(),
        cropBottom: _double(map['cropBottom'], 0).clamp(0.0, 0.999).toDouble(),
        rotationDegrees: _double(map['rotationDegrees'], 0),
        flipHorizontal: map['flipHorizontal'] == true,
        flipVertical: map['flipVertical'] == true,
      );
    } catch (_) {
      return SmartEditorInteropImagePayload(bytes: Uint8List(0));
    }
  }
}


/// Structured Word shape payload retained by Smart Editor WM5.
///
/// Common geometry is rendered directly. The payload deliberately retains
/// placement/wrap/z-order even when the editor exposes only limited shape edits,
/// so a Word -> EduSheet -> Word cycle does not silently flatten the object.
class SmartEditorInteropShapePayload {
  const SmartEditorInteropShapePayload({
    required this.kind,
    required this.widthPoints,
    required this.heightPoints,
    this.objectId,
    this.text = '',
    this.blocks = const <SmartEditorInteropCellBlock>[],
    this.altText,
    this.fillColorHex,
    this.strokeColorHex,
    this.strokeWidthPoints = 1,
    this.dashStyle,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.placement = const SmartEditorInteropObjectPlacement(),
  });

  final String kind;
  final double widthPoints;
  final double heightPoints;
  final String? objectId;
  final String text;
  final List<SmartEditorInteropCellBlock> blocks;
  final String? altText;
  final String? fillColorHex;
  final String? strokeColorHex;
  final double strokeWidthPoints;
  final String? dashStyle;
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
  final SmartEditorInteropObjectPlacement placement;

  SmartEditorInteropShapePayload copyWith({
    String? kind,
    double? widthPoints,
    double? heightPoints,
    String? objectId,
    String? text,
    List<SmartEditorInteropCellBlock>? blocks,
    String? altText,
    String? fillColorHex,
    String? strokeColorHex,
    double? strokeWidthPoints,
    String? dashStyle,
    double? rotationDegrees,
    bool? flipHorizontal,
    bool? flipVertical,
    SmartEditorInteropObjectPlacement? placement,
  }) {
    return SmartEditorInteropShapePayload(
      kind: kind ?? this.kind,
      widthPoints: widthPoints ?? this.widthPoints,
      heightPoints: heightPoints ?? this.heightPoints,
      objectId: objectId ?? this.objectId,
      text: text ?? this.text,
      blocks: blocks ?? this.blocks,
      altText: altText ?? this.altText,
      fillColorHex: fillColorHex ?? this.fillColorHex,
      strokeColorHex: strokeColorHex ?? this.strokeColorHex,
      strokeWidthPoints: strokeWidthPoints ?? this.strokeWidthPoints,
      dashStyle: dashStyle ?? this.dashStyle,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      placement: placement ?? this.placement,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'widthPoints': widthPoints,
        'heightPoints': heightPoints,
        if (objectId != null) 'objectId': objectId,
        if (text.isNotEmpty) 'text': text,
        if (blocks.isNotEmpty)
          'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
        if (altText != null) 'altText': altText,
        if (fillColorHex != null) 'fillColorHex': fillColorHex,
        if (strokeColorHex != null) 'strokeColorHex': strokeColorHex,
        if (strokeWidthPoints != 1) 'strokeWidthPoints': strokeWidthPoints,
        if (dashStyle != null) 'dashStyle': dashStyle,
        if (rotationDegrees != 0) 'rotationDegrees': rotationDegrees,
        if (flipHorizontal) 'flipHorizontal': true,
        if (flipVertical) 'flipVertical': true,
        if (placement.floating) 'placement': placement.toJson(),
      };

  String encode() => jsonEncode(toJson());

  factory SmartEditorInteropShapePayload.fromData(Object? data) {
    if (data is String) {
      return _interopShapePayloadCache.resolve(
        data,
        () => SmartEditorInteropShapePayload._parse(data),
      );
    }
    return SmartEditorInteropShapePayload._parse(data);
  }

  static SmartEditorInteropShapePayload _parse(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid shape payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorInteropShapePayload(
        kind: _nullableString(map['kind']) ?? 'unknown',
        widthPoints: _double(map['widthPoints'], 160),
        heightPoints: _double(map['heightPoints'], 80),
        objectId: _nullableString(map['objectId']),
        text: map['text']?.toString() ?? '',
        blocks: (map['blocks'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((block) => SmartEditorInteropCellBlock.fromJson(
                  Map<String, dynamic>.from(block),
                ))
            .toList(growable: false),
        altText: _nullableString(map['altText']),
        fillColorHex: _nullableString(map['fillColorHex']),
        strokeColorHex: _nullableString(map['strokeColorHex']),
        strokeWidthPoints: _double(map['strokeWidthPoints'], 1),
        dashStyle: _nullableString(map['dashStyle']),
        rotationDegrees: _double(map['rotationDegrees'], 0),
        flipHorizontal: map['flipHorizontal'] == true,
        flipVertical: map['flipVertical'] == true,
        placement: SmartEditorInteropObjectPlacement.fromData(map['placement']),
      );
    } catch (_) {
      return const SmartEditorInteropShapePayload(
        kind: 'unknown',
        widthPoints: 160,
        heightPoints: 80,
      );
    }
  }
}

/// Rich Word-table payload used by Smart Editor compatibility mode.
///
/// `text` remains for backward compatibility with W5 table embeds. New imports
/// also persist typed cell blocks so images, run formatting, paragraph
/// alignment and nested tables are not flattened into a lossy `[image]` string.
class SmartEditorInteropTablePayload {
  const SmartEditorInteropTablePayload({
    required this.rows,
    this.showBorders = true,
    this.styleId,
    this.shadingHex,
    this.borders = const <String, dynamic>{},
    this.layout = 'autoFit',
    this.objectId,
    this.sourceKind = 'table',
    this.widthPoints,
    this.heightPoints,
    this.widthPercent,
    this.indentPoints = 0,
    this.cellSpacingPoints = 0,
    this.gridColumnWidths = const <double>[],
    this.alignment = 'left',
    this.placement = const SmartEditorInteropObjectPlacement(),
  });

  final List<SmartEditorInteropTableRow> rows;
  final bool showBorders;
  final String? styleId;
  final String? shadingHex;
  final Map<String, dynamic> borders;
  final String layout;
  final String? objectId;
  final String sourceKind;
  final double? widthPoints;
  final double? heightPoints;
  final double? widthPercent;
  final double indentPoints;
  final double cellSpacingPoints;
  final List<double> gridColumnWidths;
  final String alignment;
  final SmartEditorInteropObjectPlacement placement;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'showBorders': showBorders,
        if (styleId != null) 'styleId': styleId,
        if (shadingHex != null) 'shadingHex': shadingHex,
        if (borders.isNotEmpty) 'borders': borders,
        if (layout != 'autoFit') 'layout': layout,
        if (objectId != null) 'objectId': objectId,
        if (sourceKind != 'table') 'sourceKind': sourceKind,
        if (widthPoints != null) 'widthPoints': widthPoints,
        if (heightPoints != null) 'heightPoints': heightPoints,
        if (widthPercent != null) 'widthPercent': widthPercent,
        if (indentPoints != 0) 'indentPoints': indentPoints,
        if (cellSpacingPoints != 0) 'cellSpacingPoints': cellSpacingPoints,
        if (gridColumnWidths.isNotEmpty)
          'gridColumnWidths': gridColumnWidths,
        'alignment': alignment,
        if (placement.floating) 'placement': placement.toJson(),
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  factory SmartEditorInteropTablePayload.fromData(Object? data) {
    if (data is String) {
      return _interopTablePayloadCache.resolve(
        data,
        () => SmartEditorInteropTablePayload._parse(data),
      );
    }
    return SmartEditorInteropTablePayload._parse(data);
  }

  static SmartEditorInteropTablePayload _parse(Object? data) {
    try {
      final raw = data is String ? jsonDecode(data) : data;
      if (raw is! Map) throw const FormatException('Invalid table payload');
      final map = Map<String, dynamic>.from(raw);
      return SmartEditorInteropTablePayload(
        showBorders: map['showBorders'] != false,
        styleId: _nullableString(map['styleId']),
        shadingHex: _nullableString(map['shadingHex']),
        borders: map['borders'] is Map
            ? Map<String, dynamic>.from(map['borders'] as Map)
            : const <String, dynamic>{},
        layout: _nullableString(map['layout']) ?? 'autoFit',
        objectId: _nullableString(map['objectId']),
        sourceKind: _nullableString(map['sourceKind']) ?? 'table',
        widthPoints: map['widthPoints'] is num
            ? (map['widthPoints'] as num).toDouble()
            : null,
        heightPoints: map['heightPoints'] is num
            ? (map['heightPoints'] as num).toDouble()
            : null,
        widthPercent: map['widthPercent'] is num
            ? (map['widthPercent'] as num).toDouble()
            : null,
        indentPoints: _double(map['indentPoints'], 0),
        cellSpacingPoints: _double(map['cellSpacingPoints'], 0),
        gridColumnWidths: (map['gridColumnWidths'] as List<dynamic>? ??
                const <dynamic>[])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false),
        alignment: _nullableString(map['alignment']) ?? 'left',
        placement: SmartEditorInteropObjectPlacement.fromData(map['placement']),
        rows: (map['rows'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((row) => SmartEditorInteropTableRow.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(growable: false),
      );
    } catch (_) {
      return const SmartEditorInteropTablePayload(
        rows: <SmartEditorInteropTableRow>[],
      );
    }
  }
}

class SmartEditorInteropTableRow {
  const SmartEditorInteropTableRow({
    required this.cells,
    this.header = false,
    this.cantSplit = false,
    this.heightPoints,
    this.heightRule = 'auto',
  });

  final List<SmartEditorInteropTableCell> cells;
  final bool header;
  final bool cantSplit;
  final double? heightPoints;
  final String heightRule;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'header': header,
        if (cantSplit) 'cantSplit': true,
        if (heightPoints != null) 'heightPoints': heightPoints,
        if (heightRule != 'auto') 'heightRule': heightRule,
        'cells': cells.map((cell) => cell.toJson()).toList(growable: false),
      };

  factory SmartEditorInteropTableRow.fromJson(Map<String, dynamic> json) {
    return SmartEditorInteropTableRow(
      header: json['header'] == true,
      cantSplit: json['cantSplit'] == true,
      heightPoints: json['heightPoints'] is num
          ? (json['heightPoints'] as num).toDouble()
          : null,
      heightRule: _nullableString(json['heightRule']) ?? 'auto',
      cells: (json['cells'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((cell) => SmartEditorInteropTableCell.fromJson(
                Map<String, dynamic>.from(cell),
              ))
          .toList(growable: false),
    );
  }
}

class SmartEditorInteropTableCell {
  const SmartEditorInteropTableCell({
    required this.text,
    this.shadingHex,
    this.borders = const <String, dynamic>{},
    this.widthPoints,
    this.widthPercent,
    this.gridSpan = 1,
    this.paddingTopPoints = 7,
    this.paddingRightPoints = 7,
    this.paddingBottomPoints = 6,
    this.paddingLeftPoints = 7,
    this.verticalAlignment = 'top',
    this.verticalMerge = 'none',
    this.noWrap = false,
    this.blocks = const <SmartEditorInteropCellBlock>[],
  });

  final String text;
  final String? shadingHex;
  final Map<String, dynamic> borders;
  final double? widthPoints;
  final double? widthPercent;
  final int gridSpan;
  final double paddingTopPoints;
  final double paddingRightPoints;
  final double paddingBottomPoints;
  final double paddingLeftPoints;
  final String verticalAlignment;
  final String verticalMerge;
  final bool noWrap;
  final List<SmartEditorInteropCellBlock> blocks;

  bool get hasRichContent => blocks.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        if (shadingHex != null) 'shadingHex': shadingHex,
        if (borders.isNotEmpty) 'borders': borders,
        if (widthPoints != null) 'widthPoints': widthPoints,
        if (widthPercent != null) 'widthPercent': widthPercent,
        if (gridSpan != 1) 'gridSpan': gridSpan,
        if (paddingTopPoints != 7) 'paddingTopPoints': paddingTopPoints,
        if (paddingRightPoints != 7) 'paddingRightPoints': paddingRightPoints,
        if (paddingBottomPoints != 6) 'paddingBottomPoints': paddingBottomPoints,
        if (paddingLeftPoints != 7) 'paddingLeftPoints': paddingLeftPoints,
        if (verticalAlignment != 'top') 'verticalAlignment': verticalAlignment,
        if (verticalMerge != 'none') 'verticalMerge': verticalMerge,
        if (noWrap) 'noWrap': true,
        if (blocks.isNotEmpty)
          'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
      };

  factory SmartEditorInteropTableCell.fromJson(Map<String, dynamic> json) {
    return SmartEditorInteropTableCell(
      text: json['text']?.toString() ?? '',
      shadingHex: _nullableString(json['shadingHex']),
      borders: json['borders'] is Map
          ? Map<String, dynamic>.from(json['borders'] as Map)
          : const <String, dynamic>{},
      widthPoints: json['widthPoints'] is num
          ? (json['widthPoints'] as num).toDouble()
          : null,
      widthPercent: json['widthPercent'] is num
          ? (json['widthPercent'] as num).toDouble()
          : null,
      gridSpan: (json['gridSpan'] is num
              ? (json['gridSpan'] as num).toInt()
              : int.tryParse(json['gridSpan']?.toString() ?? ''))
          ?.clamp(1, 64)
          .toInt() ??
          1,
      paddingTopPoints: _double(json['paddingTopPoints'], 7),
      paddingRightPoints: _double(json['paddingRightPoints'], 7),
      paddingBottomPoints: _double(json['paddingBottomPoints'], 6),
      paddingLeftPoints: _double(json['paddingLeftPoints'], 7),
      verticalAlignment: _nullableString(json['verticalAlignment']) ?? 'top',
      verticalMerge: _nullableString(json['verticalMerge']) ?? 'none',
      noWrap: json['noWrap'] == true,
      blocks: (json['blocks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((block) => SmartEditorInteropCellBlock.fromJson(
                Map<String, dynamic>.from(block),
              ))
          .toList(growable: false),
    );
  }
}

class SmartEditorInteropCellBlock {
  const SmartEditorInteropCellBlock.paragraph({
    required this.runs,
    this.alignment = 'left',
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 0,
    this.lineSpacingMultiple,
    this.exactLineSpacingPoints,
  })  : kind = 'paragraph',
        image = null,
        table = null,
        shape = null,
        rawOoxml = null,
        featureKind = null,
        fallbackText = '',
        relationshipIds = const <String>[];

  const SmartEditorInteropCellBlock.image(this.image)
      : kind = 'image',
        runs = const <SmartEditorInteropTextRun>[],
        alignment = 'left',
        spaceBeforePoints = 0,
        spaceAfterPoints = 0,
        lineSpacingMultiple = null,
        exactLineSpacingPoints = null,
        table = null,
        shape = null,
        rawOoxml = null,
        featureKind = null,
        fallbackText = '',
        relationshipIds = const <String>[];

  const SmartEditorInteropCellBlock.table(this.table)
      : kind = 'table',
        runs = const <SmartEditorInteropTextRun>[],
        alignment = 'left',
        spaceBeforePoints = 0,
        spaceAfterPoints = 0,
        lineSpacingMultiple = null,
        exactLineSpacingPoints = null,
        image = null,
        shape = null,
        rawOoxml = null,
        featureKind = null,
        fallbackText = '',
        relationshipIds = const <String>[];

  const SmartEditorInteropCellBlock.shape(this.shape)
      : kind = 'shape',
        runs = const <SmartEditorInteropTextRun>[],
        alignment = 'left',
        spaceBeforePoints = 0,
        spaceAfterPoints = 0,
        lineSpacingMultiple = null,
        exactLineSpacingPoints = null,
        image = null,
        table = null,
        rawOoxml = null,
        featureKind = null,
        fallbackText = '',
        relationshipIds = const <String>[];


  const SmartEditorInteropCellBlock.opaqueOoxml({
    required this.rawOoxml,
    required this.featureKind,
    this.fallbackText = '',
    this.relationshipIds = const <String>[],
  })  : kind = 'opaqueOoxml',
        runs = const <SmartEditorInteropTextRun>[],
        alignment = 'left',
        spaceBeforePoints = 0,
        spaceAfterPoints = 0,
        lineSpacingMultiple = null,
        exactLineSpacingPoints = null,
        image = null,
        table = null,
        shape = null;

  final String kind;
  final List<SmartEditorInteropTextRun> runs;
  final String alignment;
  final double spaceBeforePoints;
  final double spaceAfterPoints;
  final double? lineSpacingMultiple;
  final double? exactLineSpacingPoints;
  final SmartEditorInteropImagePayload? image;
  final SmartEditorInteropTablePayload? table;
  final SmartEditorInteropShapePayload? shape;
  final String? rawOoxml;
  final String? featureKind;
  final String fallbackText;
  final List<String> relationshipIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        if (runs.isNotEmpty)
          'runs': runs.map((run) => run.toJson()).toList(growable: false),
        if (kind == 'paragraph') 'alignment': alignment,
        if (spaceBeforePoints != 0) 'spaceBeforePoints': spaceBeforePoints,
        if (spaceAfterPoints != 0) 'spaceAfterPoints': spaceAfterPoints,
        if (lineSpacingMultiple != null)
          'lineSpacingMultiple': lineSpacingMultiple,
        if (exactLineSpacingPoints != null)
          'exactLineSpacingPoints': exactLineSpacingPoints,
        if (image != null) 'image': image!.toJson(),
        if (table != null) 'table': table!.toJson(),
        if (shape != null) 'shape': shape!.toJson(),
        if (rawOoxml != null) 'rawOoxml': rawOoxml,
        if (featureKind != null) 'featureKind': featureKind,
        if (fallbackText.isNotEmpty) 'fallbackText': fallbackText,
        if (relationshipIds.isNotEmpty) 'relationshipIds': relationshipIds,
      };

  factory SmartEditorInteropCellBlock.fromJson(Map<String, dynamic> json) {
    switch (json['kind']?.toString()) {
      case 'image':
        return SmartEditorInteropCellBlock.image(
          SmartEditorInteropImagePayload.fromData(json['image']),
        );
      case 'table':
        return SmartEditorInteropCellBlock.table(
          SmartEditorInteropTablePayload.fromData(json['table']),
        );
      case 'shape':
        return SmartEditorInteropCellBlock.shape(
          SmartEditorInteropShapePayload.fromData(json['shape']),
        );
      case 'opaqueOoxml':
        return SmartEditorInteropCellBlock.opaqueOoxml(
          rawOoxml: json['rawOoxml']?.toString(),
          featureKind: json['featureKind']?.toString() ?? 'unknownOoxml',
          fallbackText: json['fallbackText']?.toString() ?? '',
          relationshipIds: (json['relationshipIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false),
        );
      default:
        return SmartEditorInteropCellBlock.paragraph(
          runs: (json['runs'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((run) => SmartEditorInteropTextRun.fromJson(
                    Map<String, dynamic>.from(run),
                  ))
              .toList(growable: false),
          alignment: _nullableString(json['alignment']) ?? 'left',
          spaceBeforePoints: _double(json['spaceBeforePoints'], 0),
          spaceAfterPoints: _double(json['spaceAfterPoints'], 0),
          lineSpacingMultiple: json['lineSpacingMultiple'] is num
              ? (json['lineSpacingMultiple'] as num).toDouble()
              : null,
          exactLineSpacingPoints: json['exactLineSpacingPoints'] is num
              ? (json['exactLineSpacingPoints'] as num).toDouble()
              : null,
        );
    }
  }
}

class SmartEditorInteropTextRun {
  const SmartEditorInteropTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.underlineStyle = 'single',
    this.strike = false,
    this.doubleStrike = false,
    this.allCaps = false,
    this.smallCaps = false,
    this.letterSpacingPoints = 0,
    this.fontFamily,
    this.fontSizePoints,
    this.colorHex,
    this.backgroundHex,
    this.hyperlink,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String underlineStyle;
  final bool strike;
  final bool doubleStrike;
  final bool allCaps;
  final bool smallCaps;
  final double letterSpacingPoints;
  final String? fontFamily;
  final double? fontSizePoints;
  final String? colorHex;
  final String? backgroundHex;
  final String? hyperlink;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        if (bold) 'bold': true,
        if (italic) 'italic': true,
        if (underline) 'underline': true,
        if (underline && underlineStyle != 'single')
          'underlineStyle': underlineStyle,
        if (strike) 'strike': true,
        if (doubleStrike) 'doubleStrike': true,
        if (allCaps) 'allCaps': true,
        if (smallCaps) 'smallCaps': true,
        if (letterSpacingPoints != 0)
          'letterSpacingPoints': letterSpacingPoints,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontSizePoints != null) 'fontSizePoints': fontSizePoints,
        if (colorHex != null) 'colorHex': colorHex,
        if (backgroundHex != null) 'backgroundHex': backgroundHex,
        if (hyperlink != null) 'hyperlink': hyperlink,
      };

  factory SmartEditorInteropTextRun.fromJson(Map<String, dynamic> json) {
    return SmartEditorInteropTextRun(
      text: json['text']?.toString() ?? '',
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      underlineStyle:
          _nullableString(json['underlineStyle']) ?? 'single',
      strike: json['strike'] == true,
      doubleStrike: json['doubleStrike'] == true,
      allCaps: json['allCaps'] == true,
      smallCaps: json['smallCaps'] == true,
      letterSpacingPoints: _double(json['letterSpacingPoints'], 0),
      fontFamily: _nullableString(json['fontFamily']),
      fontSizePoints: json['fontSizePoints'] is num
          ? (json['fontSizePoints'] as num).toDouble()
          : null,
      colorHex: _nullableString(json['colorHex']),
      backgroundHex: _nullableString(json['backgroundHex']),
      hyperlink: _nullableString(json['hyperlink']),
    );
  }
}

typedef SmartEditorInteropImageEditCallback = Future<void> Function(
  BuildContext context,
  SmartEditorInteropImagePayload payload,
);

typedef SmartEditorInteropTableEditCallback = Future<void> Function(
  BuildContext context,
  SmartEditorInteropTablePayload payload,
);

typedef SmartEditorInteropShapeEditCallback = Future<void> Function(
  BuildContext context,
  SmartEditorInteropShapePayload payload,
);

class SmartEditorInteropShapeEmbedBuilder extends EmbedBuilder {
  const SmartEditorInteropShapeEmbedBuilder({this.onEdit});

  static const keyName = 'smartDocxShape';
  final SmartEditorInteropShapeEditCallback? onEdit;

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropShapePayload.fromData(
      embedContext.node.value.data,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final sourceWidth = math.max(1.0, payload.widthPoints);
        final sourceHeight = math.max(1.0, payload.heightPoints);
        final availableWidth = math.max(1.0, maxWidth);
        final minimumWidth = math.min(36.0, availableWidth);
        final width =
            sourceWidth.clamp(minimumWidth, availableWidth).toDouble();
        final height = (sourceHeight * width / sourceWidth)
            .clamp(18.0, 640.0)
            .toDouble();
        Widget shape = CustomPaint(
          key: ValueKey('smart-docx-shape-${payload.objectId ?? payload.kind}'),
          painter: _SmartEditorWordShapePainter(payload),
          child: SizedBox(
            width: width,
            height: height,
            child: payload.text.trim().isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      child: Text(
                        payload.text,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
          ),
        );
        if (payload.flipHorizontal || payload.flipVertical) {
          shape = Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              payload.flipHorizontal ? -1.0 : 1.0,
              payload.flipVertical ? -1.0 : 1.0,
              1,
            ),
            child: shape,
          );
        }
        if (payload.rotationDegrees != 0) {
          shape = Transform.rotate(
            angle: payload.rotationDegrees * math.pi / 180,
            alignment: Alignment.center,
            child: shape,
          );
        }
        Widget result = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(alignment: Alignment.centerLeft, child: shape),
        );
        if (!embedContext.readOnly && onEdit != null) {
          result = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onEdit!(context, payload),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(message: 'Edit Word shape', child: result),
            ),
          );
        }
        return result;
      },
    );
  }
}

class _SmartEditorWordShapePainter extends CustomPainter {
  const _SmartEditorWordShapePainter(this.payload);

  final SmartEditorInteropShapePayload payload;

  @override
  void paint(Canvas canvas, Size size) {
    Color? parseColor(String? raw) {
      if (raw == null) return null;
      final clean = raw.replaceAll('#', '').trim();
      if (clean.length != 6 && clean.length != 8) return null;
      final value = int.tryParse(clean, radix: 16);
      if (value == null) return null;
      return Color(clean.length == 6 ? 0xFF000000 | value : value);
    }

    final fill = parseColor(payload.fillColorHex);
    final stroke = parseColor(payload.strokeColorHex) ?? Colors.black87;
    final strokeWidth = math.max(0.5, payload.strokeWidthPoints);
    final fillPaint = fill == null
        ? null
        : (Paint()
          ..color = fill
          ..style = PaintingStyle.fill);
    final strokePaint = Paint()
      ..color = stroke
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    switch (payload.kind) {
      case 'ellipse':
        if (fillPaint != null) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
        break;
      case 'roundedRectangle':
        final rounded = RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(size.width, size.height) * 0.12),
        );
        if (fillPaint != null) canvas.drawRRect(rounded, fillPaint);
        canvas.drawRRect(rounded, strokePaint);
        break;
      case 'line':
        canvas.drawLine(rect.topLeft, rect.bottomRight, strokePaint);
        break;
      case 'textPath':
        break;
      default:
        if (fillPaint != null) canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SmartEditorWordShapePainter oldDelegate) =>
      oldDelegate.payload != payload;
}

class SmartEditorInteropImageEmbedBuilder extends EmbedBuilder {
  SmartEditorInteropImageEmbedBuilder({this.onEdit});

  static const keyName = 'smartDocxImage';
  final SmartEditorInteropImageEditCallback? onEdit;

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropImagePayload.fromData(
      embedContext.node.value.data,
    );
    if (payload.bytes.isEmpty) {
      return const _InteropPlaceholder(
        icon: Icons.broken_image_outlined,
        label: 'Image unavailable',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final width = payload.widthPoints.clamp(48.0, maxWidth).toDouble();
        final sourceHeight =
            payload.heightPoints <= 0 ? 120.0 : payload.heightPoints;
        final sourceWidth =
            payload.widthPoints <= 0 ? 160.0 : payload.widthPoints;
        final height = (sourceHeight * (width / sourceWidth))
            .clamp(36.0, 640.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: _interopWordImage(
                    payload,
                    width: width,
                    height: height,
                    error: const _InteropPlaceholder(
                      icon: Icons.broken_image_outlined,
                      label: 'Unsupported Word image',
                    ),
                  ),
                ),
                if (onEdit != null && payload.objectId != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        key: ValueKey(
                          'smart-docx-edit-image-${payload.objectId}',
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Resize imported Word image',
                        onPressed: () => onEdit!(context, payload),
                        icon: const Icon(Icons.open_with_rounded, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _interopWordImage(
  SmartEditorInteropImagePayload payload, {
  required double width,
  required double height,
  required Widget error,
}) {
  final cropLeft = payload.cropLeft.clamp(0.0, 0.999).toDouble();
  final cropTop = payload.cropTop.clamp(0.0, 0.999).toDouble();
  final cropRight = payload.cropRight.clamp(0.0, 0.999).toDouble();
  final cropBottom = payload.cropBottom.clamp(0.0, 0.999).toDouble();
  final visibleWidth = (1 - cropLeft - cropRight).clamp(0.001, 1.0).toDouble();
  final visibleHeight = (1 - cropTop - cropBottom).clamp(0.001, 1.0).toDouble();

  Widget image;
  if (!payload.hasCrop) {
    image = Image.memory(
      payload.bytes,
      width: width,
      height: height,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => error,
    );
  } else {
    final expandedWidth = width / visibleWidth;
    final expandedHeight = height / visibleHeight;
    image = ClipRect(
      key: const ValueKey('smart-docx-image-crop-clip'),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -cropLeft * expandedWidth,
              top: -cropTop * expandedHeight,
              width: expandedWidth,
              height: expandedHeight,
              child: Image.memory(
                payload.bytes,
                width: expandedWidth,
                height: expandedHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (payload.flipHorizontal || payload.flipVertical) {
    image = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        payload.flipHorizontal ? -1.0 : 1.0,
        payload.flipVertical ? -1.0 : 1.0,
        1,
      ),
      child: image,
    );
  }
  if (payload.rotationDegrees != 0) {
    image = Transform.rotate(
      angle: payload.rotationDegrees * math.pi / 180,
      alignment: Alignment.center,
      child: image,
    );
  }
  return SizedBox(width: width, height: height, child: image);
}

class SmartEditorInteropTableEmbedBuilder extends EmbedBuilder {
  SmartEditorInteropTableEmbedBuilder({this.onEdit});

  static const keyName = 'smartDocxTable';
  final SmartEditorInteropTableEditCallback? onEdit;

  @override
  String get key => keyName;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = SmartEditorInteropTablePayload.fromData(
      embedContext.node.value.data,
    );
    if (payload.rows.isEmpty) {
      return const _InteropPlaceholder(
        icon: Icons.table_chart_outlined,
        label: 'Empty Word table',
      );
    }
    return _InteropTable(payload: payload, onEdit: onEdit);
  }
}

class SmartEditorInteropTableViewportMetrics {
  const SmartEditorInteropTableViewportMetrics({
    required this.contentWidth,
    required this.horizontalScroll,
  });

  final double contentWidth;
  final bool horizontalScroll;
}

/// Responsive policy for Word-origin tables embedded in the Smart Editor.
///
/// Fixed-width Word tables keep their geometry on narrow phones by becoming
/// horizontally scrollable instead of crushing every column. Percentage-width
/// tables remain fluid because their Word intent is already viewport-relative.
class SmartEditorInteropTableViewportPolicy {
  static const double compactWidth = 560;
  static const double maxPreservedWidth = 1200;

  static SmartEditorInteropTableViewportMetrics resolve(
    SmartEditorInteropTablePayload payload,
    double availableWidth,
  ) {
    final available = availableWidth.isFinite
        ? availableWidth.clamp(120.0, double.infinity).toDouble()
        : 600.0;
    final percentWidth = payload.widthPercent == null
        ? null
        : available * (payload.widthPercent!.clamp(1.0, 100.0) / 100);
    final gridWidth = payload.gridColumnWidths.isEmpty
        ? null
        : payload.gridColumnWidths.fold<double>(0, (sum, value) => sum + value);
    final requested = payload.widthPoints ?? percentWidth ?? gridWidth ?? available;
    final preserveFixedGeometry = payload.widthPercent == null &&
        available < compactWidth &&
        requested > available + 12;
    final contentWidth = preserveFixedGeometry
        ? requested.clamp(available, maxPreservedWidth).toDouble()
        : requested.clamp(120.0, available).toDouble();
    return SmartEditorInteropTableViewportMetrics(
      contentWidth: contentWidth,
      horizontalScroll: preserveFixedGeometry,
    );
  }
}

class _InteropTable extends StatelessWidget {
  const _InteropTable({required this.payload, this.onEdit});

  final SmartEditorInteropTablePayload payload;
  final SmartEditorInteropTableEditCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = _InteropStructuredGrid(
      payload: payload,
      borderColor: theme.colorScheme.outlineVariant,
      headerColor: theme.colorScheme.surfaceContainerHighest,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        payload.indentPoints.clamp(0.0, 160.0).toDouble(),
        8,
        0,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null && payload.objectId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('smart-docx-edit-table-${payload.objectId}'),
                onPressed: () => onEdit!(context, payload),
                icon: Icon(
                  payload.sourceKind == 'textBox'
                      ? Icons.text_fields_rounded
                      : Icons.edit_note_rounded,
                  size: 17,
                ),
                label: Text(
                  payload.sourceKind == 'textBox'
                      ? 'Edit Word text box'
                      : 'Edit Word table',
                ),
              ),
            ),
          Align(
            alignment: switch (payload.alignment) {
              'center' => Alignment.center,
              'right' => Alignment.centerRight,
              _ => Alignment.centerLeft,
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final metrics = SmartEditorInteropTableViewportPolicy.resolve(
                  payload,
                  available,
                );
                final content = SizedBox(
                  width: metrics.contentWidth,
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _hexColor(payload.shadingHex) ?? theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(
                          payload.cellSpacingPoints
                              .clamp(0.0, 18.0)
                              .toDouble(),
                        ),
                        child: payload.heightPoints == null
                            ? table
                            : ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: payload.heightPoints!
                                      .clamp(24.0, 900.0)
                                      .toDouble(),
                                ),
                                child: table,
                              ),
                      ),
                    ),
                  ),
                );
                if (!metrics.horizontalScroll) return content;
                return SingleChildScrollView(
                  key: const ValueKey('smart-docx-table-horizontal-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InteropStructuredGrid extends StatelessWidget {
  const _InteropStructuredGrid({
    required this.payload,
    required this.borderColor,
    required this.headerColor,
  });

  final SmartEditorInteropTablePayload payload;
  final Color borderColor;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in payload.rows)
          RepaintBoundary(
            child: _InteropStructuredRow(
              row: row,
              gridColumnWidths: payload.gridColumnWidths,
              showBorders: payload.showBorders,
              borderColor: borderColor,
              headerColor: headerColor,
            ),
          ),
      ],
    );
  }
}

class _InteropStructuredRow extends StatelessWidget {
  const _InteropStructuredRow({
    required this.row,
    required this.gridColumnWidths,
    required this.showBorders,
    required this.borderColor,
    required this.headerColor,
  });

  final SmartEditorInteropTableRow row;
  final List<double> gridColumnWidths;
  final bool showBorders;
  final Color borderColor;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    var gridIndex = 0;
    for (final cell in row.cells) {
      final flex = _cellFlex(cell, gridIndex, gridColumnWidths);
      gridIndex += cell.gridSpan;
      final background = _hexColor(cell.shadingHex) ??
          (row.header ? headerColor : Colors.transparent);
      Widget content = Align(
        alignment: switch (cell.verticalAlignment) {
          'center' => Alignment.centerLeft,
          'bottom' => Alignment.bottomLeft,
          _ => Alignment.topLeft,
        },
        child: cell.verticalMerge == 'continuation'
            ? const SizedBox.shrink()
            : cell.hasRichContent
                ? _RichCellContent(cell: cell, header: row.header)
                : Text(
                    cell.text,
                    softWrap: !cell.noWrap,
                    overflow: cell.noWrap ? TextOverflow.visible : TextOverflow.clip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: row.header ? FontWeight.w700 : null,
                        ),
                  ),
      );
      content = Container(
        padding: EdgeInsets.fromLTRB(
          cell.paddingLeftPoints,
          cell.paddingTopPoints,
          cell.paddingRightPoints,
          cell.paddingBottomPoints,
        ),
        color: background,
        child: content,
      );
      if (cell.borders.isNotEmpty || showBorders) {
        content = CustomPaint(
          key: const ValueKey('smart-docx-word-cell-border'),
          foregroundPainter: _InteropWordBorderPainter(
            cell.borders,
            fallbackColor: borderColor,
            fallbackAll: showBorders && cell.borders.isEmpty,
          ),
          child: content,
        );
      }
      if (row.heightRule == 'exact' && row.heightPoints != null) {
        content = SizedBox(height: row.heightPoints, child: content);
      } else if (row.heightRule == 'atLeast' && row.heightPoints != null) {
        content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: row.heightPoints!),
          child: content,
        );
      }
      cells.add(Expanded(flex: flex, child: content));
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }

  int _cellFlex(
    SmartEditorInteropTableCell cell,
    int start,
    List<double> grid,
  ) {
    if (grid.isEmpty || start >= grid.length) {
      final explicit = cell.widthPoints ?? cell.widthPercent;
      if (explicit != null && explicit > 0) {
        return (explicit * 10).round().clamp(1, 1000000).toInt();
      }
      return cell.gridSpan * 1000;
    }
    final end = (start + cell.gridSpan).clamp(0, grid.length).toInt();
    if (end <= start) return cell.gridSpan * 1000;
    final width = grid
        .sublist(start, end)
        .fold<double>(0, (sum, value) => sum + value);
    return (width * 10).round().clamp(1, 1000000).toInt();
  }
}

class _InteropWordBorderPainter extends CustomPainter {
  const _InteropWordBorderPainter(
    this.borders, {
    required this.fallbackColor,
    required this.fallbackAll,
  });

  final Map<String, dynamic> borders;
  final Color fallbackColor;
  final bool fallbackAll;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSide(canvas, 'top', Offset.zero, Offset(size.width, 0));
    _paintSide(
      canvas,
      'bottom',
      Offset(0, size.height),
      Offset(size.width, size.height),
    );
    _paintSide(canvas, 'left', Offset.zero, Offset(0, size.height));
    _paintSide(
      canvas,
      'right',
      Offset(size.width, 0),
      Offset(size.width, size.height),
    );
  }

  void _paintSide(Canvas canvas, String key, Offset start, Offset end) {
    final raw = borders[key];
    if (raw is! Map) {
      if (!fallbackAll) return;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = fallbackColor
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
      return;
    }

    final side = Map<String, dynamic>.from(raw);
    final style = side['style']?.toString() ?? 'single';
    final width = side['widthPoints'] is num
        ? (side['widthPoints'] as num).toDouble()
        : 0.8;
    if (width <= 0 || style == 'none') return;

    final paint = Paint()
      ..color = _hexColor(side['colorHex']?.toString()) ?? fallbackColor
      ..strokeWidth = width.clamp(0.5, 12.0).toDouble()
      ..style = PaintingStyle.stroke;

    if (style == 'double') {
      final horizontal = start.dy == end.dy;
      final delta = math.max(1.0, paint.strokeWidth * 0.9);
      final shift = horizontal ? Offset(0, delta) : Offset(delta, 0);
      paint.strokeWidth = math.max(0.5, paint.strokeWidth / 2.5);
      canvas.drawLine(start - shift / 2, end - shift / 2, paint);
      canvas.drawLine(start + shift / 2, end + shift / 2, paint);
      return;
    }

    if (style == 'thick') {
      paint.strokeWidth = math.max(1.5, paint.strokeWidth);
      canvas.drawLine(start, end, paint);
      return;
    }

    if (style == 'dotted' ||
        style == 'dashed' ||
        style == 'dashDot' ||
        style == 'dashDotDot' ||
        style == 'wave') {
      _paintInteropDashedBorder(canvas, start, end, paint, style);
      return;
    }

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _InteropWordBorderPainter oldDelegate) =>
      oldDelegate.borders != borders ||
      oldDelegate.fallbackColor != fallbackColor ||
      oldDelegate.fallbackAll != fallbackAll;
}

void _paintInteropDashedBorder(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  String style,
) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length <= 0) return;
  final ux = dx / length;
  final uy = dy / length;
  final base = math.max(1.0, paint.strokeWidth);
  final pattern = switch (style) {
    'dotted' => <double>[base, 2.4 * base],
    'dashDot' => <double>[5 * base, 2 * base, base, 2 * base],
    'dashDotDot' => <double>[
        5 * base,
        2 * base,
        base,
        2 * base,
        base,
        2 * base,
      ],
    'wave' => <double>[2.5 * base, 1.5 * base],
    _ => <double>[5 * base, 3 * base],
  };

  var distance = 0.0;
  var patternIndex = 0;
  var draw = true;
  while (distance < length) {
    final segment = pattern[patternIndex % pattern.length];
    final next = math.min(length, distance + segment);
    if (draw) {
      canvas.drawLine(
        Offset(start.dx + ux * distance, start.dy + uy * distance),
        Offset(start.dx + ux * next, start.dy + uy * next),
        paint,
      );
    }
    distance = next;
    patternIndex++;
    draw = !draw;
  }
}

class _RichCellContent extends StatelessWidget {
  const _RichCellContent({required this.cell, required this.header});

  final SmartEditorInteropTableCell cell;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final block in cell.blocks) {
      switch (block.kind) {
        case 'image':
          final image = block.image;
          if (image == null || image.bytes.isEmpty) continue;
          children.add(
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : image.widthPoints;
                final sourceWidth = image.widthPoints <= 0
                    ? 160.0
                    : image.widthPoints;
                final width = sourceWidth.clamp(24.0, maxWidth).toDouble();
                final sourceHeight = image.heightPoints <= 0
                    ? 120.0
                    : image.heightPoints;
                final height = (sourceHeight * (width / sourceWidth))
                    .clamp(24.0, 640.0)
                    .toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RepaintBoundary(
                      child: _interopWordImage(
                        image,
                        width: width,
                        height: height,
                        error: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        case 'table':
          final nested = block.table;
          if (nested != null && nested.rows.isNotEmpty) {
            children.add(_InteropTable(payload: nested));
          }
        case 'opaqueOoxml':
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                block.fallbackText.trim().isNotEmpty
                    ? block.fallbackText
                    : '[Word ${block.featureKind ?? 'object'} preserved]',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          );
        default:
          children.add(
            _RichParagraph(
              block: block,
              header: header,
              noWrap: cell.noWrap,
            ),
          );
      }
    }
    if (children.isEmpty) {
      return Text(
        cell.text,
        softWrap: !cell.noWrap,
        overflow: cell.noWrap ? TextOverflow.visible : TextOverflow.clip,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: header ? FontWeight.w700 : null,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _RichParagraph extends StatelessWidget {
  const _RichParagraph({
    required this.block,
    required this.header,
    this.noWrap = false,
  });

  final SmartEditorInteropCellBlock block;
  final bool header;
  final bool noWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final spans = block.runs
        .map(
          (run) => TextSpan(
            text: run.allCaps || run.smallCaps
                ? run.text.toUpperCase()
                : run.text,
            style: base.copyWith(
              fontWeight: run.bold || header ? FontWeight.w700 : null,
              fontStyle: run.italic ? FontStyle.italic : null,
              fontFamily: run.fontFamily,
              fontSize: run.fontSizePoints == null
                  ? null
                  : run.fontSizePoints! *
                      (run.smallCaps && !run.allCaps ? 0.86 : 1.0),
              letterSpacing: run.letterSpacingPoints,
              color: _hexColor(run.colorHex),
              backgroundColor: _hexColor(run.backgroundHex),
              decoration: _decoration(run),
              decorationStyle: _decorationStyle(run),
            ),
          ),
        )
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(
        top: block.spaceBeforePoints.clamp(0, 36),
        bottom: block.spaceAfterPoints.clamp(0, 36),
      ),
      child: RichText(
        textAlign: _textAlign(block.alignment),
        softWrap: !noWrap,
        overflow: noWrap ? TextOverflow.visible : TextOverflow.clip,
        text: TextSpan(
          children: spans,
          style: base.copyWith(
            height: block.lineSpacingMultiple ??
                (block.exactLineSpacingPoints == null || base.fontSize == null
                    ? null
                    : block.exactLineSpacingPoints! / base.fontSize!),
          ),
        ),
      ),
    );
  }
}

TextDecoration? _decoration(SmartEditorInteropTextRun run) {
  final lineThrough = run.strike || run.doubleStrike;
  if (run.underline && lineThrough) {
    return TextDecoration.combine(<TextDecoration>[
      TextDecoration.underline,
      TextDecoration.lineThrough,
    ]);
  }
  if (run.underline) return TextDecoration.underline;
  if (lineThrough) return TextDecoration.lineThrough;
  return null;
}

TextDecorationStyle? _decorationStyle(SmartEditorInteropTextRun run) {
  if (!run.underline) return null;
  return switch (run.underlineStyle) {
    'double' => TextDecorationStyle.double,
    'dotted' => TextDecorationStyle.dotted,
    'dashed' => TextDecorationStyle.dashed,
    'wavy' => TextDecorationStyle.wavy,
    _ => TextDecorationStyle.solid,
  };
}

TextAlign _textAlign(String value) => switch (value) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };

class _InteropPlaceholder extends StatelessWidget {
  const _InteropPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

Color? _hexColor(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return null;
  return Color(0xFF000000 | int.parse(normalized, radix: 16));
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _double(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
