import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Geometry contract shared by PowerPoint preview and presentation surfaces.
///
/// Slides are never stretched or cropped to fill a viewport. The policy keeps
/// the deck aspect ratio, maximizes the visible slide, and reports the
/// remaining centered letterbox area.
class PresentationStageMetrics {
  final Size slideSize;
  final EdgeInsets letterbox;

  const PresentationStageMetrics({
    required this.slideSize,
    required this.letterbox,
  });

  Rect centeredRect(Size viewport) {
    final left = (viewport.width - slideSize.width) / 2;
    final top = (viewport.height - slideSize.height) / 2;
    return Rect.fromLTWH(left, top, slideSize.width, slideSize.height);
  }
}

class PresentationStagePolicy {
  const PresentationStagePolicy._();

  static PresentationStageMetrics contain({
    required Size viewport,
    required double aspectRatio,
  }) {
    final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 16 / 9;
    final availableWidth = math.max(0.0, viewport.width).toDouble();
    final availableHeight = math.max(0.0, viewport.height).toDouble();

    if (availableWidth == 0 || availableHeight == 0) {
      return const PresentationStageMetrics(
        slideSize: Size.zero,
        letterbox: EdgeInsets.zero,
      );
    }

    final availableRatio = availableWidth / availableHeight;
    double width;
    double height;
    if (availableRatio > ratio) {
      height = availableHeight;
      width = height * ratio;
    } else {
      width = availableWidth;
      height = width / ratio;
    }

    final horizontal = math.max(0.0, (viewport.width - width) / 2).toDouble();
    final vertical = math.max(0.0, (viewport.height - height) / 2).toDouble();
    return PresentationStageMetrics(
      slideSize: Size(width, height),
      letterbox: EdgeInsets.fromLTRB(
        horizontal,
        vertical,
        horizontal,
        vertical,
      ),
    );
  }
}
