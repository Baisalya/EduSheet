import 'package:flutter/foundation.dart';

/// Compile-time release configuration.
///
/// Store identifiers can be overridden per release with `--dart-define`
/// without committing credentials or environment-specific values.
class AppConfig {
  const AppConfig._();

  static const String premiumProductId = String.fromEnvironment(
    'PREMIUM_PRODUCT_ID',
    defaultValue: 'edusheet_premium_yearly',
  );

  /// Partner Center product ID for the durable Windows premium add-on.
  static const String microsoftPremiumProductId = String.fromEnvironment(
    'MICROSOFT_PREMIUM_PRODUCT_ID',
    defaultValue: 'edusheet_premium_yearly',
  );

  static String get premiumProductIdForCurrentPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
      ? microsoftPremiumProductId
      : premiumProductId;

  static const bool premiumEnabled = bool.fromEnvironment(
    'PREMIUM_ENABLED',
    defaultValue: false,
  );

  /// Store update checks stay quiet in debug/tests and are enabled in release.
  static const bool updateChecksEnabled = bool.fromEnvironment(
    'UPDATE_CHECKS_ENABLED',
    defaultValue: kReleaseMode,
  );

  /// Numeric Apple App Store id. Leave empty until App Store Connect creates it.
  static const String appleAppId = String.fromEnvironment('APPLE_APP_ID');

  /// Microsoft Store product id used by the permanent rating shortcut.
  static const String microsoftStoreId = String.fromEnvironment(
    'MICROSOFT_STORE_ID',
    defaultValue: '9N0ZK8C31X94',
  );

  static const String supportEmail = 'baishalya1999@gmail.com';
  static const String productWebsiteUrl = 'https://baisalya.com/EduSheet/';
  static const String privacyPolicyUrl = '${productWebsiteUrl}privacy.html';
}
