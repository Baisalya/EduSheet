import 'dart:async';

import 'package:edusheet/features/premium/application/premium_controller.dart';
import 'package:edusheet/features/premium/data/premium_purchase_verifier.dart';
import 'package:edusheet/features/premium/data/premium_store_gateway.dart';
import 'package:edusheet/features/premium/domain/premium_state.dart';
import 'package:edusheet/features/premium/domain/premium_store_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owned Store subscription grants premium entitlement', () async {
    final store = _FakePremiumStore(
      entry: const PremiumCatalogEntry(
        alreadyPurchased: true,
        product: PremiumProduct(
          id: 'edusheet_premium_yearly',
          title: 'EduSheet Premium',
          description: 'Annual supporter subscription',
          price: '₹399.00',
        ),
      ),
    );
    final controller = PremiumController(store: store, premiumEnabled: true);
    addTearDown(controller.dispose);

    await _flushAsyncWork();

    expect(controller.state.storeStatus, PremiumStoreStatus.ready);
    expect(controller.state.isPremium, isTrue);
    expect(controller.state.product?.price, '₹399.00');
  });

  test('completed purchase update unlocks premium', () async {
    final store = _FakePremiumStore(
      entry: const PremiumCatalogEntry(
        product: PremiumProduct(
          id: 'edusheet_premium_yearly',
          title: 'EduSheet Premium',
          description: 'Annual supporter subscription',
          price: r'$4.99',
        ),
      ),
    );
    final controller = PremiumController(store: store, premiumEnabled: true);
    addTearDown(controller.dispose);
    await _flushAsyncWork();

    await controller.buyPremium();
    await _flushAsyncWork();

    expect(store.buyCalls, 1);
    expect(controller.state.isPremium, isTrue);
    expect(controller.state.purchasePending, isFalse);
  });

  test(
    'Android purchase unlocks only after active server verification',
    () async {
      final store = _FakePremiumStore(
        requiresServerVerification: true,
        entry: const PremiumCatalogEntry(
          product: PremiumProduct(
            id: 'edusheet_premium_yearly',
            title: 'EduSheet Premium',
            description: 'Annual supporter subscription',
            price: '₹399.00',
          ),
        ),
      );
      final verifier = _FakePremiumVerifier(
        result: const PremiumVerificationResult(isValid: true, isActive: true),
      );
      final controller = PremiumController(
        store: store,
        verifier: verifier,
        premiumEnabled: true,
      );
      addTearDown(controller.dispose);
      await _flushAsyncWork();

      await controller.buyPremium();
      await _flushAsyncWork();

      expect(verifier.verifyCalls, 1);
      expect(store.completeCalls, 1);
      expect(controller.state.isPremium, isTrue);
    },
  );

  test('invalid Android purchase is neither unlocked nor completed', () async {
    final store = _FakePremiumStore(
      requiresServerVerification: true,
      entry: const PremiumCatalogEntry(
        product: PremiumProduct(
          id: 'edusheet_premium_yearly',
          title: 'EduSheet Premium',
          description: 'Annual supporter subscription',
          price: '₹399.00',
        ),
      ),
    );
    final verifier = _FakePremiumVerifier(
      result: const PremiumVerificationResult(
        isValid: false,
        isActive: false,
        message: 'Purchase could not be verified.',
      ),
    );
    final controller = PremiumController(
      store: store,
      verifier: verifier,
      premiumEnabled: true,
    );
    addTearDown(controller.dispose);
    await _flushAsyncWork();

    await controller.buyPremium();
    await _flushAsyncWork();

    expect(verifier.verifyCalls, 1);
    expect(store.completeCalls, 0);
    expect(controller.state.isPremium, isFalse);
    expect(controller.state.message, contains('could not be verified'));
  });

  test('missing Android verifier keeps complimentary access enabled', () async {
    final controller = PremiumController(
      store: _FakePremiumStore(
        requiresServerVerification: true,
        entry: const PremiumCatalogEntry(
          product: PremiumProduct(
            id: 'edusheet_premium_yearly',
            title: 'EduSheet Premium',
            description: 'Annual supporter subscription',
            price: '₹399.00',
          ),
        ),
      ),
      verifier: _FakePremiumVerifier(configured: false),
      premiumEnabled: true,
    );
    addTearDown(controller.dispose);

    await _flushAsyncWork();

    expect(controller.state.isComplimentaryAccess, isTrue);
    expect(controller.state.storeStatus, PremiumStoreStatus.unavailable);
    expect(controller.state.message, contains('not configured'));
  });

  test(
    'missing Partner Center product keeps checkout safely unavailable',
    () async {
      final controller = PremiumController(
        store: _FakePremiumStore(),
        premiumEnabled: true,
      );
      addTearDown(controller.dispose);

      await _flushAsyncWork();

      expect(controller.state.storeStatus, PremiumStoreStatus.unavailable);
      expect(controller.state.isComplimentaryAccess, isTrue);
      expect(controller.state.hasPremiumAccess, isTrue);
      expect(controller.state.product, isNull);
      expect(controller.state.message, contains('not active'));
    },
  );

  test('active Store product turns off complimentary access', () async {
    final controller = PremiumController(
      store: _FakePremiumStore(
        entry: const PremiumCatalogEntry(
          product: PremiumProduct(
            id: 'edusheet_premium_yearly',
            title: 'EduSheet Premium',
            description: 'Annual supporter subscription',
            price: '₹399.00',
          ),
        ),
      ),
      premiumEnabled: true,
    );
    addTearDown(controller.dispose);

    expect(controller.state.isComplimentaryAccess, isTrue);
    await _flushAsyncWork();

    expect(controller.state.storeStatus, PremiumStoreStatus.ready);
    expect(controller.state.isComplimentaryAccess, isFalse);
    expect(controller.state.hasPremiumAccess, isFalse);
  });

  test('disabled checkout keeps every premium style free', () async {
    final controller = PremiumController(
      store: _FakePremiumStore(),
      premiumEnabled: false,
    );
    addTearDown(controller.dispose);

    await _flushAsyncWork();

    expect(controller.state.isComplimentaryAccess, isTrue);
    expect(controller.state.hasPremiumAccess, isTrue);
    expect(controller.state.storeStatus, PremiumStoreStatus.unsupported);
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakePremiumStore implements PremiumStoreGateway {
  final PremiumCatalogEntry? entry;
  @override
  final bool requiresServerVerification;
  final StreamController<PremiumPurchaseUpdate> _updates =
      StreamController<PremiumPurchaseUpdate>.broadcast(sync: true);
  int buyCalls = 0;
  int completeCalls = 0;

  _FakePremiumStore({this.entry, this.requiresServerVerification = false});

  @override
  bool get isSupported => true;

  @override
  Stream<PremiumPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<PremiumCatalogEntry?> loadProduct(String productId) async => entry;

  @override
  Future<bool> buy(PremiumProduct product) async {
    buyCalls += 1;
    _updates.add(
      PremiumPurchaseUpdate(
        productId: product.id,
        status: PremiumPurchaseStatus.purchased,
        serverVerificationData: requiresServerVerification
            ? 'google-purchase-token'
            : '',
        purchaseId: 'test-purchase-id',
        pendingCompletePurchase: requiresServerVerification,
      ),
    );
    return true;
  }

  @override
  Future<void> complete(PremiumPurchaseUpdate purchase) async {
    completeCalls += 1;
  }

  @override
  Future<PremiumRestoreResult> restore(String productId) async =>
      const PremiumRestoreResult(PremiumRestoreStatus.notFound);

  @override
  void dispose() {
    unawaited(_updates.close());
  }
}

class _FakePremiumVerifier implements PremiumPurchaseVerifier {
  _FakePremiumVerifier({
    this.configured = true,
    this.result = const PremiumVerificationResult(
      isValid: true,
      isActive: true,
    ),
  });

  final bool configured;
  final PremiumVerificationResult result;
  int verifyCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  String? get configurationMessage =>
      configured ? null : 'Secure purchase verification is not configured.';

  @override
  Future<PremiumVerificationResult> verify(
    PremiumPurchaseUpdate purchase,
  ) async {
    verifyCalls += 1;
    return result;
  }

  @override
  void dispose() {}
}
