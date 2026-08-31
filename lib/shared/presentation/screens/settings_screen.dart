import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../features/premium/application/premium_controller.dart';
import '../../../features/premium/presentation/screens/premium_screen.dart';
import '../providers/app_info_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/rating_card.dart';

const String _developerName = 'Baishalya Roul';
const String _portfolioUrl = 'https://baisalya.com/';
const String _phonePeUpiId = 'baishalya1999@oksbi';
const bool _isUpiConfigured = _phonePeUpiId != 'YOUR_UPI_ID';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final appInfo = ref.watch(appInfoProvider);
    final isDark = themeSettings.mode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _PremiumSettingsBanner(
              isPremium: premium.hasPremiumAccess,
              isComplimentary: premium.isComplimentaryAccess,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Appearance',
              icon: Icons.palette_rounded,
              color: themeSettings.accent.seedColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Toggle day and night mode'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Workspace colour',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    premium.hasPremiumAccess
                        ? premium.isComplimentaryAccess
                              ? 'All workspace styles are free in this release.'
                              : 'All premium styles are unlocked.'
                        : 'Ocean is free. Premium unlocks three more styles.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  _AccentPicker(
                    selected: themeSettings.accent,
                    isPremium: premium.hasPremiumAccess,
                    onSelected: (accent) {
                      if (accent.isPremium && !premium.hasPremiumAccess) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PremiumScreen(),
                          ),
                        );
                        return;
                      }
                      ref.read(themeProvider.notifier).setAccent(accent);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Support',
              icon: Icons.help_outline_rounded,
              color: Colors.purple,
              child: Column(
                children: [
                  const RatingCard(),
                  const SizedBox(height: 8),
                  _SettingsActionCard(
                    title: 'Email Support',
                    subtitle: AppConfig.supportEmail,
                    icon: Icons.support_agent_rounded,
                    color: Colors.pink,
                    onTap: () {
                      _openSupportEmail(context);
                    },
                  ),
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Developer Details',
                    subtitle: 'About the creator',
                    icon: Icons.code_rounded,
                    color: Colors.teal,
                    onTap: () {
                      _showDeveloperDetails(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Legal & updates',
              icon: Icons.verified_user_rounded,
              color: Colors.blueGrey,
              child: Column(
                children: [
                  _SettingsActionCard(
                    title: 'Privacy Policy',
                    subtitle: 'How EduSheet handles local and store data',
                    icon: Icons.privacy_tip_rounded,
                    color: Colors.blueGrey,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => const PrivacyPolicyDialog(),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Check for updates',
                    subtitle: 'Open the official EduSheet download page',
                    icon: Icons.system_update_rounded,
                    color: Colors.green,
                    onTap: () =>
                        _launchExternal(context, AppConfig.productWebsiteUrl),
                  ),
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Open-source licences',
                    subtitle: 'Packages and licence notices',
                    icon: Icons.description_outlined,
                    color: Colors.indigo,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'EduSheet',
                      applicationVersion: appInfo.maybeWhen(
                        data: (info) => '${info.version} (${info.buildNumber})',
                        orElse: () => null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Advanced',
              icon: Icons.auto_awesome_rounded,
              color: Colors.orange,
              child: Column(
                children: [
                  _SettingsActionCard(
                    title: 'Download AI Model',
                    subtitle: 'Enhance OCR capabilities',
                    icon: Icons.psychology_rounded,
                    color: Colors.indigo,
                    isComingSoon: true,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Backup Cloud',
                    subtitle: 'Sync your data securely',
                    icon: Icons.cloud_done_rounded,
                    color: Colors.blue,
                    isComingSoon: true,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Import/Export Data',
                    subtitle: 'Manage your local files',
                    icon: Icons.import_export_rounded,
                    color: Colors.deepOrange,
                    isComingSoon: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              appInfo.maybeWhen(
                data: (info) =>
                    'EduSheet v${info.version} • build ${info.buildNumber}',
                orElse: () => 'EduSheet',
              ),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: {'subject': 'EduSheet support'},
    );
    if (await launchUrl(uri)) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email app is available right now.')),
      );
    }
  }

  void _showDeveloperDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Icon(Icons.code_rounded, color: Colors.teal, size: 30),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Developer Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Creator of EduSheet',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Made with care for teachers, tutors, and students who need simple tools that just work.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _launchExternal(context, _portfolioUrl),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _developerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tap to view portfolio',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.teal.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_cafe_rounded,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Buy me a coffee',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'EduSheet is free for everyone. If it saved your time, a tiny coffee helps keep new features brewing.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Text(
                              _phonePeUpiId,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Copy UPI ID',
                          onPressed: () => _copyUpiId(context),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUpiPayment(context),
                        icon: const Icon(Icons.volunteer_activism_rounded),
                        label: const Text('Donate with PhonePe / UPI'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now.')),
      );
    }
  }

  Future<void> _copyUpiId(BuildContext context) async {
    if (!_isUpiConfigured) {
      _showMissingUpiMessage(context);
      return;
    }

    await Clipboard.setData(const ClipboardData(text: _phonePeUpiId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI ID copied. Thank you for supporting EduSheet.'),
        ),
      );
    }
  }

  Future<void> _openUpiPayment(BuildContext context) async {
    if (!_isUpiConfigured) {
      _showMissingUpiMessage(context);
      return;
    }

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _phonePeUpiId,
        'pn': _developerName,
        'tn': 'Thanks for supporting EduSheet',
        'cu': 'INR',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. You can copy the UPI ID instead.'),
        ),
      );
    }
  }

  void _showMissingUpiMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PhonePe UPI ID is not configured yet.')),
    );
  }
}

class _PremiumSettingsBanner extends StatelessWidget {
  final bool isPremium;
  final bool isComplimentary;
  final VoidCallback onTap;

  const _PremiumSettingsBanner({
    required this.isPremium,
    required this.isComplimentary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF29204F), Color(0xFF7557D5)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7557D5).withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPremium
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  color: const Color(0xFFFFD76A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplimentary
                          ? 'Free access release'
                          : (isPremium ? 'Premium active' : 'EduSheet Premium'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isComplimentary
                          ? 'Subscription inactive • all styles unlocked'
                          : isPremium
                          ? 'Thank you for supporting EduSheet.'
                          : 'Optional Store subscription • premium styles',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  final AppAccent selected;
  final bool isPremium;
  final ValueChanged<AppAccent> onSelected;

  const _AccentPicker({
    required this.selected,
    required this.isPremium,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppAccent.values.map((accent) {
        final selectedAccent = accent == selected;
        final locked = accent.isPremium && !isPremium;
        return Semantics(
          button: true,
          selected: selectedAccent,
          label: '${accent.label}${locked ? ', Premium' : ''}',
          child: InkWell(
            onTap: () => onSelected(accent),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 66,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: accent.seedColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedAccent
                      ? accent.seedColor
                      : accent.seedColor.withValues(alpha: 0.24),
                  width: selectedAccent ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.seedColor,
                          shape: BoxShape.circle,
                        ),
                        child: selectedAccent
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                      if (locked)
                        const Positioned(
                          right: -5,
                          bottom: -4,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: Color(0xFFFFC857),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: Color(0xFF4A3210),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accent.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isComingSoon;

  const _SettingsActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: isComingSoon
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title is coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isComingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'SOON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
