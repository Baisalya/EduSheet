import 'package:edusheet/features/premium/application/monthly_export_quota.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('counts successful PDF exports within the current month', () async {
    final quota = MonthlyExportQuota(now: () => DateTime(2026, 9, 20));

    expect((await quota.usage()).count, 0);
    await quota.recordSuccessfulPdfExport();
    await quota.recordSuccessfulPdfExport();

    final usage = await quota.usage();
    expect(usage.period, '2026-09');
    expect(usage.count, 2);
    expect(usage.remaining, 3);
  });

  test('starts a fresh quota when the calendar month changes', () async {
    var now = DateTime(2026, 9, 20);
    final quota = MonthlyExportQuota(now: () => now);
    await quota.recordSuccessfulPdfExport();

    now = DateTime(2026, 10, 1);
    final usage = await quota.usage();

    expect(usage.period, '2026-10');
    expect(usage.count, 0);
  });
}
