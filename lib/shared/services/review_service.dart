import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

class ReviewPromptPolicy {
  const ReviewPromptPolicy._();

  static bool isEligible({
    required int launchCount,
    required int successfulExports,
    required DateTime firstUsedAt,
    required DateTime now,
    DateTime? lastPromptAt,
  }) {
    if (launchCount < 3 || successfulExports < 2) return false;
    if (now.difference(firstUsedAt) < const Duration(days: 3)) return false;
    if (lastPromptAt != null &&
        now.difference(lastPromptAt) < const Duration(days: 120)) {
      return false;
    }
    return true;
  }
}

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  static const String _launchCountKey = 'review_launch_count';
  static const String _exportCountKey = 'review_successful_export_count';
  static const String _firstUsedAtKey = 'review_first_used_at';
  static const String _lastPromptAtKey = 'review_last_prompt_at';

  final InAppReview _review = InAppReview.instance;
  bool _launchRegistered = false;

  Future<void> registerLaunch() async {
    if (_launchRegistered) return;
    _launchRegistered = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      await prefs.setInt(
        _launchCountKey,
        (prefs.getInt(_launchCountKey) ?? 0) + 1,
      );
      if (!prefs.containsKey(_firstUsedAtKey)) {
        await prefs.setString(_firstUsedAtKey, now.toIso8601String());
      }
    } catch (_) {
      // Review prompts are optional and never block normal app use.
    }
  }

  Future<void> recordSuccessfulExport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _exportCountKey,
        (prefs.getInt(_exportCountKey) ?? 0) + 1,
      );
      await _requestReviewIfEligible(prefs);
    } catch (_) {
      // Export success must not be affected by review infrastructure.
    }
  }

  Future<void> _requestReviewIfEligible(SharedPreferences prefs) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return;
    }

    final firstUsedRaw = prefs.getString(_firstUsedAtKey);
    final firstUsedAt = DateTime.tryParse(firstUsedRaw ?? '');
    if (firstUsedAt == null) return;
    final lastPromptAt = DateTime.tryParse(
      prefs.getString(_lastPromptAtKey) ?? '',
    );
    final now = DateTime.now().toUtc();
    final eligible = ReviewPromptPolicy.isEligible(
      launchCount: prefs.getInt(_launchCountKey) ?? 0,
      successfulExports: prefs.getInt(_exportCountKey) ?? 0,
      firstUsedAt: firstUsedAt,
      lastPromptAt: lastPromptAt,
      now: now,
    );
    if (!eligible || !await _review.isAvailable()) return;

    // Record before requesting because stores intentionally do not report
    // whether the quota-controlled dialog was actually shown.
    await prefs.setString(_lastPromptAtKey, now.toIso8601String());
    await _review.requestReview();
  }

  Future<bool> openStoreListing() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _review.openStoreListing();
        return true;
      }
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) &&
          AppConfig.appleAppId.isNotEmpty) {
        await _review.openStoreListing(appStoreId: AppConfig.appleAppId);
        return true;
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.windows &&
          AppConfig.microsoftStoreId.isNotEmpty) {
        await _review.openStoreListing(
          microsoftStoreId: AppConfig.microsoftStoreId,
        );
        return true;
      }
    } catch (_) {
      // Fall through to the product website.
    }

    try {
      return await launchUrl(
        Uri.parse(AppConfig.productWebsiteUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
