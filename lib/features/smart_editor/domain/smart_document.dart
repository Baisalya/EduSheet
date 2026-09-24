import 'dart:convert';

import 'package:uuid/uuid.dart';

enum SmartDocumentPageSize { a4, letter }

enum SmartDocumentOrientation { portrait, landscape }

enum SmartDocumentMarginPreset { normal, narrow, wide, custom }

enum SmartDocumentPageBorderStyle { none, subtle, solid, doubleLine }

enum SmartDocumentHeaderFooterAlignment { left, center, right }

class SmartDocumentHeaderFooter {
  final bool enabled;
  final String text;
  final SmartDocumentHeaderFooterAlignment alignment;
  final bool showDivider;

  const SmartDocumentHeaderFooter({
    this.enabled = false,
    this.text = '',
    this.alignment = SmartDocumentHeaderFooterAlignment.center,
    this.showDivider = false,
  });

  SmartDocumentHeaderFooter copyWith({
    bool? enabled,
    String? text,
    SmartDocumentHeaderFooterAlignment? alignment,
    bool? showDivider,
  }) {
    return SmartDocumentHeaderFooter(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      alignment: alignment ?? this.alignment,
      showDivider: showDivider ?? this.showDivider,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'text': text,
    'alignment': alignment.name,
    'showDivider': showDivider,
  };

  factory SmartDocumentHeaderFooter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SmartDocumentHeaderFooter();
    return SmartDocumentHeaderFooter(
      enabled: json['enabled'] == true,
      text: json['text']?.toString() ?? '',
      alignment: _enumValue(
        SmartDocumentHeaderFooterAlignment.values,
        json['alignment'],
        SmartDocumentHeaderFooterAlignment.center,
      ),
      showDivider: json['showDivider'] == true,
    );
  }
}

class SmartDocumentPageLayout {
  final SmartDocumentPageSize pageSize;
  final SmartDocumentOrientation orientation;
  final SmartDocumentMarginPreset marginPreset;
  final SmartDocumentPageBorderStyle borderStyle;
  final double customTopMargin;
  final double customRightMargin;
  final double customBottomMargin;
  final double customLeftMargin;

  /// Exact Word page geometry captured during a standard DOCX import.
  ///
  /// Smart Editor keeps its friendly A4/Letter controls for normal authoring,
  /// while these optional values let an imported document round-trip its
  /// original page size/margins/header distances without silently snapping the
  /// exported DOCX to the nearest preset. Applying Page Layout in the editor
  /// constructs a fresh layout and therefore intentionally clears this source
  /// geometry.
  final double? wordPageWidthPoints;
  final double? wordPageHeightPoints;
  final double? wordMarginTopPoints;
  final double? wordMarginRightPoints;
  final double? wordMarginBottomPoints;
  final double? wordMarginLeftPoints;
  final double? wordHeaderDistancePoints;
  final double? wordFooterDistancePoints;

  const SmartDocumentPageLayout({
    this.pageSize = SmartDocumentPageSize.a4,
    this.orientation = SmartDocumentOrientation.portrait,
    this.marginPreset = SmartDocumentMarginPreset.normal,
    this.borderStyle = SmartDocumentPageBorderStyle.subtle,
    this.customTopMargin = 72.0,
    this.customRightMargin = 72.0,
    this.customBottomMargin = 72.0,
    this.customLeftMargin = 72.0,
    this.wordPageWidthPoints,
    this.wordPageHeightPoints,
    this.wordMarginTopPoints,
    this.wordMarginRightPoints,
    this.wordMarginBottomPoints,
    this.wordMarginLeftPoints,
    this.wordHeaderDistancePoints,
    this.wordFooterDistancePoints,
  });

  double get logicalWidth {
    if (wordPageWidthPoints != null && wordPageWidthPoints! > 0) {
      return wordPageWidthPoints! * (96 / 72);
    }
    final portraitWidth = switch (pageSize) {
      SmartDocumentPageSize.a4 => 794.0,
      SmartDocumentPageSize.letter => 816.0,
    };
    final portraitHeight = switch (pageSize) {
      SmartDocumentPageSize.a4 => 1123.0,
      SmartDocumentPageSize.letter => 1056.0,
    };
    return orientation == SmartDocumentOrientation.portrait
        ? portraitWidth
        : portraitHeight;
  }

