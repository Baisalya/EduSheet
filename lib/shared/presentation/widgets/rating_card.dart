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
    final leading = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.star_rounded, color: Color(0xFFF3A712), size: 30),
    );

    const details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3A712)),
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3A712)),
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3A712)),
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3A712)),
            Icon(Icons.star_rounded, size: 15, color: Color(0xFFF3A712)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Enjoying EduSheet?',
          style: TextStyle(
            color: Color(0xFF4A3210),
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'A quick store rating helps more teachers find it.',
          style: TextStyle(color: Color(0xFF72531F), fontSize: 12),
        ),
      ],
    );

    final rateButton = FilledButton(
      onPressed: _opening ? null : _rateApp,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF5A3D0B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: _opening
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF4D3), Color(0xFFFFE4AA)],
            ),
            border: Border.all(
              color: const Color(0xFFFFC857).withValues(alpha: 0.6),
            ),
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
                        const Expanded(child: details),
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
                    const Expanded(child: details),
                    const SizedBox(width: 8),
                    rateButton,
                  ],
                ),
        );
      },
    );
  }
}
