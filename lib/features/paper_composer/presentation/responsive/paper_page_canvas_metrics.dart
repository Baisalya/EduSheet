import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/widgets.dart';

/// Shared page geometry for the read-only Preview and editable Word Mode.
///
/// Keeping this math in one place is the Phase-3 WYSIWYG contract: both
/// surfaces use the same page width, scale, margins and minimum paper height.
class PaperPageCanvasMetrics {
  final double pageWidth;
  final double pageScale;
  final double pageMinHeight;
  final EdgeInsets pagePadding;
  final ({double width, double height}) pagePoints;

  const PaperPageCanvasMetrics({
    required this.pageWidth,
    required this.pageScale,
    required this.pageMinHeight,
    required this.pagePadding,
    required this.pagePoints,
  });

  static PaperPageCanvasMetrics resolve({
    required PaperPageLayout layout,
    required PaperSize templatePageSize,
    required double viewportWidth,
  }) {
    final points = _resolvedPagePoints(layout, templatePageSize);
    final preferredWidth = (820 * points.width / 595.28)
        .clamp(620, 980)
        .toDouble();
    final availableWidth = (viewportWidth - 32).clamp(280, 980).toDouble();
    final pageWidth = preferredWidth < availableWidth
        ? preferredWidth
        : availableWidth;
    final scale = pageWidth / points.width;
    final margins = layout.margins;

    return PaperPageCanvasMetrics(
      pageWidth: pageWidth,
      pageScale: scale,
      pageMinHeight: (points.height * scale).clamp(700, 1500).toDouble(),
      pagePadding: EdgeInsets.fromLTRB(
        (margins.leftPoints * scale).clamp(18, 120).toDouble(),
        (margins.topPoints * scale).clamp(20, 140).toDouble(),
        (margins.rightPoints * scale).clamp(18, 120).toDouble(),
        (margins.bottomPoints * scale).clamp(24, 160).toDouble(),
      ),
      pagePoints: points,
    );
  }

  static ({double width, double height}) _resolvedPagePoints(
    PaperPageLayout layout,
    PaperSize templatePageSize,
  ) {
    final explicit = layout.explicitPageSizePoints;
    if (explicit != null) {
      return explicit;
    }

    final portrait = switch (templatePageSize) {
      PaperSize.a4 => (width: 595.28, height: 841.89),
      PaperSize.a5 => (width: 419.53, height: 595.28),
      PaperSize.a3 => (width: 841.89, height: 1190.55),
      PaperSize.letter => (width: 612.0, height: 792.0),
      PaperSize.legal => (width: 612.0, height: 1008.0),
    };
    if (layout.orientation == PaperPageOrientation.landscape) {
      return (width: portrait.height, height: portrait.width);
    }
    return portrait;
  }
}