  double get logicalHeight {
    if (wordPageHeightPoints != null && wordPageHeightPoints! > 0) {
      return wordPageHeightPoints! * (96 / 72);
    }
    final portraitWidth = switch (pageSize) {
      SmartDocumentPageSize.a4 => 794.0,
      SmartDocumentPageSize.letter => 816.0,
    };
    final portraitHeight = switch (pageSize) {
      SmartDocumentPageSize.a4 => 1123.0,
      SmartDocumentPageSize.letter => 1056.0,
    };
    return orientation == SmartDocumentOrientation.portrait
        ? portraitHeight
        : portraitWidth;
  }

  double get exportPageWidthPoints {
    if (wordPageWidthPoints != null && wordPageWidthPoints! > 0) {
      return wordPageWidthPoints!;
    }
    var width = pageSize == SmartDocumentPageSize.a4 ? 595.3 : 612.0;
    var height = pageSize == SmartDocumentPageSize.a4 ? 841.9 : 792.0;
    if (orientation == SmartDocumentOrientation.landscape) {
      final swap = width;
      width = height;
      height = swap;
    }
    return width;
  }

  double get exportPageHeightPoints {
    if (wordPageHeightPoints != null && wordPageHeightPoints! > 0) {
      return wordPageHeightPoints!;
    }
    var width = pageSize == SmartDocumentPageSize.a4 ? 595.3 : 612.0;
    var height = pageSize == SmartDocumentPageSize.a4 ? 841.9 : 792.0;
    if (orientation == SmartDocumentOrientation.landscape) {
      final swap = width;
      width = height;
      height = swap;
    }
    return height;
  }

  double get exportTopMarginPoints => wordMarginTopPoints ?? topMarginPoints;
  double get exportRightMarginPoints =>
      wordMarginRightPoints ?? rightMarginPoints;
  double get exportBottomMarginPoints =>
      wordMarginBottomPoints ?? bottomMarginPoints;
  double get exportLeftMarginPoints => wordMarginLeftPoints ?? leftMarginPoints;
  double get exportHeaderDistancePoints => wordHeaderDistancePoints ?? 36.0;
  double get exportFooterDistancePoints => wordFooterDistancePoints ?? 36.0;

  double get topMarginPoints => _marginValue(customTopMargin);
  double get rightMarginPoints => _marginValue(customRightMargin);
  double get bottomMarginPoints => _marginValue(customBottomMargin);
  double get leftMarginPoints => _marginValue(customLeftMargin);

  double get marginPoints => switch (marginPreset) {
    SmartDocumentMarginPreset.normal => 72.0,
    SmartDocumentMarginPreset.narrow => 36.0,
    SmartDocumentMarginPreset.wide => 108.0,
    SmartDocumentMarginPreset.custom =>
      (customTopMargin +
              customRightMargin +
              customBottomMargin +
              customLeftMargin) /
          4,
  };

  double _marginValue(double customValue) => switch (marginPreset) {
    SmartDocumentMarginPreset.normal => 72.0,
    SmartDocumentMarginPreset.narrow => 36.0,
    SmartDocumentMarginPreset.wide => 108.0,
    SmartDocumentMarginPreset.custom => customValue.clamp(18.0, 180.0).toDouble(),
  };

