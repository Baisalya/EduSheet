import 'package:flutter/widgets.dart';

enum GuidePlacementSide { top, bottom, right, left, center }

@immutable
class GuidePlacementResult {
  const GuidePlacementResult({required this.offset, required this.side, required this.rect});
  final Offset offset;
  final GuidePlacementSide side;
  final Rect rect;
}

/// Pure geometry engine used by both the tutorial coach and the future
/// context-aware assistant. It never intentionally places the coach over the
/// highlighted control.
class GuidePlacementEngine {
  const GuidePlacementEngine({this.gap = 14, this.margin = 12});
  final double gap;
  final double margin;

  GuidePlacementResult place({
    required Rect viewport,
    required Rect target,
    required Size childSize,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final safe = viewport.deflate(margin);
    final candidates = <GuidePlacementResult>[
      _top(safe, target, childSize),
      _bottom(safe, target, childSize),
      if (textDirection == TextDirection.ltr) ...[
        _right(safe, target, childSize), _left(safe, target, childSize),
      ] else ...[
        _left(safe, target, childSize), _right(safe, target, childSize),
      ],
    ];

    for (final candidate in candidates) {
      if (_fullyInside(candidate.rect, safe) && !candidate.rect.overlaps(target.inflate(6))) {
        return candidate;
      }
    }

    // If no natural side fits, choose the candidate with the largest visible
    // area and clamp it. This can happen on tiny windows / large accessibility
    // text. The final overlap correction still keeps the target usable.
    candidates.sort((a, b) => _visibleArea(b.rect, safe).compareTo(_visibleArea(a.rect, safe)));
    var best = candidates.first;
    var rect = _clampRect(best.rect, safe);
    if (rect.overlaps(target.inflate(6))) {
      final above = target.top - gap - childSize.height;
      final below = target.bottom + gap;
      final y = above >= safe.top ? above : (below + childSize.height <= safe.bottom ? below : safe.top);
      rect = _clampRect(Rect.fromLTWH(rect.left, y, childSize.width, childSize.height), safe);
    }
    return GuidePlacementResult(offset: rect.topLeft, side: best.side, rect: rect);
  }

  GuidePlacementResult _top(Rect s, Rect t, Size c) => _result(
      Offset((t.center.dx - c.width / 2).clamp(s.left, s.right - c.width).toDouble(), t.top - gap - c.height), c, GuidePlacementSide.top);
  GuidePlacementResult _bottom(Rect s, Rect t, Size c) => _result(
      Offset((t.center.dx - c.width / 2).clamp(s.left, s.right - c.width).toDouble(), t.bottom + gap), c, GuidePlacementSide.bottom);
  GuidePlacementResult _right(Rect s, Rect t, Size c) => _result(
      Offset(t.right + gap, (t.center.dy - c.height / 2).clamp(s.top, s.bottom - c.height).toDouble()), c, GuidePlacementSide.right);
  GuidePlacementResult _left(Rect s, Rect t, Size c) => _result(
      Offset(t.left - gap - c.width, (t.center.dy - c.height / 2).clamp(s.top, s.bottom - c.height).toDouble()), c, GuidePlacementSide.left);
  GuidePlacementResult _result(Offset o, Size c, GuidePlacementSide side) =>
      GuidePlacementResult(offset: o, side: side, rect: o & c);

  bool _fullyInside(Rect r, Rect s) => r.left >= s.left && r.top >= s.top && r.right <= s.right && r.bottom <= s.bottom;
  double _visibleArea(Rect r, Rect s) { final i=r.intersect(s); return i.isEmpty ? 0 : i.width*i.height; }
  Rect _clampRect(Rect r, Rect s) {
    final w = r.width > s.width ? s.width : r.width;
    final h = r.height > s.height ? s.height : r.height;
    final left = r.left.clamp(s.left, s.right - w).toDouble();
    final top = r.top.clamp(s.top, s.bottom - h).toDouble();
    return Rect.fromLTWH(left, top, w, h);
  }
}
