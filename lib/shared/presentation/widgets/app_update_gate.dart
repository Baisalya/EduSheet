import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upgrader/upgrader.dart';

import '../../../core/config/app_config.dart';
import '../providers/privacy_provider.dart';

class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  late final Upgrader _upgrader = Upgrader(
    countryCode: 'IN',
    durationUntilAlertAgain: const Duration(days: 2),
    checkOnResume: true,
  );

  @override
  Widget build(BuildContext context) {
    final policyAccepted = ref
        .watch(privacyProvider)
        .maybeWhen(
          data: (version) => version >= PrivacyNotifier.currentPolicyVersion,
          orElse: () => false,
        );
    if (!AppConfig.updateChecksEnabled || !policyAccepted) {
      return widget.child;
    }

    return UpgradeAlert(
      upgrader: _upgrader,
      dialogStyle: UpgradeDialogStyle.material,
      barrierDismissible: false,
      showIgnore: true,
      showLater: true,
      showReleaseNotes: true,
      child: widget.child,
    );
  }
}
