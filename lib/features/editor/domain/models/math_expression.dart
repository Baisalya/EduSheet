import 'dart:convert';

enum MathExpressionDisplay { inline, block }

/// Canonical, portable mathematics stored independently from its visual widget.
///
/// [latex] is the editable source used by every renderer. [plainText] is a
/// required accessibility/export fallback and is never discarded when LaTeX
/// validation fails.
class MathExpression {
  static const int currentFormatVersion = 1;
  static const String quillEmbedKey = 'edusheetMath';

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

  String toQuillEmbedData() => jsonEncode(toJson());

  static MathExpression? tryFromQuillEmbedData(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return MathExpression.fromJson(decoded);
        }
        if (decoded is Map) {
          return MathExpression.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
      if (data is Map<String, dynamic>) {
        return MathExpression.fromJson(data);
      }
      if (data is Map) {
        return MathExpression.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Malformed embeds must never make a saved question unreadable.
    }
    return null;
  }

  static List<MathExpression> embeddedInRichText(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is! List) return const [];
      final expressions = <MathExpression>[];
      final seen = <String>{};
      for (final operation in decoded.whereType<Map>()) {
        final insert = operation['insert'];
        if (insert is! Map || !insert.containsKey(quillEmbedKey)) continue;
        final expression = tryFromQuillEmbedData(insert[quillEmbedKey]);
        if (expression == null) continue;
        if (expression.id.isNotEmpty && !seen.add(expression.id)) continue;
        expressions.add(expression);
      }
      return expressions;
    } catch (_) {
      return const [];
    }
  }

  static List<MathExpression> unplacedInRichText(
    String text,
    List<MathExpression> expressions,
  ) {
    final embeddedIds = embeddedInRichText(
      text,
    ).map((expression) => expression.id).where((id) => id.isNotEmpty).toSet();
    return expressions
        .where((expression) => !embeddedIds.contains(expression.id))
        .toList();
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
