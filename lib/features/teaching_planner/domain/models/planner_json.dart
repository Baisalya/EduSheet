DateTime plannerRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString();
  final parsed = value == null ? null : DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid or missing $key.');
  }
  return parsed;
}

DateTime? plannerOptionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) {
    throw FormatException('Invalid $key.');
  }
  return parsed;
}

int plannerInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw FormatException('Invalid $key.');
  }
  return parsed;
}

String plannerRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('Invalid or missing $key.');
  }
  return value;
}

String? plannerOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
