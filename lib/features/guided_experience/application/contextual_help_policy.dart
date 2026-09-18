import '../domain/contextual_help.dart';
import '../domain/contextual_help_state.dart';

class ContextualHelpPolicy {
  const ContextualHelpPolicy();

  bool canOffer({
    required ContextualHelpSuggestion suggestion,
    required ContextualHelpSignals signals,
    required ContextualHelpState state,
    required DateTime now,
    required bool alreadyOfferedThisSession,
  }) {
    if (!state.isInitialized || state.isLoading || !state.helperEnabled) {
      return false;
    }
    if (!signals.isAppForeground ||
        alreadyOfferedThisSession ||
        signals.currentScreen != suggestion.screen) {
      return false;
    }
    if (signals.hasActiveGuide ||
        signals.hasBlockingModal ||
        signals.isTextInputActive) {
      return false;
    }
    if (suggestion.requiresIncompleteAction && !signals.hasIncompleteAction) {
      return false;
    }
    if (suggestion.requiresFirstTimeUse && !signals.isFirstTimeUse) {
      return false;
    }
    if (suggestion.suppressWhenRelatedGuideCompleted &&
        signals.relatedGuideCompleted) {
      return false;
    }
    if (signals.inactivity < suggestion.minimumInactivity) return false;

    final snoozedUntil =
        state.preferences?.snoozedUntilBySuggestion[suggestion.id];
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return false;

    return true;
  }
}
