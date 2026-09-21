import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/premium_controller.dart';
import '../../domain/freemium_policy.dart';
import '../../domain/premium_state.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('EduSheet Premium')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PremiumHero(
                    hasPremiumAccess: premium.hasPremiumAccess,
                    isInGracePeriod: premium.isInGracePeriod,
                    isComplimentary: premium.isComplimentaryAccess,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    premium.isComplimentaryAccess
                        ? 'Everything is unlocked for now'
                        : premium.isInGracePeriod
                        ? 'Your 7-day grace period is active'
                        : premium.isPremium
                        ? 'Your Premium plan is active'
                        : 'Unlock unlimited teacher workflows',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    premium.isComplimentaryAccess
                        ? 'Premium checkout is not active yet. Every feature remains available; Free-plan advertising may still appear.'
                        : premium.isInGracePeriod
                        ? 'Your papers and planner remain fully available while you resolve the payment issue.'
                        : premium.isPremium
                        ? 'Unlimited creation, advanced planning and an ad-free workspace are active.'
                        : 'Free remains genuinely useful. Premium removes limits from new creation and advanced operations.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _BenefitTile(
                    icon: Icons.all_inclusive_rounded,
                    title: 'Unlimited papers, classes and exports',
                    description:
                        'Create without Free limits and export editable Word files or unlimited PDFs.',
                  ),
                  const _BenefitTile(
                    icon: Icons.branding_watermark_rounded,
                    title: 'All templates and custom branding',
                    description:
                        'Use every template, school logos and custom paper styles.',
                  ),
                  const _BenefitTile(
                    icon: Icons.insights_rounded,
                    title: 'Advanced Teaching Planner',
                    description:
                        'Advanced analytics, period scheduling, curriculum packs and bulk operations.',
                  ),
                  const _BenefitTile(
                    icon: Icons.security_rounded,
                    title: 'Your work always stays yours',
                    description:
                        'Existing documents remain viewable/editable, personal backups stay free, and expiry includes a 7-day grace period.',
                  ),
                  const _BenefitTile(
                    icon: Icons.block_rounded,
                    title: 'No advertising',
                    description:
                        'Home banners and occasional transition ads are removed.',
                  ),
                  if (premium.message != null) ...[
                    const SizedBox(height: 12),
                    _StatusMessage(message: premium.message!),
                  ],
                  const SizedBox(height: 24),
                  _PurchaseButton(state: premium),
                  if (!premium.isComplimentaryAccess &&
                      premium.storeStatus != PremiumStoreStatus.unsupported &&
                      !premium.hasPremiumAccess) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: premium.purchasePending
                          ? null
                          : () => ref
                                .read(premiumProvider.notifier)
                                .restorePurchases(),
                      child: const Text('Restore purchase'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _storeFootnote(premium),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _storeFootnote(PremiumState state) {
    if (state.isComplimentaryAccess) {
      return 'The Premium subscription is not active in this store. Full feature access stays available; supported mobile Free editions may show advertising.';
    }
    if (state.storeStatus == PremiumStoreStatus.unsupported) {
      return 'Ad-free checkout is unavailable on this platform. Every EduSheet feature remains available.';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'Payment is securely processed by Microsoft Store. An active subscription can be restored with the same Microsoft account.';
    }
    return 'Payment is securely processed by your app store. The displayed price and applicable taxes come from the store.';
  }
}

class _PremiumHero extends StatelessWidget {
  final bool hasPremiumAccess;
  final bool isInGracePeriod;
  final bool isComplimentary;

  const _PremiumHero({
    required this.hasPremiumAccess,
    required this.isInGracePeriod,
    required this.isComplimentary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25204E), Color(0xFF7557D5), Color(0xFFE05A8B)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7557D5).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              hasPremiumAccess || isComplimentary
                  ? Icons.verified_rounded
                  : Icons.workspace_premium,
              size: 38,
              color: const Color(0xFFFFD76A),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplimentary
                      ? 'FREE ACCESS'
                      : isInGracePeriod
                      ? 'GRACE PERIOD'
                      : (hasPremiumAccess ? 'PREMIUM ACTIVE' : 'PREMIUM PLAN'),
                  style: const TextStyle(
                    color: Color(0xFFFFD76A),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isComplimentary
                      ? 'Full features with Free ads.'
                      : isInGracePeriod
                      ? '${FreemiumPolicy.premiumGracePeriod.inDays} days to update payment.'
                      : hasPremiumAccess
                      ? 'Unlimited and ad-free.'
                      : 'More creation. Less friction.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7557D5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF7557D5)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseButton extends ConsumerWidget {
  final PremiumState state;

  const _PurchaseButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = state.storeStatus == PremiumStoreStatus.ready;
    final label = switch ((
      state.isComplimentaryAccess,
      state.hasPremiumAccess,
      state.purchasePending,
      ready,
    )) {
      (true, _, _, _) => 'Free access is active',
      (_, true, _, _) =>
        state.isInGracePeriod
            ? 'Premium grace period is active'
            : 'Premium plan is active',
      (_, _, true, _) => 'Connecting to store…',
      (_, _, _, true) => 'Subscribe for ${state.product!.price}',
      _ => 'Ad-free plan unavailable',
    };

    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed:
            !state.isComplimentaryAccess &&
                ready &&
                !state.purchasePending &&
                !state.hasPremiumAccess
            ? () => ref.read(premiumProvider.notifier).buyPremium()
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7557D5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: state.purchasePending
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                state.hasPremiumAccess
                    ? Icons.check_rounded
                    : Icons.lock_open_rounded,
              ),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;

  const _StatusMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
