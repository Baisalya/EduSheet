import 'premium_store_models.dart';

enum PremiumStoreStatus { loading, ready, unavailable, unsupported }

class PremiumState {
  final bool isPremium;
  final bool isInGracePeriod;
  final DateTime? gracePeriodEndsAt;
  final bool isComplimentaryAccess;
  final bool purchasePending;
  final PremiumStoreStatus storeStatus;
  final PremiumProduct? product;
  final String? message;

  const PremiumState({
    this.isPremium = false,
    this.isInGracePeriod = false,
    this.gracePeriodEndsAt,
    this.isComplimentaryAccess = false,
    this.purchasePending = false,
    this.storeStatus = PremiumStoreStatus.loading,
    this.product,
    this.message,
  });

  bool get hasPremiumAccess =>
      isPremium || isInGracePeriod || isComplimentaryAccess;

  /// Complimentary mode keeps features unlocked while the store product is
  /// inactive or temporarily unavailable, but it is still the ad-supported
  /// Free experience. Only a paid or grace-period entitlement removes ads.
  bool get hasAdFreeAccess => isPremium || isInGracePeriod;

  PremiumState copyWith({
    bool? isPremium,
    bool? isInGracePeriod,
    DateTime? gracePeriodEndsAt,
    bool clearGracePeriodEndsAt = false,
    bool? isComplimentaryAccess,
    bool? purchasePending,
    PremiumStoreStatus? storeStatus,
    PremiumProduct? product,
    bool clearProduct = false,
    String? message,
    bool clearMessage = false,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isInGracePeriod: isInGracePeriod ?? this.isInGracePeriod,
      gracePeriodEndsAt: clearGracePeriodEndsAt
          ? null
          : (gracePeriodEndsAt ?? this.gracePeriodEndsAt),
      isComplimentaryAccess:
          isComplimentaryAccess ?? this.isComplimentaryAccess,
      purchasePending: purchasePending ?? this.purchasePending,
      storeStatus: storeStatus ?? this.storeStatus,
      product: clearProduct ? null : (product ?? this.product),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
