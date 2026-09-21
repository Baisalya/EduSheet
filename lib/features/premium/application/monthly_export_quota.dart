import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/freemium_policy.dart';

class MonthlyExportUsage {
  const MonthlyExportUsage({required this.period, required this.count});

  final String period;
  final int count;

  int get remaining => (FreemiumPolicy.freeMonthlyPdfExportLimit - count).clamp(
    0,
    FreemiumPolicy.freeMonthlyPdfExportLimit,
  );
}

class MonthlyExportQuota {
  MonthlyExportQuota({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static const _periodKey = 'freemium_pdf_export_period';
  static const _countKey = 'freemium_pdf_export_count';

  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  Future<MonthlyExportUsage> usage() async {
    final prefs = await _preferences();
    final period = _periodFor(_now());
    if (prefs.getString(_periodKey) != period) {
      await prefs.setString(_periodKey, period);
      await prefs.setInt(_countKey, 0);
      return MonthlyExportUsage(period: period, count: 0);
    }
    return MonthlyExportUsage(
      period: period,
      count: prefs.getInt(_countKey) ?? 0,
    );
  }

  Future<MonthlyExportUsage> recordSuccessfulPdfExport() async {
    final current = await usage();
    final next = current.count + 1;
    final prefs = await _preferences();
    await prefs.setInt(_countKey, next);
    return MonthlyExportUsage(period: current.period, count: next);
  }

  String _periodFor(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}';
  }
}

final monthlyExportQuotaProvider = Provider<MonthlyExportQuota>((ref) {
  return MonthlyExportQuota();
});
