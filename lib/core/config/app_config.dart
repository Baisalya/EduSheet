import 'package:flutter/foundation.dart';

/// Compile-time release configuration.
///
/// Store identifiers can be overridden per release with `--dart-define`
/// without committing credentials or environment-specific values.
class AppConfig {
  const AppConfig._();

  static const String androidPackageName = 'com.baishalya.edusheet';

  static const String premiumProductId = String.fromEnvironment(
    'PREMIUM_PRODUCT_ID',
    // Keep the existing Store/backend identity; configure its active base plan
    // as monthly in Play Console so established entitlement contracts survive.
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

  /// When enabled, the store catalogue is the activation switch.
  ///
  /// An unavailable/inactive product keeps complimentary access enabled. Once
  /// the matching store product is active, the app exposes checkout while
  /// keeping essential teacher workflows and personal data portability free.
  static const bool premiumEnabled = bool.fromEnvironment(
    'PREMIUM_ENABLED',
    defaultValue: false,
  );

  /// Advertising is opt-in per release so an unfinished AdMob setup can never
  /// ship test inventory or a broken ad surface by accident.
  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  static const String androidHomeBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_HOME_BANNER_ID',
  );

  static const String iosHomeBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_HOME_BANNER_ID',
  );

  static const String androidHomeInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_HOME_INTERSTITIAL_ID',
  );

  static const String iosHomeInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_HOME_INTERSTITIAL_ID',
  );

  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2435281174';
  static const String _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get adsSupportedOnCurrentPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Returns official Google test inventory in debug mode and requires a real
  /// release ad-unit ID in production. An empty result disables the slot.
  static String? get homeBannerAdUnitIdForCurrentPlatform {
    if (!adsEnabled || !adsSupportedOnCurrentPlatform) return null;
    if (!kReleaseMode) {
      return defaultTargetPlatform == TargetPlatform.android
          ? _androidTestBannerAdUnitId
          : _iosTestBannerAdUnitId;
    }
    final configured = defaultTargetPlatform == TargetPlatform.android
        ? androidHomeBannerAdUnitId
        : iosHomeBannerAdUnitId;
    return configured.trim().isEmpty ? null : configured.trim();
  }

  /// Returns pre-load-only interstitial inventory. The ad is shown only at a
  /// completed screen-to-home transition and is never delayed into home use.
  static String? get homeInterstitialAdUnitIdForCurrentPlatform {
    if (!adsEnabled || !adsSupportedOnCurrentPlatform) return null;
    if (!kReleaseMode) {
      return defaultTargetPlatform == TargetPlatform.android
          ? _androidTestInterstitialAdUnitId
          : _iosTestInterstitialAdUnitId;
    }
    final configured = defaultTargetPlatform == TargetPlatform.android
        ? androidHomeInterstitialAdUnitId
        : iosHomeInterstitialAdUnitId;
    return configured.trim().isEmpty ? null : configured.trim();
  }

  /// HTTPS endpoint that validates Android purchase tokens with Google Play.
  /// Keep this empty in source and provide it to paid release builds.
  static const String purchaseVerificationUrl = String.fromEnvironment(
    'EDUSHEET_PURCHASE_VERIFICATION_URL',
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
