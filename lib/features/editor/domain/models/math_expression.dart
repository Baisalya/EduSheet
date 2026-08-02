enum MathExpressionDisplay { inline, block }

/// Canonical, portable mathematics stored independently from its visual widget.
///
/// [latex] is the editable source used by every renderer. [plainText] is a
/// required accessibility/export fallback and is never discarded when LaTeX
/// validation fails.
class MathExpression {
  static const int currentFormatVersion = 1;

  final String id;
  final String latex;
  final String plainText;
  final MathExpressionDisplay display;
  final int formatVersion;
  final Map<String, dynamic> metadata;

  const MathExpression({
    required this.id,
    required this.latex,
    required this.plainText,
    this.display = MathExpressionDisplay.inline,
    this.formatVersion = currentFormatVersion,
    this.metadata = const {},
  });

  MathExpression copyWith({
    String? id,
    String? latex,
    String? plainText,
    MathExpressionDisplay? display,
    int? formatVersion,
    Map<String, dynamic>? metadata,
  }) {
    return MathExpression(
      id: id ?? this.id,
      latex: latex ?? this.latex,
      plainText: plainText ?? this.plainText,
      display: display ?? this.display,
      formatVersion: formatVersion ?? this.formatVersion,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latex': latex,
      'plainText': plainText,
      'display': display.name,
      'formatVersion': formatVersion,
      'metadata': metadata,
    };
  }

  factory MathExpression.fromJson(Map<String, dynamic> json) {
    final displayName = json['display']?.toString();
    final display = MathExpressionDisplay.values.firstWhere(
      (value) => value.name == displayName,
      orElse: () => MathExpressionDisplay.inline,
    );
    final latex = json['latex']?.toString() ?? json['source']?.toString() ?? '';
    return MathExpression(
      id: json['id']?.toString() ?? '',
      latex: latex,
      plainText: json['plainText']?.toString() ?? latex,
      display: display,
      formatVersion:
          (json['formatVersion'] as num?)?.toInt() ?? currentFormatVersion,
      metadata: _stringKeyedMap(json['metadata']),
    );
  }
}

Map<String, dynamic> _stringKeyedMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
