import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../widgets/privacy_policy_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

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
            _SettingsSection(
              title: 'General',
              icon: Icons.settings_rounded,
              color: Colors.blue,
              child: ListTile(
                title: const Text(
                  'Dark Mode',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Toggle day and night mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Support',
              icon: Icons.help_outline_rounded,
              color: Colors.purple,
              child: Column(
                children: [
                  _SettingsActionCard(
                    title: 'Help Us',
                    subtitle: 'Feedback and suggestions',
                    icon: Icons.favorite_rounded,
                    color: Colors.pink,
                    onTap: () {
                      _showHelpDialog(context);
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
                  const Divider(height: 1, indent: 48),
                  _SettingsActionCard(
                    title: 'Privacy Policy',
                    subtitle: 'Review our terms and data usage',
                    icon: Icons.privacy_tip_rounded,
                    color: Colors.blueGrey,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const PrivacyPolicyDialog(),
                      );
                    },
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
              'EduSheet v1.0.0',
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Help Us', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'We are constantly working to improve EduSheet. If you have any suggestions, bug reports, or feedback, please reach out to us at support@edusheet.com',
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

  void _showDeveloperDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Developer Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Created with ❤️ by Baishak.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('A passionate developer building tools for educators.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'github.com/baishak',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ],
            ),
          ],
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
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
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
                color: color.withOpacity(0.1),
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                            "SOON",
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
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
