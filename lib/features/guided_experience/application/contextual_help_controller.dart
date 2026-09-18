import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contextual_help_preferences.dart';
import '../domain/contextual_help_state.dart';

class ContextualHelpController extends StateNotifier<ContextualHelpState> {
  ContextualHelpController(this._repository) : super(const ContextualHelpState());

  final ContextualHelpPreferencesRepository _repository;
  final Set<String> _offeredThisSession = <String>{};
  Future<void>? _loadOperation;

  bool wasOfferedThisSession(String suggestionId) =>
      _offeredThisSession.contains(suggestionId);

  void markOfferedThisSession(String suggestionId) {
    _offeredThisSession.add(suggestionId);
  }

  Future<void> load() {
    final existing = _loadOperation;
    if (existing != null) return existing;
    final operation = _load();
    _loadOperation = operation;
    return operation.whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preferences = await _repository.load();
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        preferences: preferences,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        preferences: ContextualHelpPreferences(),
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> setHelperEnabled(bool enabled) async {
    await _ensureLoaded();
    final current = state.preferences ?? ContextualHelpPreferences();
    await _persist(current.copyWith(helperEnabled: enabled));
  }

  Future<void> snooze(
    String suggestionId, {
    Duration duration = const Duration(hours: 24),
    DateTime? now,
  }) async {
    await _ensureLoaded();
    _offeredThisSession.add(suggestionId);
    final current = state.preferences ?? ContextualHelpPreferences();
    final next = <String, DateTime>{
      ...current.snoozedUntilBySuggestion,
      suggestionId: (now ?? DateTime.now()).add(duration),
    };
    await _persist(current.copyWith(snoozedUntilBySuggestion: next));
  }

  Future<void> _persist(ContextualHelpPreferences preferences) async {
    state = state.copyWith(preferences: preferences, clearError: true);
    try {
      await _repository.save(preferences);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> _ensureLoaded() async {
    if (state.isInitialized) return;
    await load();
  }
}
