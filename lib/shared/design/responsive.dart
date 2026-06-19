import 'package:flutter/material.dart';

class EduBreakpoints {
  static const double compact = 420;
  static const double tablet = 720;
  static const double desktop = 1080;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return const EdgeInsets.all(32);
    if (width >= tablet) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }

  static int homeGridColumns(double width) {
    if (width >= 1180) return 4;
    if (width >= 760) return 3;
    if (width >= 360) return 2;
    return 1;
  }

  static double homeCardAspect(double width) {
    if (width < 360) return 2.9;
    if (width < 420) return 1.22;
    if (width < 760) return 1.08;
    return 1.22;
  }
}

class MaxContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MaxContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
