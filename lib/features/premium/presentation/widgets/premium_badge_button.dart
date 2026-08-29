import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/premium_controller.dart';
import '../screens/premium_screen.dart';

class PremiumBadgeButton extends ConsumerWidget {
  const PremiumBadgeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);
    final hasAccess = premium.hasPremiumAccess;
    final compact = MediaQuery.sizeOf(context).width < 380;
    final foreground = hasAccess
        ? const Color(0xFFD49B00)
        : Theme.of(context).colorScheme.primary;

    void openPremium() {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PremiumScreen()));
    }

    return Padding(
      padding: EdgeInsets.only(right: compact ? 2 : 8),
      child: compact
          ? IconButton(
              tooltip: premium.isComplimentaryAccess
                  ? 'Free access release'
                  : (hasAccess ? 'Premium active' : 'Premium'),
              onPressed: openPremium,
              visualDensity: VisualDensity.compact,
              color: foreground,
              icon: Icon(
                hasAccess
                    ? Icons.workspace_premium_rounded
                    : Icons.diamond_outlined,
                size: 20,
              ),
            )
          : TextButton.icon(
              onPressed: openPremium,
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                hasAccess
                    ? Icons.workspace_premium_rounded
                    : Icons.diamond_outlined,
                size: 19,
              ),
              label: Text(
                premium.isComplimentaryAccess
                    ? 'FREE'
                    : (hasAccess ? 'PRO' : 'Premium'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
