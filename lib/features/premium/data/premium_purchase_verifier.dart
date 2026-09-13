import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/premium_store_models.dart';

class PremiumVerificationResult {
  const PremiumVerificationResult({
    required this.isValid,
    required this.isActive,
    this.isDefinitive = true,
    this.expiresAt,
    this.message,
  });

  final bool isValid;
  final bool isActive;
  final bool isDefinitive;
  final DateTime? expiresAt;
  final String? message;
}

abstract interface class PremiumPurchaseVerifier {
  bool get isConfigured;

  String? get configurationMessage;

  Future<PremiumVerificationResult> verify(PremiumPurchaseUpdate purchase);

  void dispose();
}

class GooglePlayPremiumPurchaseVerifier implements PremiumPurchaseVerifier {
  GooglePlayPremiumPurchaseVerifier({
    http.Client? client,
    String? verificationUrl,
    String packageName = AppConfig.androidPackageName,
    String productId = AppConfig.premiumProductId,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _verificationUrl = verificationUrl ?? AppConfig.purchaseVerificationUrl,
       _packageName = packageName,
       _productId = productId;

  final http.Client _client;
  final bool _ownsClient;
  final String _verificationUrl;
  final String _packageName;
  final String _productId;

  Uri? get _verificationUri {
    final uri = Uri.tryParse(_verificationUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  @override
  bool get isConfigured => _verificationUri != null;

  @override
  String? get configurationMessage => isConfigured
      ? null
      : 'Secure Google Play purchase verification is not configured.';

  @override
  Future<PremiumVerificationResult> verify(
    PremiumPurchaseUpdate purchase,
  ) async {
    if (purchase.productId != _productId) {
      return const PremiumVerificationResult(
        isValid: false,
        isActive: false,
        message: 'The purchase belongs to an unknown product.',
      );
    }
    if (purchase.serverVerificationData.trim().isEmpty) {
      return const PremiumVerificationResult(
        isValid: false,
        isActive: false,
        message: 'Google Play did not return a purchase token.',
      );
    }

    final uri = _verificationUri;
    if (uri == null) {
      return PremiumVerificationResult(
        isValid: false,
        isActive: false,
        isDefinitive: false,
        message: configurationMessage,
      );
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'packageName': _packageName,
              'productId': purchase.productId,
              'purchaseToken': purchase.serverVerificationData,
              'purchaseId': purchase.purchaseId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PremiumVerificationResult(
          isValid: false,
          isActive: false,
          isDefinitive: false,
          message: 'Verification server returned ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['valid'] is! bool ||
          decoded['active'] is! bool) {
        throw const FormatException('Invalid verification response.');
      }
      final expiresAtMs = (decoded['expiresAtMs'] as num?)?.toInt();
      return PremiumVerificationResult(
        isValid: decoded['valid'] == true,
        isActive: decoded['active'] == true,
        expiresAt: expiresAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true),
        message: decoded['message'] as String?,
      );
    } catch (_) {
      return const PremiumVerificationResult(
        isValid: false,
        isActive: false,
        isDefinitive: false,
        message: 'Purchase verification is temporarily unavailable.',
      );
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
