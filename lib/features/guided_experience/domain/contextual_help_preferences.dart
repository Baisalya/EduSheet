import 'package:flutter/foundation.dart';

@immutable
class ContextualHelpPreferences {
  ContextualHelpPreferences({
    this.helperEnabled = true,
    Map<String, DateTime> snoozedUntilBySuggestion =
        const <String, DateTime>{},
  }) : snoozedUntilBySuggestion =
           Map<String, DateTime>.unmodifiable(snoozedUntilBySuggestion);

  final bool helperEnabled;
  final Map<String, DateTime> snoozedUntilBySuggestion;

  ContextualHelpPreferences copyWith({
    bool? helperEnabled,
    Map<String, DateTime>? snoozedUntilBySuggestion,
  }) {
    return ContextualHelpPreferences(
      helperEnabled: helperEnabled ?? this.helperEnabled,
      snoozedUntilBySuggestion:
          snoozedUntilBySuggestion ?? this.snoozedUntilBySuggestion,
    );
  }
}

abstract interface class ContextualHelpPreferencesRepository {
  Future<ContextualHelpPreferences> load();

  Future<void> save(ContextualHelpPreferences preferences);
}
