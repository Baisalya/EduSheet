import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/config/app_config.dart';
import '../domain/premium_store_models.dart';

abstract interface class PremiumStoreGateway {
  bool get isSupported;

  Stream<PremiumPurchaseUpdate> get purchaseUpdates;

  Future<PremiumCatalogEntry?> loadProduct(String productId);

  Future<bool> buy(PremiumProduct product);

  Future<PremiumRestoreResult> restore(String productId);

  void dispose();
}

PremiumStoreGateway createPremiumStoreGateway({TargetPlatform? platform}) {
  if (kIsWeb || !AppConfig.premiumEnabled) {
    return const UnsupportedPremiumStoreGateway();
  }

  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => MobilePremiumStoreGateway(),
    TargetPlatform.windows => MicrosoftPremiumStoreGateway(),
    _ => const UnsupportedPremiumStoreGateway(),
  };
}

class UnsupportedPremiumStoreGateway implements PremiumStoreGateway {
  const UnsupportedPremiumStoreGateway();

  @override
  bool get isSupported => false;

  @override
  Stream<PremiumPurchaseUpdate> get purchaseUpdates => const Stream.empty();

  @override
  Future<PremiumCatalogEntry?> loadProduct(String productId) async => null;

  @override
  Future<bool> buy(PremiumProduct product) async => false;

  @override
  Future<PremiumRestoreResult> restore(String productId) async =>
      const PremiumRestoreResult(PremiumRestoreStatus.notFound);

  @override
  void dispose() {}
}

class MobilePremiumStoreGateway implements PremiumStoreGateway {
  final InAppPurchase _store;
  final StreamController<PremiumPurchaseUpdate> _updates =
      StreamController<PremiumPurchaseUpdate>.broadcast(sync: true);
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  MobilePremiumStoreGateway({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(
      _handlePurchaseDetails,
      onError: (Object error, StackTrace stackTrace) {
        if (_updates.isClosed) return;
        _updates.add(
          const PremiumPurchaseUpdate(
            productId: '',
            status: PremiumPurchaseStatus.error,
            message: 'The app store could not finish this purchase.',
          ),
        );
      },
    );
  }

  @override
  bool get isSupported => true;

  @override
  Stream<PremiumPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<PremiumCatalogEntry?> loadProduct(String productId) async {
    if (!await _store.isAvailable()) {
      throw const PremiumStoreException(
        'The app store is unavailable on this device.',
      );
    }

    final response = await _store.queryProductDetails(<String>{productId});
    if (response.error != null) {
      throw PremiumStoreException(response.error!.message);
    }
    if (response.productDetails.isEmpty) return null;

    final details = response.productDetails.first;
    _products[productId] = details;
    return PremiumCatalogEntry(
      product: PremiumProduct(
        id: details.id,
        title: details.title,
        description: details.description,
        price: details.price,
      ),
    );
  }

  @override
  Future<bool> buy(PremiumProduct product) async {
    final details = _products[product.id];
    if (details == null) {
      throw const PremiumStoreException(
        'Premium product details are not available yet.',
      );
    }
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<PremiumRestoreResult> restore(String productId) async {
    await _store.restorePurchases();
    return const PremiumRestoreResult(PremiumRestoreStatus.requested);
  }

  Future<void> _handlePurchaseDetails(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_updates.isClosed) {
        _updates.add(
          PremiumPurchaseUpdate(
            productId: purchase.productID,
            status: switch (purchase.status) {
              PurchaseStatus.pending => PremiumPurchaseStatus.pending,
              PurchaseStatus.purchased => PremiumPurchaseStatus.purchased,
              PurchaseStatus.restored => PremiumPurchaseStatus.restored,
              PurchaseStatus.error => PremiumPurchaseStatus.error,
              PurchaseStatus.canceled => PremiumPurchaseStatus.canceled,
            },
            message: purchase.error?.message,
          ),
        );
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_updates.close());
  }
}

class MicrosoftPremiumStoreGateway implements PremiumStoreGateway {
  static const MethodChannel _channel = MethodChannel(
    'edusheet/microsoft_store',
  );

  final StreamController<PremiumPurchaseUpdate> _updates =
      StreamController<PremiumPurchaseUpdate>.broadcast(sync: true);

  @override
  bool get isSupported => true;

  @override
  Stream<PremiumPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<PremiumCatalogEntry?> loadProduct(String productId) async {
    final response = await _invoke('getProduct', productId);
    switch (response['status']) {
      case 'ready':
        return PremiumCatalogEntry(
          alreadyPurchased: response['isPurchased'] == true,
          product: PremiumProduct(
            id: response['productId'] as String? ?? productId,
            title: response['title'] as String? ?? 'EduSheet Premium',
            description: response['description'] as String? ?? '',
            price: response['price'] as String? ?? '',
          ),
        );
      case 'notConfigured':
        return null;
      default:
        throw PremiumStoreException(
          response['message'] as String? ??
              'Microsoft Store is unavailable for this build.',
        );
    }
  }

  @override
  Future<bool> buy(PremiumProduct product) async {
    final response = await _invoke('purchase', product.id);
    final status = response['status'] as String?;
    switch (status) {
      case 'succeeded':
      case 'alreadyPurchased':
        _emit(product.id, PremiumPurchaseStatus.purchased);
        return true;
      case 'notPurchased':
        _emit(product.id, PremiumPurchaseStatus.canceled);
        return true;
      default:
        final message =
            response['message'] as String? ??
            'Microsoft Store could not complete the purchase.';
        _emit(product.id, PremiumPurchaseStatus.error, message);
        return false;
    }
  }

  @override
  Future<PremiumRestoreResult> restore(String productId) async {
    final response = await _invoke('restore', productId);
    if (response['status'] == 'restored') {
      _emit(productId, PremiumPurchaseStatus.restored);
      return const PremiumRestoreResult(PremiumRestoreStatus.restored);
    }
    if (response['status'] == 'notFound') {
      return const PremiumRestoreResult(
        PremiumRestoreStatus.notFound,
        message:
            'No active premium purchase was found for this Microsoft account.',
      );
    }
    throw PremiumStoreException(
      response['message'] as String? ??
          'Microsoft Store could not restore purchases.',
    );
  }

  Future<Map<String, Object?>> _invoke(String method, String productId) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        method,
        <String, Object?>{'productId': productId},
      );
      return response ??
          <String, Object?>{
            'status': 'unavailable',
            'message': 'Microsoft Store returned no response.',
          };
    } on PlatformException catch (error) {
      throw PremiumStoreException(
        error.message ?? 'Microsoft Store is unavailable for this build.',
      );
    } on MissingPluginException {
      throw const PremiumStoreException(
        'Microsoft Store checkout requires the packaged Windows edition.',
      );
    }
  }

  void _emit(
    String productId,
    PremiumPurchaseStatus status, [
    String? message,
  ]) {
    if (_updates.isClosed) return;
    _updates.add(
      PremiumPurchaseUpdate(
        productId: productId,
        status: status,
        message: message,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_updates.close());
  }
}