  SmartDocumentPageLayout copyWith({
    SmartDocumentPageSize? pageSize,
    SmartDocumentOrientation? orientation,
    SmartDocumentMarginPreset? marginPreset,
    SmartDocumentPageBorderStyle? borderStyle,
    double? customTopMargin,
    double? customRightMargin,
    double? customBottomMargin,
    double? customLeftMargin,
    double? wordPageWidthPoints,
    double? wordPageHeightPoints,
    double? wordMarginTopPoints,
    double? wordMarginRightPoints,
    double? wordMarginBottomPoints,
    double? wordMarginLeftPoints,
    double? wordHeaderDistancePoints,
    double? wordFooterDistancePoints,
  }) {
    return SmartDocumentPageLayout(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      marginPreset: marginPreset ?? this.marginPreset,
      borderStyle: borderStyle ?? this.borderStyle,
      customTopMargin: customTopMargin ?? this.customTopMargin,
      customRightMargin: customRightMargin ?? this.customRightMargin,
      customBottomMargin: customBottomMargin ?? this.customBottomMargin,
      customLeftMargin: customLeftMargin ?? this.customLeftMargin,
      wordPageWidthPoints: wordPageWidthPoints ?? this.wordPageWidthPoints,
      wordPageHeightPoints: wordPageHeightPoints ?? this.wordPageHeightPoints,
      wordMarginTopPoints: wordMarginTopPoints ?? this.wordMarginTopPoints,
      wordMarginRightPoints: wordMarginRightPoints ?? this.wordMarginRightPoints,
      wordMarginBottomPoints:
          wordMarginBottomPoints ?? this.wordMarginBottomPoints,
      wordMarginLeftPoints: wordMarginLeftPoints ?? this.wordMarginLeftPoints,
      wordHeaderDistancePoints:
          wordHeaderDistancePoints ?? this.wordHeaderDistancePoints,
      wordFooterDistancePoints:
          wordFooterDistancePoints ?? this.wordFooterDistancePoints,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageSize': pageSize.name,
    'orientation': orientation.name,
    'marginPreset': marginPreset.name,
    'borderStyle': borderStyle.name,
    'customTopMargin': customTopMargin,
    'customRightMargin': customRightMargin,
    'customBottomMargin': customBottomMargin,
    'customLeftMargin': customLeftMargin,
    if (wordPageWidthPoints != null)
      'wordPageWidthPoints': wordPageWidthPoints,
    if (wordPageHeightPoints != null)
      'wordPageHeightPoints': wordPageHeightPoints,
    if (wordMarginTopPoints != null)
      'wordMarginTopPoints': wordMarginTopPoints,
    if (wordMarginRightPoints != null)
      'wordMarginRightPoints': wordMarginRightPoints,
    if (wordMarginBottomPoints != null)
      'wordMarginBottomPoints': wordMarginBottomPoints,
    if (wordMarginLeftPoints != null)
      'wordMarginLeftPoints': wordMarginLeftPoints,
    if (wordHeaderDistancePoints != null)
      'wordHeaderDistancePoints': wordHeaderDistancePoints,
    if (wordFooterDistancePoints != null)
      'wordFooterDistancePoints': wordFooterDistancePoints,
  };

  factory SmartDocumentPageLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SmartDocumentPageLayout();
    return SmartDocumentPageLayout(
      pageSize: _enumValue(
        SmartDocumentPageSize.values,
        json['pageSize'],
        SmartDocumentPageSize.a4,
      ),
      orientation: _enumValue(
        SmartDocumentOrientation.values,
        json['orientation'],
        SmartDocumentOrientation.portrait,
      ),
      marginPreset: _enumValue(
        SmartDocumentMarginPreset.values,
        json['marginPreset'],
        SmartDocumentMarginPreset.normal,
      ),
      borderStyle: _enumValue(
        SmartDocumentPageBorderStyle.values,
        json['borderStyle'],
        SmartDocumentPageBorderStyle.subtle,
      ),
      customTopMargin: _doubleValue(json['customTopMargin'], 72.0),
      customRightMargin: _doubleValue(json['customRightMargin'], 72.0),
      customBottomMargin: _doubleValue(json['customBottomMargin'], 72.0),
      customLeftMargin: _doubleValue(json['customLeftMargin'], 72.0),
      wordPageWidthPoints: _nullableDoubleValue(json['wordPageWidthPoints']),
      wordPageHeightPoints: _nullableDoubleValue(json['wordPageHeightPoints']),
      wordMarginTopPoints: _nullableDoubleValue(json['wordMarginTopPoints']),
      wordMarginRightPoints:
          _nullableDoubleValue(json['wordMarginRightPoints']),
      wordMarginBottomPoints:
          _nullableDoubleValue(json['wordMarginBottomPoints']),
      wordMarginLeftPoints: _nullableDoubleValue(json['wordMarginLeftPoints']),
      wordHeaderDistancePoints:
          _nullableDoubleValue(json['wordHeaderDistancePoints']),
      wordFooterDistancePoints:
          _nullableDoubleValue(json['wordFooterDistancePoints']),
    );
  }
}


