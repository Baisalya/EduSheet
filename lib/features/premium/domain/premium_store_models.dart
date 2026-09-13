enum PremiumPurchaseStatus { pending, purchased, restored, canceled, error }

enum PremiumRestoreStatus { restored, requested, notFound }

class PremiumProduct {
  final String id;
  final String title;
  final String description;
  final String price;

  const PremiumProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });
}

class PremiumCatalogEntry {
  final PremiumProduct product;
  final bool alreadyPurchased;

  const PremiumCatalogEntry({
    required this.product,
    this.alreadyPurchased = false,
  });
}

class PremiumPurchaseUpdate {
  final String productId;
  final PremiumPurchaseStatus status;
  final String? message;
  final String serverVerificationData;
  final String? purchaseId;
  final bool pendingCompletePurchase;

  const PremiumPurchaseUpdate({
    required this.productId,
    required this.status,
    this.message,
    this.serverVerificationData = '',
    this.purchaseId,
    this.pendingCompletePurchase = false,
  });
}

class PremiumRestoreResult {
  final PremiumRestoreStatus status;
  final String? message;

  const PremiumRestoreResult(this.status, {this.message});
}

class PremiumStoreException implements Exception {
  final String message;

  const PremiumStoreException(this.message);

  @override
  String toString() => message;
}
