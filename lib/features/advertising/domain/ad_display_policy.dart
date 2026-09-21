import '../../premium/domain/premium_state.dart';

abstract final class AdDisplayPolicy {
  static bool shouldShowHomeAd({
    required PremiumState premium,
    required bool adsEnabled,
    required bool platformSupported,
    required bool hasConfiguredAdUnit,
  }) {
    return adsEnabled &&
        platformSupported &&
        hasConfiguredAdUnit &&
        premium.storeStatus != PremiumStoreStatus.loading &&
        !premium.hasAdFreeAccess;
  }
}