/// Word-native section metadata retained independently from the editor canvas.
/// Values here use Word points (72dpi) so package round-trips are not affected
/// by Flutter logical-pixel conversions.
class SmartDocumentWordColumn {
  const SmartDocumentWordColumn({this.widthPoints, this.spacingPoints});

  final double? widthPoints;
  final double? spacingPoints;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (widthPoints != null) 'widthPoints': widthPoints,
        if (spacingPoints != null) 'spacingPoints': spacingPoints,
      };

  factory SmartDocumentWordColumn.fromJson(Map<String, dynamic> json) =>
      SmartDocumentWordColumn(
        widthPoints: _nullableDoubleValue(json['widthPoints']),
        spacingPoints: _nullableDoubleValue(json['spacingPoints']),
      );
}

class SmartDocumentWordColumns {
  const SmartDocumentWordColumns({
    this.count = 1,
    this.equalWidth = true,
    this.spacingPoints = 36,
    this.separator = false,
    this.columns = const <SmartDocumentWordColumn>[],
  });

  final int count;
  final bool equalWidth;
  final double spacingPoints;
  final bool separator;
  final List<SmartDocumentWordColumn> columns;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'count': count,
        'equalWidth': equalWidth,
        'spacingPoints': spacingPoints,
        'separator': separator,
        if (columns.isNotEmpty)
          'columns': columns.map((column) => column.toJson()).toList(growable: false),
      };

  factory SmartDocumentWordColumns.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SmartDocumentWordColumns();
    final rawCount = json['count'] is num
        ? (json['count'] as num).toInt()
        : int.tryParse(json['count']?.toString() ?? '') ?? 1;
    return SmartDocumentWordColumns(
      count: rawCount.clamp(1, 16).toInt(),
      equalWidth: json['equalWidth'] != false,
      spacingPoints: _nullableDoubleValue(json['spacingPoints']) ?? 36,
      separator: json['separator'] == true,
      columns: (json['columns'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => SmartDocumentWordColumn.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
    );
  }
}

class SmartDocumentWordBorderSide {
  const SmartDocumentWordBorderSide({
    required this.style,
    required this.widthPoints,
    this.colorHex,
    this.spacePoints = 0,
  });

  final String style;
  final double widthPoints;
  final String? colorHex;
  final double spacePoints;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'style': style,
        'widthPoints': widthPoints,
        if (colorHex != null) 'colorHex': colorHex,
        if (spacePoints != 0) 'spacePoints': spacePoints,
      };

  factory SmartDocumentWordBorderSide.fromJson(Map<String, dynamic> json) =>
      SmartDocumentWordBorderSide(
        style: json['style']?.toString() ?? 'single',
        widthPoints: _nullableDoubleValue(json['widthPoints']) ?? 0.5,
        colorHex: json['colorHex']?.toString(),
        spacePoints: _nullableDoubleValue(json['spacePoints']) ?? 0,
      );
}

class SmartDocumentWordPageBorders {
  const SmartDocumentWordPageBorders({
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.offsetFrom = 'text',
    this.display = 'allPages',
    this.zOrder = 'front',
  });

  final SmartDocumentWordBorderSide? top;
  final SmartDocumentWordBorderSide? right;
  final SmartDocumentWordBorderSide? bottom;
  final SmartDocumentWordBorderSide? left;
  final String offsetFrom;
  final String display;
  final String zOrder;

