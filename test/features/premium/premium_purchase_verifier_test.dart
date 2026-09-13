import 'dart:convert';

import 'package:edusheet/features/premium/data/premium_purchase_verifier.dart';
import 'package:edusheet/features/premium/domain/premium_store_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const endpoint =
      'https://baisalya-entitlement-api.baishalya1999.workers.dev/v1/google-play/verify';
  const purchase = PremiumPurchaseUpdate(
    productId: 'edusheet_premium_yearly',
    status: PremiumPurchaseStatus.purchased,
    serverVerificationData: 'google-purchase-token',
    purchaseId: 'GPA.1234-5678',
    pendingCompletePurchase: true,
  );

  test('sends the EduSheet Play purchase contract to the verifier', () async {
    late Map<String, dynamic> sentBody;
    final verifier = GooglePlayPremiumPurchaseVerifier(
      verificationUrl: endpoint,
      client: MockClient((request) async {
        expect(request.url.toString(), endpoint);
        expect(request.headers['content-type'], contains('application/json'));
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'valid': true,
            'active': true,
            'expiresAtMs': 1817673600000,
            'message': 'Subscription verified.',
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(verifier.dispose);

    final result = await verifier.verify(purchase);

    expect(sentBody, <String, Object?>{
      'packageName': 'com.baishalya.edusheet',
      'productId': 'edusheet_premium_yearly',
      'purchaseToken': 'google-purchase-token',
      'purchaseId': 'GPA.1234-5678',
    });
    expect(result.isValid, isTrue);
    expect(result.isActive, isTrue);
    expect(result.expiresAt?.millisecondsSinceEpoch, 1817673600000);
  });

  test('treats verifier HTTP errors as temporary failures', () async {
    final verifier = GooglePlayPremiumPurchaseVerifier(
      verificationUrl: endpoint,
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(verifier.dispose);

    final result = await verifier.verify(purchase);

    expect(result.isValid, isFalse);
    expect(result.isActive, isFalse);
    expect(result.isDefinitive, isFalse);
  });

  test('rejects a missing Google purchase token locally', () async {
    final verifier = GooglePlayPremiumPurchaseVerifier(
      verificationUrl: endpoint,
      client: MockClient((_) async => throw StateError('must not be called')),
    );
    addTearDown(verifier.dispose);

    final result = await verifier.verify(
      const PremiumPurchaseUpdate(
        productId: 'edusheet_premium_yearly',
        status: PremiumPurchaseStatus.purchased,
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.isDefinitive, isTrue);
    expect(result.message, contains('purchase token'));
  });
}
