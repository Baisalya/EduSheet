import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../domain/premium_state.dart';

final premiumProvider = StateNotifierProvider<PremiumController, PremiumState>((
  ref,
) {
  return PremiumController();
});

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance,
      super(const PremiumState()) {
    unawaited(_initialize());
  }

  static const String _entitlementKey = 'premium_lifetime_entitlement_v1';
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool get _supportsStorePurchases {
    if (kIsWeb || !AppConfig.premiumEnabled) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locallyEntitled = prefs.getBool(_entitlementKey) ?? false;
      if (mounted) state = state.copyWith(isPremium: locallyEntitled);

      if (!_supportsStorePurchases) {
        if (mounted) {
          state = state.copyWith(
            storeStatus: PremiumStoreStatus.unsupported,
            clearMessage: true,
          );
        }
        return;
      }

      _purchaseSubscription = _store.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          state = state.copyWith(
            purchasePending: false,
            message: 'The store could not finish this purchase. Try again.',
          );
        },
      );

      final storeAvailable = await _store.isAvailable();
      if (!storeAvailable) {
        if (mounted) {
          state = state.copyWith(
            storeStatus: PremiumStoreStatus.unavailable,
            message: 'The app store is unavailable on this device.',
          );
        }
        return;
      }

      final response = await _store.queryProductDetails({
        AppConfig.premiumProductId,
      });
      if (!mounted) return;

      if (response.error != null) {
        state = state.copyWith(
          storeStatus: PremiumStoreStatus.unavailable,
          message: response.error!.message,
        );
        return;
      }
      if (response.productDetails.isEmpty) {
        state = state.copyWith(
          storeStatus: PremiumStoreStatus.unavailable,
          message: 'Premium is not configured in this store yet.',
        );
        return;
      }

      state = state.copyWith(
        storeStatus: PremiumStoreStatus.ready,
        product: response.productDetails.first,
        clearMessage: true,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        storeStatus: _supportsStorePurchases
            ? PremiumStoreStatus.unavailable
            : PremiumStoreStatus.unsupported,
        message: 'Premium could not connect to the app store.',
      );
    }
  }

  Future<void> buyLifetimePremium() async {
    final product = state.product;
    if (state.purchasePending || product == null) return;

    state = state.copyWith(purchasePending: true, clearMessage: true);
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started && mounted) {
        state = state.copyWith(
          purchasePending: false,
          message: 'The purchase was not started. Please try again.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        purchasePending: false,
        message: 'The purchase could not be started.',
      );
    }
  }

  Future<void> restorePurchases() async {
    if (!_supportsStorePurchases || state.purchasePending) return;
    state = state.copyWith(purchasePending: true, clearMessage: true);
    try {
      await _store.restorePurchases();
      if (mounted && !state.isPremium) {
        state = state.copyWith(
          purchasePending: false,
          message: 'Restore requested. Any eligible purchase will appear soon.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        purchasePending: false,
        message: 'Purchases could not be restored right now.',
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConfig.premiumProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) state = state.copyWith(purchasePending: true);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // The store has delivered the non-consumable. A future backend can
          // replace this delivery point with server receipt verification.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_entitlementKey, true);
          if (mounted) {
            state = state.copyWith(
              isPremium: true,
              purchasePending: false,
              clearMessage: true,
            );
          }
        case PurchaseStatus.error:
          if (mounted) {
            state = state.copyWith(
              purchasePending: false,
              message: purchase.error?.message ?? 'The purchase failed.',
            );
          }
        case PurchaseStatus.canceled:
          if (mounted) {
            state = state.copyWith(purchasePending: false, clearMessage: true);
          }
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
