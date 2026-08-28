import 'package:flutter/foundation.dart';

/// Compile-time release configuration.
///
/// Store identifiers can be overridden per release with `--dart-define`
/// without committing credentials or environment-specific values.
class AppConfig {
  const AppConfig._();

  static const String premiumProductId = String.fromEnvironment(
    'PREMIUM_PRODUCT_ID',
    defaultValue: 'edusheet_premium_lifetime',
  );

  static const bool premiumEnabled = bool.fromEnvironment(
    'PREMIUM_ENABLED',
    defaultValue: true,
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
  );

  static const String supportEmail = 'support@edusheet.com';
  static const String productWebsiteUrl =
      'https://baisalya.github.io/Baisalya-Roul/EduSheet/';
  static const String privacyPolicyUrl = '${productWebsiteUrl}privacy.html';
}
