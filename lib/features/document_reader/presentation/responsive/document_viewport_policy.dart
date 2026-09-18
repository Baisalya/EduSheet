import 'dart:math' as math;

/// Shared responsive rules for in-app document viewers.
///
/// The policy is deliberately renderer-agnostic: PDF, Word, and future viewers
/// consume the same breakpoints/gutters instead of inventing per-feature mobile
/// sizing. The document content itself remains renderer-owned.
class DocumentViewportPolicy {
  static const double phoneBreakpoint = 600;
  static const double compactToolbarBreakpoint = 680;
  static const double veryCompactToolbarBreakpoint = 390;
  static const double desktopBreakpoint = 900;

  static const double _wordDesktopPageWidth = 794;
  static const double _wordMaxWorkspacePageWidth = 860;

  final double width;
  final double height;

  const DocumentViewportPolicy({required this.width, required this.height});

  bool get isPhone => width < phoneBreakpoint;
  bool get isDesktop => width >= desktopBreakpoint;
  bool get isCompactToolbar => width < compactToolbarBreakpoint;
  bool get isVeryCompactToolbar => width < veryCompactToolbarBreakpoint;

  /// Phone readers start in screen-fit mode. Larger workspaces can preserve a
  /// conventional print-layout canvas without forcing lateral scrolling.
  bool get preferWordFitWidth => width < desktopBreakpoint;

  double get wordHorizontalGutter {
    if (width < phoneBreakpoint) return 8;
    if (width < desktopBreakpoint) return 16;
    return 24;
  }

  double get wordVerticalGutter => isPhone ? 8 : 16;

  double get wordAvailableWidth =>
      math.max(1, width - (wordHorizontalGutter * 2));

  /// Width used for the normal mobile/tablet Word experience. Importantly,
  /// there is no minimum 320px clamp: a 320px viewport with gutters yields a
  /// page narrower than 320px, so it never overflows merely because of policy.
  double get wordFitWidthPageWidth =>
      math.min(wordAvailableWidth, _wordMaxWorkspacePageWidth);

  /// Canonical print-layout width. On desktop it remains bounded by the actual
  /// workspace; on phone this may be wider than the viewport by user choice.
  double get wordPrintLayoutPageWidth {
    if (isDesktop) {
      return math.min(wordAvailableWidth, _wordDesktopPageWidth);
    }
    return _wordDesktopPageWidth;
  }

  /// Toolbar height stays touch-friendly on phones and visually balanced on
  /// desktop. Both values remain at or above Material's minimum touch target.
  double get documentToolbarHeight => isPhone ? 48 : 52;
}
