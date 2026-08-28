import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/premium_controller.dart';
import '../screens/premium_screen.dart';

class PremiumBadgeButton extends ConsumerWidget {
  const PremiumBadgeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(
      premiumProvider.select((state) => state.isPremium),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PremiumScreen())),
        style: TextButton.styleFrom(
          foregroundColor: isPremium
              ? const Color(0xFFD49B00)
              : Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(
          isPremium ? Icons.workspace_premium_rounded : Icons.diamond_outlined,
          size: 19,
        ),
        label: Text(
          isPremium ? 'PRO' : 'Premium',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}