  bool get isEmpty => top == null && right == null && bottom == null && left == null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (top != null) 'top': top!.toJson(),
        if (right != null) 'right': right!.toJson(),
        if (bottom != null) 'bottom': bottom!.toJson(),
        if (left != null) 'left': left!.toJson(),
        'offsetFrom': offsetFrom,
        'display': display,
        'zOrder': zOrder,
      };

  factory SmartDocumentWordPageBorders.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SmartDocumentWordPageBorders();
    SmartDocumentWordBorderSide? side(String name) => json[name] is Map
        ? SmartDocumentWordBorderSide.fromJson(
            Map<String, dynamic>.from(json[name] as Map),
          )
        : null;
    return SmartDocumentWordPageBorders(
      top: side('top'),
      right: side('right'),
      bottom: side('bottom'),
      left: side('left'),
      offsetFrom: json['offsetFrom']?.toString() ?? 'text',
      display: json['display']?.toString() ?? 'allPages',
      zOrder: json['zOrder']?.toString() ?? 'front',
    );
  }
}

class SmartDocumentWordSectionProfile {
  const SmartDocumentWordSectionProfile({
    required this.pageLayout,
    this.breakType = 'nextPage',
    this.titlePage = false,
    this.columns = const SmartDocumentWordColumns(),
    this.gutterPoints = 0,
    this.pageBorders = const SmartDocumentWordPageBorders(),
    this.pageNumberStart,
    this.pageNumberFormat,
    this.header = const SmartDocumentHeaderFooter(),
    this.footer = const SmartDocumentHeaderFooter(),
    this.firstHeader = const SmartDocumentHeaderFooter(),
    this.firstFooter = const SmartDocumentHeaderFooter(),
    this.evenHeader = const SmartDocumentHeaderFooter(),
    this.evenFooter = const SmartDocumentHeaderFooter(),
  });

  final SmartDocumentPageLayout pageLayout;
  final String breakType;
  final bool titlePage;
  final SmartDocumentWordColumns columns;
  final double gutterPoints;
  final SmartDocumentWordPageBorders pageBorders;
  final int? pageNumberStart;
  final String? pageNumberFormat;
  final SmartDocumentHeaderFooter header;
  final SmartDocumentHeaderFooter footer;
  final SmartDocumentHeaderFooter firstHeader;
  final SmartDocumentHeaderFooter firstFooter;
  final SmartDocumentHeaderFooter evenHeader;
  final SmartDocumentHeaderFooter evenFooter;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pageLayout': pageLayout.toJson(),
        'breakType': breakType,
        'titlePage': titlePage,
        'columns': columns.toJson(),
        if (gutterPoints != 0) 'gutterPoints': gutterPoints,
        if (!pageBorders.isEmpty) 'pageBorders': pageBorders.toJson(),
        if (pageNumberStart != null) 'pageNumberStart': pageNumberStart,
        if (pageNumberFormat != null) 'pageNumberFormat': pageNumberFormat,
        'header': header.toJson(),
        'footer': footer.toJson(),
        'firstHeader': firstHeader.toJson(),
        'firstFooter': firstFooter.toJson(),
        'evenHeader': evenHeader.toJson(),
        'evenFooter': evenFooter.toJson(),
      };

  factory SmartDocumentWordSectionProfile.fromJson(Map<String, dynamic> json) =>
      SmartDocumentWordSectionProfile(
        pageLayout: SmartDocumentPageLayout.fromJson(
          json['pageLayout'] is Map
              ? Map<String, dynamic>.from(json['pageLayout'] as Map)
              : null,
        ),
        breakType: json['breakType']?.toString() ?? 'nextPage',
        titlePage: json['titlePage'] == true,
        columns: SmartDocumentWordColumns.fromJson(
          json['columns'] is Map
              ? Map<String, dynamic>.from(json['columns'] as Map)
              : null,
        ),
        gutterPoints: _nullableDoubleValue(json['gutterPoints']) ?? 0,
        pageBorders: SmartDocumentWordPageBorders.fromJson(
          json['pageBorders'] is Map
              ? Map<String, dynamic>.from(json['pageBorders'] as Map)
              : null,
        ),
        pageNumberStart: json['pageNumberStart'] is num
            ? (json['pageNumberStart'] as num).toInt()
            : int.tryParse(json['pageNumberStart']?.toString() ?? ''),
        pageNumberFormat: json['pageNumberFormat']?.toString(),
        header: SmartDocumentHeaderFooter.fromJson(
          json['header'] is Map ? Map<String, dynamic>.from(json['header'] as Map) : null,
        ),
        footer: SmartDocumentHeaderFooter.fromJson(
          json['footer'] is Map ? Map<String, dynamic>.from(json['footer'] as Map) : null,
        ),
        firstHeader: SmartDocumentHeaderFooter.fromJson(
          json['firstHeader'] is Map
              ? Map<String, dynamic>.from(json['firstHeader'] as Map)
              : null,
        ),
        firstFooter: SmartDocumentHeaderFooter.fromJson(
          json['firstFooter'] is Map
              ? Map<String, dynamic>.from(json['firstFooter'] as Map)
              : null,
        ),
        evenHeader: SmartDocumentHeaderFooter.fromJson(
          json['evenHeader'] is Map
              ? Map<String, dynamic>.from(json['evenHeader'] as Map)
              : null,
        ),
        evenFooter: SmartDocumentHeaderFooter.fromJson(
          json['evenFooter'] is Map
              ? Map<String, dynamic>.from(json['evenFooter'] as Map)
              : null,
        ),
      );
}


