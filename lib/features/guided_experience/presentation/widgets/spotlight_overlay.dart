import 'package:flutter/material.dart';

class SpotlightOverlay extends StatelessWidget {
  const SpotlightOverlay({
    super.key,
    required this.targetRect,
    this.targetPadding = 8,
    this.cornerRadius = 14,
    this.dimOpacity = 0.66,
  });

  final Rect? targetRect;
  final double targetPadding;
  final double cornerRadius;
  final double dimOpacity;

  Rect? get spotlightRect => targetRect?.inflate(targetPadding);

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim.withValues(
      alpha: dimOpacity.clamp(0.0, 1.0).toDouble(),
    );

    return IgnorePointer(
      child: CustomPaint(
        painter: _SpotlightPainter(
          spotlightRect: spotlightRect,
          cornerRadius: cornerRadius,
          scrimColor: scrim,
          outlineColor: Theme.of(context).colorScheme.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.spotlightRect,
    required this.cornerRadius,
    required this.scrimColor,
    required this.outlineColor,
  });

  final Rect? spotlightRect;
  final double cornerRadius;
  final Color scrimColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final target = spotlightRect;

    if (target == null) {
      canvas.drawRect(fullRect, Paint()..color = scrimColor);
      return;
    }

    final clippedTarget = target.intersect(fullRect);
    if (clippedTarget.isEmpty) {
      canvas.drawRect(fullRect, Paint()..color = scrimColor);
      return;
    }

    final hole = RRect.fromRectAndRadius(
      clippedTarget,
      Radius.circular(cornerRadius),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = scrimColor);

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = outlineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
