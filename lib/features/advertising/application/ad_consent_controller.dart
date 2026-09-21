import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';

class AdConsentState {
  const AdConsentState({
    required this.initialized,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.message,
  });

  const AdConsentState.loading()
    : initialized = false,
      canRequestAds = false,
      privacyOptionsRequired = false,
      message = null;

  const AdConsentState.disabled()
    : initialized = true,
      canRequestAds = false,
      privacyOptionsRequired = false,
      message = null;

  final bool initialized;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final String? message;
}

final adConsentProvider =
    StateNotifierProvider<AdConsentController, AdConsentState>((ref) {
      return AdConsentController();
    });

class AdConsentController extends StateNotifier<AdConsentState> {
  AdConsentController({bool? enabled})
    : _enabled =
          enabled ?? AppConfig.homeBannerAdUnitIdForCurrentPlatform != null,
      super(
        (enabled ?? AppConfig.homeBannerAdUnitIdForCurrentPlatform != null)
            ? const AdConsentState.loading()
            : const AdConsentState.disabled(),
      ) {
    if (_enabled) unawaited(initialize());
  }

  final bool _enabled;
  bool _initializing = false;
  bool _mobileAdsInitialized = false;

  Future<void> initialize() async {
    if (!_enabled || _initializing) return;
    _initializing = true;
    try {
      final consentError = await _requestConsentUpdate();
      await _publishCurrentState(message: consentError?.message);
    } catch (_) {
      await _publishCurrentState(
        message: 'Advertising privacy choices could not be refreshed.',
      );
    } finally {
      _initializing = false;
    }
  }

  Future<void> showPrivacyOptions() async {
    if (!_enabled || !state.privacyOptionsRequired) return;
    final completer = Completer<FormError?>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (!completer.isCompleted) completer.complete(error);
    });
    final error = await completer.future;
    await _publishCurrentState(message: error?.message);
  }

  Future<FormError?> _requestConsentUpdate() {
    final completer = Completer<FormError?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        unawaited(
          ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (!completer.isCompleted) completer.complete(error);
          }),
        );
      },
      (error) {
        if (!completer.isCompleted) completer.complete(error);
      },
    );
    return completer.future;
  }

  Future<void> _publishCurrentState({String? message}) async {
    var canRequestAds = false;
    var privacyOptionsRequired = false;
    try {
      canRequestAds = await ConsentInformation.instance.canRequestAds();
      privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (canRequestAds && !_mobileAdsInitialized) {
        await MobileAds.instance.initialize();
        _mobileAdsInitialized = true;
      }
    } catch (_) {
      canRequestAds = false;
    }
    if (!mounted) return;
    state = AdConsentState(
      initialized: true,
      canRequestAds: canRequestAds,
      privacyOptionsRequired: privacyOptionsRequired,
      message: message,
    );
  }
}