class SmartDocumentPreservedPackagePart {
  const SmartDocumentPreservedPackagePart({
    required this.path,
    required this.base64Data,
  });

  final String path;
  final String base64Data;

  List<int> get bytes {
    try {
      return base64Decode(base64Data);
    } catch (_) {
      return const <int>[];
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'base64Data': base64Data,
      };

  factory SmartDocumentPreservedPackagePart.fromJson(
    Map<String, dynamic> json,
  ) =>
      SmartDocumentPreservedPackagePart(
        path: json['path']?.toString() ?? '',
        base64Data: json['base64Data']?.toString() ?? '',
      );
}

class SmartDocumentPreservedRelationship {
  const SmartDocumentPreservedRelationship({
    required this.id,
    required this.type,
    required this.target,
    this.targetMode,
  });

  final String id;
  final String type;
  final String target;
  final String? targetMode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'target': target,
        if (targetMode != null) 'targetMode': targetMode,
      };

  factory SmartDocumentPreservedRelationship.fromJson(
    Map<String, dynamic> json,
  ) =>
      SmartDocumentPreservedRelationship(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        target: json['target']?.toString() ?? '',
        targetMode: json['targetMode']?.toString(),
      );
}

class SmartDocumentPreservedContentType {
  const SmartDocumentPreservedContentType({
    required this.contentType,
    this.extension,
    this.partName,
  });

  final String contentType;
  final String? extension;
  final String? partName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'contentType': contentType,
        if (extension != null) 'extension': extension,
        if (partName != null) 'partName': partName,
      };

  factory SmartDocumentPreservedContentType.fromJson(
    Map<String, dynamic> json,
  ) =>
      SmartDocumentPreservedContentType(
        contentType: json['contentType']?.toString() ?? 'application/octet-stream',
        extension: json['extension']?.toString(),
        partName: json['partName']?.toString(),
      );
}

/// WM9 preserve-only package state captured from a standard Word import.
///
/// Parts and relationships outside EduSheet's editable surface are carried
/// unchanged so charts, SmartArt, embedded objects, themes and vendor/private
/// OOXML do not disappear merely because the editor cannot render them yet.
class SmartDocumentWordPreservationState {
  const SmartDocumentWordPreservationState({
    this.packageParts = const <SmartDocumentPreservedPackagePart>[],
    this.documentRelationships = const <SmartDocumentPreservedRelationship>[],
    this.rootRelationships = const <SmartDocumentPreservedRelationship>[],
    this.contentTypes = const <SmartDocumentPreservedContentType>[],
    this.documentNamespaces = const <String, String>{},
  });

  final List<SmartDocumentPreservedPackagePart> packageParts;
  final List<SmartDocumentPreservedRelationship> documentRelationships;
  final List<SmartDocumentPreservedRelationship> rootRelationships;
  final List<SmartDocumentPreservedContentType> contentTypes;
  final Map<String, String> documentNamespaces;

