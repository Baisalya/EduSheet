import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/contextual_help_preferences.dart';

class SharedPreferencesContextualHelpRepository
    implements ContextualHelpPreferencesRepository {
  static const _preferencesKey = 'guided_experience.contextual_help';

  @override
  Future<ContextualHelpPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_preferencesKey);
    if (encoded == null || encoded.isEmpty) {
      return ContextualHelpPreferences();
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return ContextualHelpPreferences();
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final snoozedRaw = map['snoozedUntilBySuggestion'];
      final snoozed = <String, DateTime>{};
      if (snoozedRaw is Map) {
        for (final entry in snoozedRaw.entries) {
          final parsed = DateTime.tryParse(entry.value.toString());
          if (parsed != null) snoozed[entry.key.toString()] = parsed;
        }
      }

      return ContextualHelpPreferences(
        helperEnabled: map['helperEnabled'] is bool
            ? map['helperEnabled'] as bool
            : true,
        snoozedUntilBySuggestion: snoozed,
      );
    } on FormatException {
      return ContextualHelpPreferences();
    }
  }

  @override
  Future<void> save(ContextualHelpPreferences preferences) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, Object>{
      'helperEnabled': preferences.helperEnabled,
      'snoozedUntilBySuggestion': preferences.snoozedUntilBySuggestion.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    });
    await sharedPreferences.setString(_preferencesKey, encoded);
  }
}
