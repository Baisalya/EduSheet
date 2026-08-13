class PaperComposerBreakpoints {
  const PaperComposerBreakpoints._();

  static const double compactMax = 699;
  static const double expandedMin = 1100;

  static bool isCompact(double width) => width <= compactMax;
  static bool isExpanded(double width) => width >= expandedMin;
}
