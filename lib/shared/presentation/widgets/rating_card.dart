import 'package:flutter/material.dart';

import '../../services/review_service.dart';

class RatingCard extends StatefulWidget {
  const RatingCard({super.key});

  @override
  State<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<RatingCard> {
  bool _opening = false;

  Future<void> _rateApp() async {
    if (_opening) return;
    setState(() => _opening = true);
    final opened = await ReviewService.instance.openStoreListing();
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The store listing could not be opened right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const gold = Color(0xFFF3A712);
    final warmSurface = Color.alphaBlend(
      gold.withValues(alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08),
      scheme.surface,
    );
    final warmSurfaceStrong = Color.alphaBlend(
      gold.withValues(alpha: theme.brightness == Brightness.dark ? 0.17 : 0.13),
      scheme.surfaceContainerLow,
    );

    final leading = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: const Icon(Icons.star_rounded, color: gold, size: 30),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 15, color: gold),
            Icon(Icons.star_rounded, size: 15, color: gold),
            Icon(Icons.star_rounded, size: 15, color: gold),
            Icon(Icons.star_rounded, size: 15, color: gold),
            Icon(Icons.star_rounded, size: 15, color: gold),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enjoying EduSheet?',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'A quick store rating helps more teachers find it.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );

    final rateButton = FilledButton(
      onPressed: _opening ? null : _rateApp,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: _opening
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : const Text('Rate', style: TextStyle(fontWeight: FontWeight.w800)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [warmSurface, warmSurfaceStrong],
            ),
            border: Border.all(color: gold.withValues(alpha: 0.32)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: 12),
                    rateButton,
                  ],
                )
              : Row(
                  children: [
                    leading,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    rateButton,
                  ],
                ),
        );
      },
    );
  }
}
