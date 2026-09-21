import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/presentation/providers/privacy_provider.dart';
import '../../premium/application/premium_controller.dart';
import '../domain/ad_display_policy.dart';
import '../domain/interstitial_display_policy.dart';
import 'ad_consent_controller.dart';

final homeInterstitialControllerProvider = Provider<HomeInterstitialController>(
  (ref) {
    final controller = HomeInterstitialController(ref);
    ref.onDispose(controller.dispose);
    return controller;
  },
);

class HomeInterstitialController {
  HomeInterstitialController(this._ref);

  static const _lastShownKey = 'home_interstitial_last_shown_ms';

  final Ref _ref;
  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;
  bool _disposed = false;
  int _completedHomeReturns = 0;

  Future<void> prepare() async {
    if (_disposed || _loading || _showing || _ad != null) return;
    final adUnitId = AppConfig.homeInterstitialAdUnitIdForCurrentPlatform;
    if (adUnitId == null || !_eligible()) return;
    _loading = true;
    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          if (_disposed || !_eligible()) {
            unawaited(ad.dispose());
          } else {
            _ad = ad;
          }
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    await completer.future;
  }

  Future<void> onReturnedHome() async {
    if (_disposed || _showing) return;
    _completedHomeReturns++;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastShownMs = prefs.getInt(_lastShownKey);
    final lastShownAt = lastShownMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    final ad = _ad;
    final shouldShow = InterstitialDisplayPolicy.shouldShow(
      completedHomeReturns: _completedHomeReturns,
      now: now,
      lastShownAt: lastShownAt,
      eligible: _eligible(),
      isPreloaded: ad != null,
    );
    if (!shouldShow || ad == null) {
      unawaited(prepare());
      return;
    }

    _ad = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        unawaited(prefs.setInt(_lastShownKey, now.millisecondsSinceEpoch));
      },
      onAdDismissedFullScreenContent: (value) {
        unawaited(value.dispose());
        _showing = false;
        unawaited(prepare());
      },
      onAdFailedToShowFullScreenContent: (value, _) {
        unawaited(value.dispose());
        _showing = false;
        unawaited(prepare());
      },
    );
    try {
      await ad.show();
    } catch (_) {
      await ad.dispose();
      _showing = false;
      unawaited(prepare());
    }
  }

  bool _eligible() {
    final premium = _ref.read(premiumProvider);
    final adUnitId = AppConfig.homeInterstitialAdUnitIdForCurrentPlatform;
    final privacyAccepted = _ref
        .read(privacyProvider)
        .maybeWhen(
          data: (version) => version >= PrivacyNotifier.currentPolicyVersion,
          orElse: () => false,
        );
    final consent = _ref.read(adConsentProvider);
    return privacyAccepted &&
        consent.canRequestAds &&
        AdDisplayPolicy.shouldShowHomeAd(
          premium: premium,
          adsEnabled: AppConfig.adsEnabled,
          platformSupported: AppConfig.adsSupportedOnCurrentPlatform,
          hasConfiguredAdUnit: adUnitId != null,
        );
  }

  void dispose() {
    _disposed = true;
    unawaited(_ad?.dispose());
    _ad = null;
  }
}
