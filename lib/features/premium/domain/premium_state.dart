import 'premium_store_models.dart';

enum PremiumStoreStatus { loading, ready, unavailable, unsupported }

class PremiumState {
  final bool isPremium;
  final bool isComplimentaryAccess;
  final bool purchasePending;
  final PremiumStoreStatus storeStatus;
  final PremiumProduct? product;
  final String? message;

  const PremiumState({
    this.isPremium = false,
    this.isComplimentaryAccess = false,
    this.purchasePending = false,
    this.storeStatus = PremiumStoreStatus.loading,
    this.product,
    this.message,
  });

  bool get hasPremiumAccess => isPremium || isComplimentaryAccess;

  PremiumState copyWith({
    bool? isPremium,
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
      isComplimentaryAccess:
          isComplimentaryAccess ?? this.isComplimentaryAccess,
      purchasePending: purchasePending ?? this.purchasePending,
      storeStatus: storeStatus ?? this.storeStatus,
      product: clearProduct ? null : (product ?? this.product),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
