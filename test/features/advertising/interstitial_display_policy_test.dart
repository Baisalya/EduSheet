import 'package:edusheet/features/advertising/domain/interstitial_display_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 20, 12);

  test('offers an interstitial only at every second completed home return', () {
    for (final returns in [1, 3, 5]) {
      expect(
        InterstitialDisplayPolicy.shouldShow(
          completedHomeReturns: returns,
          now: now,
          lastShownAt: null,
          eligible: true,
          isPreloaded: true,
        ),
        isFalse,
      );
    }
    expect(
      InterstitialDisplayPolicy.shouldShow(
        completedHomeReturns: 2,
        now: now,
        lastShownAt: null,
        eligible: true,
        isPreloaded: true,
      ),
      isTrue,
    );
  });

  test('ten-second gap and preload prevent disruptive launches', () {
    expect(
      InterstitialDisplayPolicy.shouldShow(
        completedHomeReturns: 4,
        now: now,
        lastShownAt: now.subtract(const Duration(seconds: 9)),
        eligible: true,
        isPreloaded: true,
      ),
      isFalse,
    );
    expect(
      InterstitialDisplayPolicy.shouldShow(
        completedHomeReturns: 4,
        now: now,
        lastShownAt: now.subtract(const Duration(seconds: 10)),
        eligible: true,
        isPreloaded: true,
      ),
      isTrue,
    );
    expect(
      InterstitialDisplayPolicy.shouldShow(
        completedHomeReturns: 4,
        now: now,
        lastShownAt: null,
        eligible: true,
        isPreloaded: false,
      ),
      isFalse,
    );
  });
}
