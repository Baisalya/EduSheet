import 'package:edusheet/features/premium/domain/premium_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium state keeps entitlement while store status changes', () {
    const entitled = PremiumState(
      isPremium: true,
      storeStatus: PremiumStoreStatus.loading,
    );

    final offline = entitled.copyWith(
      storeStatus: PremiumStoreStatus.unavailable,
      message: 'Store unavailable',
    );

    expect(offline.isPremium, isTrue);
    expect(offline.storeStatus, PremiumStoreStatus.unavailable);
    expect(offline.message, 'Store unavailable');
  });

  test('copyWith can clear a stale store message', () {
    const failed = PremiumState(message: 'Temporary error');

    expect(failed.copyWith(clearMessage: true).message, isNull);
  });

  test('complimentary mode unlocks features but remains ad-supported', () {
    const complimentary = PremiumState(isComplimentaryAccess: true);
    const paid = PremiumState(isPremium: true);
    const grace = PremiumState(isInGracePeriod: true);

    expect(complimentary.hasPremiumAccess, isTrue);
    expect(complimentary.hasAdFreeAccess, isFalse);
    expect(paid.hasAdFreeAccess, isTrue);
    expect(grace.hasAdFreeAccess, isTrue);
  });
}
