import 'dart:convert';

class ConversionHistoryEntry {
  const ConversionHistoryEntry({
    required this.outputPath,
    required this.sourceName,
    required this.modeLabel,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String outputPath;
  final String sourceName;
  final String modeLabel;
  final DateTime createdAt;
  final int sizeBytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'outputPath': outputPath,
        'sourceName': sourceName,
        'modeLabel': modeLabel,
        'createdAt': createdAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  String encode() => jsonEncode(toJson());

  static ConversionHistoryEntry? decode(String value) {
    try {
      final raw = jsonDecode(value);
      if (raw is! Map<String, dynamic>) return null;
      final outputPath = raw['outputPath'];
      final sourceName = raw['sourceName'];
      final modeLabel = raw['modeLabel'];
      final createdAt = raw['createdAt'];
      final sizeBytes = raw['sizeBytes'];
      if (outputPath is! String ||
          sourceName is! String ||
          modeLabel is! String ||
          createdAt is! String ||
          sizeBytes is! num) {
        return null;
      }
      return ConversionHistoryEntry(
        outputPath: outputPath,
        sourceName: sourceName,
        modeLabel: modeLabel,
        createdAt: DateTime.parse(createdAt),
        sizeBytes: sizeBytes.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
