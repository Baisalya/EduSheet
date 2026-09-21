import 'package:edusheet/features/advertising/domain/ad_display_policy.dart';
import 'package:edusheet/features/premium/domain/premium_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eligible free users see the home advertising placement', () {
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(storeStatus: PremiumStoreStatus.ready),
        adsEnabled: true,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isTrue,
    );
  });

  test('active subscribers never receive the home advertising placement', () {
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(
          isPremium: true,
          storeStatus: PremiumStoreStatus.ready,
        ),
        adsEnabled: true,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isFalse,
    );
  });

  test('grace-period subscribers never receive advertising', () {
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(
          isInGracePeriod: true,
          storeStatus: PremiumStoreStatus.ready,
        ),
        adsEnabled: true,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isFalse,
    );
  });

  test('complimentary full-feature mode remains ad-supported', () {
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(
          isComplimentaryAccess: true,
          storeStatus: PremiumStoreStatus.unavailable,
        ),
        adsEnabled: true,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isTrue,
    );
  });

  test('loading and unconfigured ad releases do not request ads', () {
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(isComplimentaryAccess: true),
        adsEnabled: true,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isFalse,
    );
    expect(
      AdDisplayPolicy.shouldShowHomeAd(
        premium: const PremiumState(storeStatus: PremiumStoreStatus.ready),
        adsEnabled: false,
        platformSupported: true,
        hasConfiguredAdUnit: true,
      ),
      isFalse,
    );
  });
}
