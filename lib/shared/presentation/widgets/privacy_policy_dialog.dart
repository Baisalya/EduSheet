import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../providers/privacy_provider.dart';

class PrivacyPolicyDialog extends ConsumerWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requiresAcceptance = ref.read(privacyProvider.notifier).needsApproval;

    return PopScope(
      canPop: !requiresAcceptance,
      child: AlertDialog(
        title: Text(
          requiresAcceptance ? 'Privacy Policy Update' : 'Privacy Policy',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to EduSheet! Before you continue, please review and accept our Privacy Policy.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Key points:\n'
                '- Offline First: Your data stays on your device.\n'
                '- Storage Access: We scan common document folders such as Downloads, Documents, EduSheet export folders, and messaging app document folders to help you find PDF, Word, Excel, PowerPoint, and text files. We also allow you to open documents directly from external apps like File Manager or WhatsApp.\n'
                '- Local Previews: Supported files are previewed on your device. Unsupported legacy Office files can be opened in another app you choose.\n'
                '- Camera/Gallery: Used to scan questions, OMR sheets, and select school logos for your papers and templates.\n'
                '- Store Services: Premium purchases, ratings, and update checks contact your device app store. Those services process data under their own policies.\n'
                '- No Sale of Data: EduSheet does not sell your personal data.',
              ),
              SizedBox(height: 16),
              Text(
                'By clicking Accept, you agree to how we handle permissions and data as described.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(AppConfig.privacyPolicyUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Full policy'),
          ),
          TextButton(
            onPressed: () async {
              if (requiresAcceptance) {
                await ref.read(privacyProvider.notifier).acceptPolicy();
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: Text(requiresAcceptance ? 'Accept & Continue' : 'Close'),
          ),
        ],
      ),
    );
  }
}
