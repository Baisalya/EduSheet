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

  const SmartDocumentPageLayout({
    this.pageSize = SmartDocumentPageSize.a4,
    this.orientation = SmartDocumentOrientation.portrait,
    this.marginPreset = SmartDocumentMarginPreset.normal,
    this.borderStyle = SmartDocumentPageBorderStyle.subtle,
    this.customTopMargin = 72.0,
    this.customRightMargin = 72.0,
    this.customBottomMargin = 72.0,
    this.customLeftMargin = 72.0,
  });

  double get logicalWidth {
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
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmartDocument({
    required this.id,
    required this.title,
    required this.deltaJson,
    required this.pageLayout,
    this.header = const SmartDocumentHeaderFooter(),
    this.footer = const SmartDocumentHeaderFooter(),
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
