import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../data/premium_purchase_verifier.dart';
import '../data/premium_store_gateway.dart';
import '../domain/freemium_policy.dart';
import '../domain/premium_state.dart';
import '../domain/premium_store_models.dart';

final premiumProvider = StateNotifierProvider<PremiumController, PremiumState>((
  ref,
) {
  return PremiumController();
});

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController({
    PremiumStoreGateway? store,
    PremiumPurchaseVerifier? verifier,
    bool? premiumEnabled,
    DateTime Function()? now,
  }) : _store = store ?? createPremiumStoreGateway(),
       _verifier = verifier ?? GooglePlayPremiumPurchaseVerifier(),
       _premiumEnabled = premiumEnabled ?? AppConfig.premiumEnabled,
       _now = now ?? DateTime.now,
       // Fail open for features while store discovery is pending. Advertising
       // waits for the store check to finish so a paid user never sees a
       // startup ad before their entitlement is restored.
       super(const PremiumState(isComplimentaryAccess: true)) {
    unawaited(_initialize());
  }

  final PremiumStoreGateway _store;
  final PremiumPurchaseVerifier _verifier;
  final bool _premiumEnabled;
  final DateTime Function() _now;
  StreamSubscription<PremiumPurchaseUpdate>? _purchaseSubscription;

  Future<void> _initialize() async {
    try {
      if (!_premiumEnabled) {
        if (mounted) {
          state = state.copyWith(
            isComplimentaryAccess: true,
            storeStatus: PremiumStoreStatus.unsupported,
            message:
                'Premium checkout is off in this release. Every feature remains available.',
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

      if (_store.requiresServerVerification && !_verifier.isConfigured) {
        if (mounted) {
          state = state.copyWith(
            isComplimentaryAccess: true,
            storeStatus: PremiumStoreStatus.unavailable,
            clearProduct: true,
            message: _verifier.configurationMessage,
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
              'The subscription is not active in this store yet. Full feature access remains available.',
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
        message: 'The Premium plan could not connect to the app store.',
      );
    }
  }

  Future<void> buyPremium() async {
    final product = state.product;
    if (state.purchasePending || product == null) return;
    if (_store.requiresServerVerification && !_verifier.isConfigured) {
      state = state.copyWith(message: _verifier.configurationMessage);
      return;
    }

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
        var isInGracePeriod = false;
        DateTime? gracePeriodEndsAt;
        if (_store.requiresServerVerification) {
          final verification = await _verifier.verify(purchase);
          gracePeriodEndsAt = verification.expiresAt?.add(
            FreemiumPolicy.premiumGracePeriod,
          );
          isInGracePeriod =
              verification.isValid &&
              !verification.isActive &&
              gracePeriodEndsAt != null &&
              !_now().toUtc().isAfter(gracePeriodEndsAt);
          if (!verification.isValid ||
              (!verification.isActive && !isInGracePeriod)) {
            if (mounted) {
              state = state.copyWith(
                isPremium: verification.isDefinitive ? false : state.isPremium,
                isInGracePeriod: verification.isDefinitive
                    ? false
                    : state.isInGracePeriod,
                clearGracePeriodEndsAt: verification.isDefinitive,
                purchasePending: false,
                message:
                    verification.message ??
                    'Google Play could not verify an active subscription.',
              );
            }
            return;
          }
        }
        try {
          if (purchase.pendingCompletePurchase) {
            await _store.complete(purchase);
          }
          await _grantPremium(
            gracePeriodEndsAt: gracePeriodEndsAt,
            inGracePeriod: isInGracePeriod,
          );
        } catch (_) {
          if (mounted) {
            state = state.copyWith(
              purchasePending: false,
              message: 'The verified purchase could not be completed safely.',
            );
          }
        }
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

  Future<void> _grantPremium({
    bool inGracePeriod = false,
    DateTime? gracePeriodEndsAt,
  }) async {
    if (!mounted) return;
    state = state.copyWith(
      isPremium: !inGracePeriod,
      isInGracePeriod: inGracePeriod,
      gracePeriodEndsAt: gracePeriodEndsAt,
      clearGracePeriodEndsAt: !inGracePeriod,
      isComplimentaryAccess: false,
      purchasePending: false,
      message: inGracePeriod
          ? 'Payment issue detected. Premium access remains active during the 7-day grace period.'
          : null,
      clearMessage: !inGracePeriod,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _store.dispose();
    _verifier.dispose();
    super.dispose();
  }
}
