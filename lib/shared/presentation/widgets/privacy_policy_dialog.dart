import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/privacy_provider.dart';

class PrivacyPolicyDialog extends ConsumerWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false, // Prevent dismissing without accepting
      child: AlertDialog(
        title: const Text('Privacy Policy Update'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to EduSheet! Before you continue, please review and accept our Privacy Policy.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key points:\n'
                '• Offline First: Your data stays on your device.\n'
                '• Storage Access: We scan specific folders (Downloads/Documents) to help you find your files easily. We also allow you to open documents directly from external apps (like File Manager or WhatsApp).\n'
                '• Camera/Gallery: Used to scan questions, OMR sheets, and select school logos for your papers and templates.\n'
                '• No Data Collection: We do not sell or share your personal data with third parties.',
              ),
              const SizedBox(height: 16),
              const Text(
                'By clicking Accept, you agree to how we handle permissions and data as described.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(privacyProvider.notifier).acceptPolicy();
              Navigator.of(context).pop();
            },
            child: const Text('Accept & Continue'),
          ),
        ],
      ),
    );
  }
}
