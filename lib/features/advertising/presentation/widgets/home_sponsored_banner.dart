import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/app_config.dart';
import '../../../premium/application/premium_controller.dart';
import '../../application/ad_consent_controller.dart';
import '../../domain/ad_display_policy.dart';
import '../../../../shared/presentation/providers/privacy_provider.dart';

class HomeSponsoredBanner extends ConsumerWidget {
  const HomeSponsoredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);
    final adUnitId = AppConfig.homeBannerAdUnitIdForCurrentPlatform;
    final shouldShow = AdDisplayPolicy.shouldShowHomeAd(
      premium: premium,
      adsEnabled: AppConfig.adsEnabled,
      platformSupported: AppConfig.adsSupportedOnCurrentPlatform,
      hasConfiguredAdUnit: adUnitId != null,
    );
    if (!shouldShow) return const SizedBox.shrink();

    final policyAccepted = ref
        .watch(privacyProvider)
        .maybeWhen(
          data: (version) => version >= PrivacyNotifier.currentPolicyVersion,
          orElse: () => false,
        );
    if (!policyAccepted) return const SizedBox.shrink();

    final consent = ref.watch(adConsentProvider);
    if (!consent.canRequestAds) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: _InlineSponsoredBanner(adUnitId: adUnitId!),
    );
  }
}

class _InlineSponsoredBanner extends StatefulWidget {
  const _InlineSponsoredBanner({required this.adUnitId});

  final String adUnitId;

  @override
  State<_InlineSponsoredBanner> createState() => _InlineSponsoredBannerState();
}

class _InlineSponsoredBannerState extends State<_InlineSponsoredBanner> {
  BannerAd? _banner;
  int? _requestedWidth;
  double _height = 100;
  bool _loaded = false;
  bool _failed = false;

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _scheduleLoad(int width) {
    if (_requestedWidth == width) return;
    _requestedWidth = width;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load(width));
    });
  }

  Future<void> _load(int width) async {
    if (_requestedWidth != width) return;
    final previous = _banner;
    _banner = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() {
      _loaded = false;
      _failed = false;
      _height = 100;
    });

    final size = AdSize.getInlineAdaptiveBannerAdSize(width, 100);
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final platformSize = await banner.getPlatformAdSize();
          if (!mounted || !identical(_banner, banner)) {
            await ad.dispose();
            return;
          }
          setState(() {
            _height = (platformSize?.height ?? size.height).toDouble();
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) async {
          await ad.dispose();
          if (!mounted || !identical(_banner, banner)) return;
          setState(() {
            _banner = null;
            _failed = true;
          });
        },
      ),
    );
    _banner = banner;
    try {
      await banner.load();
    } catch (_) {
      await banner.dispose();
      if (!mounted || !identical(_banner, banner)) return;
      setState(() {
        _banner = null;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 720).floor();
        if (width >= 320) _scheduleLoad(width);
        if (width < 320) return const SizedBox.shrink();
        return Center(
          child: Semantics(
            container: true,
            label: 'Advertisement',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ADVERTISEMENT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: width.toDouble(),
                  height: _height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _loaded && _banner != null
                      ? SizedBox(
                          width: width.toDouble(),
                          height: _height,
                          child: AdWidget(ad: _banner!),
                        )
                      : Text(
                          'Loading advertisement…',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