  bool get isEmpty =>
      packageParts.isEmpty &&
      documentRelationships.isEmpty &&
      rootRelationships.isEmpty &&
      contentTypes.isEmpty &&
      documentNamespaces.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'packageParts': packageParts.map((value) => value.toJson()).toList(growable: false),
        'documentRelationships': documentRelationships.map((value) => value.toJson()).toList(growable: false),
        'rootRelationships': rootRelationships.map((value) => value.toJson()).toList(growable: false),
        'contentTypes': contentTypes.map((value) => value.toJson()).toList(growable: false),
        if (documentNamespaces.isNotEmpty)
          'documentNamespaces': documentNamespaces,
      };

  factory SmartDocumentWordPreservationState.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const SmartDocumentWordPreservationState();
    List<T> read<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((value) => parse(Map<String, dynamic>.from(value)))
            .toList(growable: false);
    return SmartDocumentWordPreservationState(
      packageParts: read(
        'packageParts',
        SmartDocumentPreservedPackagePart.fromJson,
      ),
      documentRelationships: read(
        'documentRelationships',
        SmartDocumentPreservedRelationship.fromJson,
      ),
      rootRelationships: read(
        'rootRelationships',
        SmartDocumentPreservedRelationship.fromJson,
      ),
      contentTypes: read(
        'contentTypes',
        SmartDocumentPreservedContentType.fromJson,
      ),
      documentNamespaces: json['documentNamespaces'] is Map
          ? Map<String, String>.from(
              (json['documentNamespaces'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            )
          : const <String, String>{},
    );
  }
}

class SmartDocument {
  static const Uuid _uuid = Uuid();

  final String id;
  final String title;
  final List<dynamic> deltaJson;
  final SmartDocumentPageLayout pageLayout;
  final SmartDocumentHeaderFooter header;
  final SmartDocumentHeaderFooter footer;
  final List<SmartDocumentWordSectionProfile> wordSections;
  final bool wordEvenAndOddHeaders;
  final bool wordMirrorMargins;
  final bool wordGutterAtTop;
  final String? wordBackgroundColorHex;
  final SmartDocumentWordPreservationState wordPreservation;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmartDocument({
    required this.id,
    required this.title,
    required this.deltaJson,
    required this.pageLayout,
    this.header = const SmartDocumentHeaderFooter(),
    this.footer = const SmartDocumentHeaderFooter(),
    this.wordSections = const <SmartDocumentWordSectionProfile>[],
    this.wordEvenAndOddHeaders = false,
    this.wordMirrorMargins = false,
    this.wordGutterAtTop = false,
    this.wordBackgroundColorHex,
    this.wordPreservation = const SmartDocumentWordPreservationState(),
    required this.createdAt,
    required this.updatedAt,
  });

