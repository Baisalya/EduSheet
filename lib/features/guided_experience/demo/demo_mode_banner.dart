import 'package:flutter/material.dart';

class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({
    super.key,
    required this.label,
    required this.onExit,
  });

  final String label;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Demo Mode · $label',
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your real EduSheet data will not be changed.',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Exit Demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
