abstract final class InterstitialDisplayPolicy {
  static const int returnsPerOpportunity = 2;
  static const Duration minimumInterval = Duration(seconds: 10);

  static bool shouldShow({
    required int completedHomeReturns,
    required DateTime now,
    required DateTime? lastShownAt,
    required bool eligible,
    required bool isPreloaded,
  }) {
    if (!eligible || !isPreloaded) return false;
    if (completedHomeReturns < returnsPerOpportunity ||
        completedHomeReturns % returnsPerOpportunity != 0) {
      return false;
    }
    if (lastShownAt != null && now.difference(lastShownAt) < minimumInterval) {
      return false;
    }
    return true;
  }
}