  List<Map<String, dynamic>> get quillOperations => deltaJson
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);

  factory SmartDocument.blank({String title = 'Untitled Document'}) {
    final now = DateTime.now().toUtc();
    return SmartDocument(
      id: _uuid.v4(),
      title: title,
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': '\n'},
      ],
      pageLayout: const SmartDocumentPageLayout(),
      createdAt: now,
      updatedAt: now,
    );
  }

  SmartDocument copyWith({
    String? id,
    String? title,
    List<dynamic>? deltaJson,
    SmartDocumentPageLayout? pageLayout,
    SmartDocumentHeaderFooter? header,
    SmartDocumentHeaderFooter? footer,
    List<SmartDocumentWordSectionProfile>? wordSections,
    bool? wordEvenAndOddHeaders,
    bool? wordMirrorMargins,
    bool? wordGutterAtTop,
    String? wordBackgroundColorHex,
    SmartDocumentWordPreservationState? wordPreservation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      deltaJson: deltaJson ?? this.deltaJson,
      pageLayout: pageLayout ?? this.pageLayout,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      wordSections: wordSections ?? this.wordSections,
      wordEvenAndOddHeaders: wordEvenAndOddHeaders ?? this.wordEvenAndOddHeaders,
      wordMirrorMargins: wordMirrorMargins ?? this.wordMirrorMargins,
      wordGutterAtTop: wordGutterAtTop ?? this.wordGutterAtTop,
      wordBackgroundColorHex:
          wordBackgroundColorHex ?? this.wordBackgroundColorHex,
      wordPreservation: wordPreservation ?? this.wordPreservation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'deltaJson': deltaJson,
    'pageLayout': pageLayout.toJson(),
    'header': header.toJson(),
    'footer': footer.toJson(),
    if (wordSections.isNotEmpty)
      'wordSections': wordSections.map((section) => section.toJson()).toList(growable: false),
    if (wordEvenAndOddHeaders) 'wordEvenAndOddHeaders': true,
    if (wordMirrorMargins) 'wordMirrorMargins': true,
    if (wordGutterAtTop) 'wordGutterAtTop': true,
    if (wordBackgroundColorHex != null)
      'wordBackgroundColorHex': wordBackgroundColorHex,
    if (!wordPreservation.isEmpty)
      'wordPreservation': wordPreservation.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory SmartDocument.fromJson(Map<String, dynamic> json) {
    final rawDelta = json['deltaJson'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    return SmartDocument(
      id: json['id']?.toString() ?? _uuid.v4(),
      title: _cleanTitle(json['title']),
      deltaJson: _normalizeDeltaJson(rawDelta),
      pageLayout: SmartDocumentPageLayout.fromJson(
        json['pageLayout'] is Map
            ? Map<String, dynamic>.from(json['pageLayout'] as Map)
            : null,
      ),
      header: SmartDocumentHeaderFooter.fromJson(
        json['header'] is Map
            ? Map<String, dynamic>.from(json['header'] as Map)
            : null,
      ),
      footer: SmartDocumentHeaderFooter.fromJson(
        json['footer'] is Map
            ? Map<String, dynamic>.from(json['footer'] as Map)
            : null,
      ),
      wordSections: (json['wordSections'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((section) => SmartDocumentWordSectionProfile.fromJson(
                Map<String, dynamic>.from(section),
              ))
          .toList(growable: false),
      wordEvenAndOddHeaders: json['wordEvenAndOddHeaders'] == true,
      wordMirrorMargins: json['wordMirrorMargins'] == true,
      wordGutterAtTop: json['wordGutterAtTop'] == true,
      wordBackgroundColorHex: json['wordBackgroundColorHex']?.toString(),
      wordPreservation: SmartDocumentWordPreservationState.fromJson(
        json['wordPreservation'] is Map
            ? Map<String, dynamic>.from(json['wordPreservation'] as Map)
            : null,
      ),
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      updatedAt: (updatedAt ?? createdAt ?? DateTime.now()).toUtc(),
    );
  }

  static String _cleanTitle(Object? value) {
    final title = value?.toString().trim() ?? '';
    return title.isEmpty ? 'Untitled Document' : title;
  }
}

List<dynamic> _normalizeDeltaJson(Object? raw) {
  if (raw is! List) {
    return const <dynamic>[
      <String, dynamic>{'insert': '\n'},
    ];
  }
  final operations = <dynamic>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final operation = Map<String, dynamic>.from(item);
    final insert = operation['insert'];
    if (insert is! String && insert is! Map) continue;
    if (insert is Map) {
      operation['insert'] = Map<String, dynamic>.from(insert);
    }
    final attributes = operation['attributes'];
    if (attributes != null && attributes is! Map) {
      operation.remove('attributes');
    } else if (attributes is Map) {
      operation['attributes'] = Map<String, dynamic>.from(attributes);
    }
    operations.add(operation);
  }
  if (operations.isEmpty) {
    return const <dynamic>[
      <String, dynamic>{'insert': '\n'},
    ];
  }
  final last = operations.last as Map<String, dynamic>;
  final insert = last['insert'];
  if (insert is! String || !insert.endsWith('\n')) {
    operations.add(<String, dynamic>{'insert': '\n'});
  }
  return operations;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

double _doubleValue(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _nullableDoubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
