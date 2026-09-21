import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';

Future<void> showPremiumGateDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final openPremium = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_rounded),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('View Premium'),
        ),
      ],
    ),
  );
  if (openPremium == true && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
    );
  }
}
