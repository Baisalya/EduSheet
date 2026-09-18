import 'package:flutter/foundation.dart';

import 'contextual_help_preferences.dart';

@immutable
class ContextualHelpState {
  const ContextualHelpState({
    this.isInitialized = false,
    this.isLoading = false,
    this.preferences,
    this.errorMessage,
  });

  final bool isInitialized;
  final bool isLoading;
  final ContextualHelpPreferences? preferences;
  final String? errorMessage;

  bool get helperEnabled => preferences?.helperEnabled ?? true;

  ContextualHelpState copyWith({
    bool? isInitialized,
    bool? isLoading,
    ContextualHelpPreferences? preferences,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ContextualHelpState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      preferences: preferences ?? this.preferences,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
