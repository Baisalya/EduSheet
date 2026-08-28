import 'package:in_app_purchase/in_app_purchase.dart';

enum PremiumStoreStatus { loading, ready, unavailable, unsupported }

class PremiumState {
  final bool isPremium;
  final bool purchasePending;
  final PremiumStoreStatus storeStatus;
  final ProductDetails? product;
  final String? message;

  const PremiumState({
    this.isPremium = false,
    this.purchasePending = false,
    this.storeStatus = PremiumStoreStatus.loading,
    this.product,
    this.message,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? purchasePending,
    PremiumStoreStatus? storeStatus,
    ProductDetails? product,
    bool clearProduct = false,
    String? message,
    bool clearMessage = false,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      purchasePending: purchasePending ?? this.purchasePending,
      storeStatus: storeStatus ?? this.storeStatus,
      product: clearProduct ? null : (product ?? this.product),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
