import 'package:flutter/foundation.dart';

enum GuidedScreenContext {
  home,
  createPaper,
  teachingPlanner,
  syllabus,
  settings,
}

@immutable
class ContextualHelpSuggestion {
  const ContextualHelpSuggestion({
    required this.id,
    required this.screen,
    required this.title,
    required this.message,
    this.primaryLabel = 'Show Me',
    this.secondaryLabel = 'Not Now',
    this.disableLabel = 'Turn Off',
    this.minimumInactivity = Duration.zero,
    this.requiresIncompleteAction = false,
    this.requiresFirstTimeUse = false,
    this.suppressWhenRelatedGuideCompleted = true,
  }) : assert(id != '');

  final String id;
  final GuidedScreenContext screen;
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final String disableLabel;
  final Duration minimumInactivity;
  final bool requiresIncompleteAction;
  final bool requiresFirstTimeUse;
  final bool suppressWhenRelatedGuideCompleted;
}

@immutable
class ContextualHelpSignals {
  const ContextualHelpSignals({
    required this.currentScreen,
    this.hasIncompleteAction = false,
    this.isFirstTimeUse = false,
    this.inactivity = Duration.zero,
    this.hasActiveGuide = false,
    this.hasBlockingModal = false,
    this.isTextInputActive = false,
    this.relatedGuideCompleted = false,
    this.isAppForeground = true,
  });

  final GuidedScreenContext currentScreen;
  final bool hasIncompleteAction;
  final bool isFirstTimeUse;
  final Duration inactivity;
  final bool hasActiveGuide;
  final bool hasBlockingModal;
  final bool isTextInputActive;
  final bool relatedGuideCompleted;
  final bool isAppForeground;

  @override
  bool operator ==(Object other) {
    return other is ContextualHelpSignals &&
        other.currentScreen == currentScreen &&
        other.hasIncompleteAction == hasIncompleteAction &&
        other.isFirstTimeUse == isFirstTimeUse &&
        other.inactivity == inactivity &&
        other.hasActiveGuide == hasActiveGuide &&
        other.hasBlockingModal == hasBlockingModal &&
        other.isTextInputActive == isTextInputActive &&
        other.relatedGuideCompleted == relatedGuideCompleted &&
        other.isAppForeground == isAppForeground;
  }

  @override
  int get hashCode => Object.hash(
        currentScreen,
        hasIncompleteAction,
        isFirstTimeUse,
        inactivity,
        hasActiveGuide,
        hasBlockingModal,
        isTextInputActive,
        relatedGuideCompleted,
        isAppForeground,
      );
}
