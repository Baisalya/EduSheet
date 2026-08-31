import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../data/premium_store_gateway.dart';
import '../domain/premium_state.dart';
import '../domain/premium_store_models.dart';

final premiumProvider = StateNotifierProvider<PremiumController, PremiumState>((
  ref,
) {
  return PremiumController();
});

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController({PremiumStoreGateway? store, bool? premiumEnabled})
    : _store = store ?? createPremiumStoreGateway(),
      _premiumEnabled = premiumEnabled ?? AppConfig.premiumEnabled,
      // Fail open while store discovery is pending. No feature may become
      // paid merely because Play Billing is slow, unavailable, or inactive.
      super(const PremiumState(isComplimentaryAccess: true)) {
    unawaited(_initialize());
  }

  final PremiumStoreGateway _store;
  final bool _premiumEnabled;
  StreamSubscription<PremiumPurchaseUpdate>? _purchaseSubscription;

  Future<void> _initialize() async {
    try {
      if (!_premiumEnabled) {
        if (mounted) {
          state = state.copyWith(
            isComplimentaryAccess: true,
            storeStatus: PremiumStoreStatus.unsupported,
            message:
                'Premium purchases are off. All workspace styles are free in this release.',
          );
        }
        return;
      }

      if (!_store.isSupported) {
        if (mounted) {
          state = state.copyWith(
            isComplimentaryAccess: true,
            storeStatus: PremiumStoreStatus.unsupported,
            clearMessage: true,
          );
        }
        return;
      }

      _purchaseSubscription = _store.purchaseUpdates.listen(
        _handlePurchaseUpdates,
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          state = state.copyWith(
            purchasePending: false,
            message: 'The store could not finish this purchase. Try again.',
          );
        },
      );

      final productId = AppConfig.premiumProductIdForCurrentPlatform;
      final entry = await _store.loadProduct(productId);
      if (!mounted) return;
      if (entry == null) {
        state = state.copyWith(
          isComplimentaryAccess: true,
          storeStatus: PremiumStoreStatus.unavailable,
          clearProduct: true,
          message:
              'The subscription is not active in this store yet. Everything remains free.',
        );
        return;
      }

      if (entry.alreadyPurchased) {
        await _grantPremium();
      }

      state = state.copyWith(
        isComplimentaryAccess: false,
        storeStatus: PremiumStoreStatus.ready,
        product: entry.product,
        clearMessage: true,
      );
    } on PremiumStoreException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isComplimentaryAccess: true,
        storeStatus: _store.isSupported
            ? PremiumStoreStatus.unavailable
            : PremiumStoreStatus.unsupported,
        message: error.message,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isComplimentaryAccess: true,
        storeStatus: PremiumStoreStatus.unavailable,
        message: 'Premium could not connect to the app store.',
      );
    }
  }

  Future<void> buyPremium() async {
    final product = state.product;
    if (state.purchasePending || product == null) return;

    state = state.copyWith(purchasePending: true, clearMessage: true);
    try {
      final started = await _store.buy(product);
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
    if (!_store.isSupported || state.purchasePending) return;
    state = state.copyWith(purchasePending: true, clearMessage: true);
    try {
      final result = await _store.restore(
        AppConfig.premiumProductIdForCurrentPlatform,
      );
      if (!mounted) return;
      switch (result.status) {
        case PremiumRestoreStatus.restored:
          state = state.copyWith(purchasePending: false, clearMessage: true);
        case PremiumRestoreStatus.requested:
          state = state.copyWith(
            purchasePending: false,
            message:
                'Restore requested. Any eligible purchase will appear soon.',
          );
        case PremiumRestoreStatus.notFound:
          state = state.copyWith(
            purchasePending: false,
            message: result.message ?? 'No active premium purchase was found.',
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

  Future<void> _handlePurchaseUpdates(PremiumPurchaseUpdate purchase) async {
    final expectedId = AppConfig.premiumProductIdForCurrentPlatform;
    if (purchase.productId.isNotEmpty && purchase.productId != expectedId) {
      return;
    }

    switch (purchase.status) {
      case PremiumPurchaseStatus.pending:
        if (mounted) state = state.copyWith(purchasePending: true);
      case PremiumPurchaseStatus.purchased:
      case PremiumPurchaseStatus.restored:
        await _grantPremium();
      case PremiumPurchaseStatus.error:
        if (mounted) {
          state = state.copyWith(
            purchasePending: false,
            message: purchase.message ?? 'The purchase failed.',
          );
        }
      case PremiumPurchaseStatus.canceled:
        if (mounted) {
          state = state.copyWith(purchasePending: false, clearMessage: true);
        }
    }
  }

  Future<void> _grantPremium() async {
    if (!mounted) return;
    state = state.copyWith(
      isPremium: true,
      isComplimentaryAccess: false,
      purchasePending: false,
      clearMessage: true,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _store.dispose();
    super.dispose();
  }
}
