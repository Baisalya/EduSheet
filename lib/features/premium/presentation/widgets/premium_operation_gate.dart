import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/monthly_export_quota.dart';
import '../../application/premium_controller.dart';
import '../../domain/freemium_policy.dart';
import 'premium_gate_dialog.dart';

Future<bool> allowPdfExport(BuildContext context, WidgetRef ref) async {
  final premium = ref.read(premiumProvider);
  if (premium.hasPremiumAccess) return true;
  final usage = await ref.read(monthlyExportQuotaProvider).usage();
  if (FreemiumPolicy.canExportPdf(
    premium: premium,
    exportsThisMonth: usage.count,
  )) {
    return true;
  }
  if (context.mounted) {
    await showPremiumGateDialog(
      context,
      title: 'Monthly PDF limit reached',
      message:
          'Free includes ${FreemiumPolicy.freeMonthlyPdfExportLimit} basic PDF exports each month. Existing papers and personal backups stay available. Premium adds unlimited exports.',
    );
  }
  return false;
}

Future<void> recordPdfExport(WidgetRef ref) async {
  if (ref.read(premiumProvider).hasPremiumAccess) return;
  await ref.read(monthlyExportQuotaProvider).recordSuccessfulPdfExport();
}

Future<bool> allowWordExport(BuildContext context, WidgetRef ref) async {
  final premium = ref.read(premiumProvider);
  if (FreemiumPolicy.canExportWord(premium)) return true;
  await showPremiumGateDialog(
    context,
    title: 'Editable Word export is Premium',
    message:
        'Your paper remains editable inside EduSheet and its personal .eds backup stays free. Premium adds editable Word export and unlimited PDF exports.',
  );
  return false;
}
