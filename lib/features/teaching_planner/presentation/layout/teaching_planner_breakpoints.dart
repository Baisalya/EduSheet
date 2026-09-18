abstract final class TeachingPlannerBreakpoints {
  /// Phone-first reference layout. Below this value the UI should avoid
  /// side-by-side content and preserve the single-column visual rhythm.
  static const double compact = 520;

  /// Tablet / desktop transition used by forms and medium grids.
  static const double medium = 720;

  /// Existing global navigation switches to a rail only when both width and
  /// height can support it. This preserves phone behaviour on short windows.
  static const double navigationRail = 720;
  static const double navigationRailMinHeight = 480;

  static const double twoPane = 900;
  static const double wide = 980;
  static const double syllabusWide = 840;
  static const double extraWide = 1200;

  static const double compactMaxContentWidth = 760;
  static const double standardMaxContentWidth = 1280;
  static const double wideMaxContentWidth = 1320;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < twoPane;
  static bool isWide(double width) => width >= twoPane;

  static bool useNavigationRail({
    required double width,
    required double height,
  }) {
    return width >= navigationRail && height >= navigationRailMinHeight;
  }

  static int gridColumns(
    double width, {
    int compactColumns = 2,
    int mediumColumns = 3,
    int wideColumns = 4,
  }) {
    if (width >= twoPane) return wideColumns;
    if (width >= compact) return mediumColumns;
    return compactColumns;
  }

  static double horizontalPadding(
    double width, {
    double factor = 0.035,
    double min = 12,
    double max = 30,
  }) {
    return (width * factor).clamp(min, max).toDouble();
  }

  /// Default content padding tuned to the mobile reference while still
  /// allowing the module to breathe on resizable Windows surfaces.
  static double pagePadding(double width) {
    if (width >= extraWide) return 32;
    if (width >= twoPane) return 28;
    if (width >= compact) return 22;
    if (width >= 380) return 16;
    return 14;
  }
}
