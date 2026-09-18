import 'package:edusheet/features/guided_experience/application/contextual_help_policy.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help_preferences.dart';
import 'package:edusheet/features/guided_experience/domain/contextual_help_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _suggestion = ContextualHelpSuggestion(
  id: 'planner.syllabus',
  screen: GuidedScreenContext.teachingPlanner,
  title: 'Need help?',
  message: 'Finish setup.',
  minimumInactivity: Duration(minutes: 1),
  requiresIncompleteAction: true,
);

void main() {
  const policy = ContextualHelpPolicy();
  final now = DateTime(2026, 9, 16, 12);

  ContextualHelpState state({
    bool enabled = true,
    Map<String, DateTime> snoozed = const <String, DateTime>{},
  }) {
    return ContextualHelpState(
      isInitialized: true,
      preferences: ContextualHelpPreferences(
        helperEnabled: enabled,
        snoozedUntilBySuggestion: snoozed,
      ),
    );
  }

  const eligibleSignals = ContextualHelpSignals(
    currentScreen: GuidedScreenContext.teachingPlanner,
    hasIncompleteAction: true,
    inactivity: Duration(minutes: 1),
  );

  test('offers only when context is relevant and non-blocking', () {
    expect(
      policy.canOffer(
        suggestion: _suggestion,
        signals: eligibleSignals,
        state: state(),
        now: now,
        alreadyOfferedThisSession: false,
      ),
      isTrue,
    );

    for (final signals in <ContextualHelpSignals>[
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.home,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: false,
        inactivity: Duration(minutes: 1),
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(seconds: 59),
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
        hasActiveGuide: true,
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
        hasBlockingModal: true,
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
        isTextInputActive: true,
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
        isAppForeground: false,
      ),
      const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.teachingPlanner,
        hasIncompleteAction: true,
        inactivity: Duration(minutes: 1),
        relatedGuideCompleted: true,
      ),
    ]) {
      expect(
        policy.canOffer(
          suggestion: _suggestion,
          signals: signals,
          state: state(),
          now: now,
          alreadyOfferedThisSession: false,
        ),
        isFalse,
      );
    }
  });

  test('respects disabled, session-offered, and persisted snooze state', () {
    expect(
      policy.canOffer(
        suggestion: _suggestion,
        signals: eligibleSignals,
        state: state(enabled: false),
        now: now,
        alreadyOfferedThisSession: false,
      ),
      isFalse,
    );
    expect(
      policy.canOffer(
        suggestion: _suggestion,
        signals: eligibleSignals,
        state: state(),
        now: now,
        alreadyOfferedThisSession: true,
      ),
      isFalse,
    );
    expect(
      policy.canOffer(
        suggestion: _suggestion,
        signals: eligibleSignals,
        state: state(
          snoozed: <String, DateTime>{
            _suggestion.id: now.add(const Duration(hours: 1)),
          },
        ),
        now: now,
        alreadyOfferedThisSession: false,
      ),
      isFalse,
    );
  });
}
