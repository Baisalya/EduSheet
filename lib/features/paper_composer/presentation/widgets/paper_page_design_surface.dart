import 'dart:math' as math;

import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:flutter/material.dart';

/// Shared visual page surface for Word Mode and read-only preview.
///
/// Background and watermark are document content and therefore appear on both
/// surfaces. Grid/ruler/column guides are editor chrome and are painted only
/// when [showEditorChrome] is true, so they can never leak into preview/export.
class PaperPageDesignSurface extends StatelessWidget {
  final PaperPageLayout layout;
  final double pageScale;
  final EdgeInsets pagePadding;
  final int resolvedColumnCount;
  final bool compact;
  final bool showEditorChrome;
  final Widget child;

  const PaperPageDesignSurface({
    super.key,
    required this.layout,
    required this.pageScale,
    required this.pagePadding,
    required this.resolvedColumnCount,
    required this.compact,
    required this.showEditorChrome,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final watermark = layout.watermarkText.trim();
    final chromeVisible = showEditorChrome && !compact;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ColoredBox(color: Color(layout.pageBackgroundArgb)),
        ),
        if (watermark.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -math.pi / 5,
                  child: Opacity(
                    opacity: layout.watermarkOpacity
                        .clamp(0.02, 0.35)
                        .toDouble(),
                    child: Text(
                      watermark,
                      key: const Key('paper-page-watermark'),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        child,
        if (chromeVisible && (layout.showGrid || layout.showRulers))
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('word-page-layout-guides'),
                painter: _PageChromePainter(
                  pageScale: pageScale,
                  padding: pagePadding,
                  showGrid: layout.showGrid,
                  showRulers: layout.showRulers,
                  gridSpacingPoints: layout.gridSpacingPoints,
                  columnCount: resolvedColumnCount,
                  columnSpacingPoints: layout.columnSpacingPoints,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PageChromePainter extends CustomPainter {
  final double pageScale;
  final EdgeInsets padding;
  final bool showGrid;
  final bool showRulers;
  final double gridSpacingPoints;
  final int columnCount;
  final double columnSpacingPoints;
  final Color color;

  const _PageChromePainter({
    required this.pageScale,
    required this.padding,
    required this.showGrid,
    required this.showRulers,
    required this.gridSpacingPoints,
    required this.columnCount,
    required this.columnSpacingPoints,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final content = Rect.fromLTRB(
      padding.left,
      padding.top,
      size.width - padding.right,
      size.height - padding.bottom,
    );
    if (content.width <= 0 || content.height <= 0) return;

    if (showGrid) {
      final spacing = (gridSpacingPoints * pageScale)
          .clamp(8.0, 72.0)
          .toDouble();
      final gridPaint = Paint()
        ..color = color.withValues(alpha: 0.08)
        ..strokeWidth = 0.6;
      for (double x = content.left; x <= content.right; x += spacing) {
        canvas.drawLine(
          Offset(x, content.top),
          Offset(x, content.bottom),
          gridPaint,
        );
      }
      for (double y = content.top; y <= content.bottom; y += spacing) {
        canvas.drawLine(
          Offset(content.left, y),
          Offset(content.right, y),
          gridPaint,
        );
      }
    }

    if (columnCount > 1) {
      final gap = columnSpacingPoints * pageScale;
      final usable = content.width - gap * (columnCount - 1);
      if (usable > 0) {
        final columnWidth = usable / columnCount;
        final guidePaint = Paint()
          ..color = color.withValues(alpha: 0.30)
          ..strokeWidth = 1;
        for (var index = 1; index < columnCount; index++) {
          final x = content.left + columnWidth * index + gap * (index - 0.5);
          canvas.drawLine(
            Offset(x, content.top),
            Offset(x, content.bottom),
            guidePaint,
          );
        }
      }
    }

    if (!showRulers) return;
    final rulerPaint = Paint()
      ..color = color.withValues(alpha: 0.46)
      ..strokeWidth = 1;
    final minor = (18 * pageScale).clamp(10.0, 30.0).toDouble();
    for (double x = content.left; x <= content.right; x += minor) {
      final major = (((x - content.left) / minor).round() % 4) == 0;
      final tick = major ? 8.0 : 4.0;
      canvas.drawLine(
        Offset(x, math.max(0.0, content.top - tick)),
        Offset(x, content.top),
        rulerPaint,
      );
    }
    for (double y = content.top; y <= content.bottom; y += minor) {
      final major = (((y - content.top) / minor).round() % 4) == 0;
      final tick = major ? 8.0 : 4.0;
      canvas.drawLine(
        Offset(math.max(0.0, content.left - tick), y),
        Offset(content.left, y),
        rulerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PageChromePainter oldDelegate) {
    return pageScale != oldDelegate.pageScale ||
        padding != oldDelegate.padding ||
        showGrid != oldDelegate.showGrid ||
        showRulers != oldDelegate.showRulers ||
        gridSpacingPoints != oldDelegate.gridSpacingPoints ||
        columnCount != oldDelegate.columnCount ||
        columnSpacingPoints != oldDelegate.columnSpacingPoints ||
        color != oldDelegate.color;
  }
}
