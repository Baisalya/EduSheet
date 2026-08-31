import 'dart:async';

import 'package:edusheet/features/premium/application/premium_controller.dart';
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
  final StreamController<PremiumPurchaseUpdate> _updates =
      StreamController<PremiumPurchaseUpdate>.broadcast(sync: true);
  int buyCalls = 0;

  _FakePremiumStore({this.entry});

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
      ),
    );
    return true;
  }

  @override
  Future<PremiumRestoreResult> restore(String productId) async =>
      const PremiumRestoreResult(PremiumRestoreStatus.notFound);

  @override
  void dispose() {
    unawaited(_updates.close());
  }
}
