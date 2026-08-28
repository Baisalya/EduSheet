import 'package:flutter/material.dart';

/// App-wide safety net for ultra-small free-form windows.
///
/// Normal Android/tablet/desktop sizes keep their real constraints. When a
/// desktop window is resized below a practical compact canvas, or a mobile
/// viewport becomes exceptionally small, the route hierarchy keeps a stable
/// logical layout size and the outer viewport becomes pannable instead of
/// forcing every nested Row/toolbar/dialog into impossible constraints.
///
/// This is deliberately a last-line safety net, not a replacement for local
/// responsive layout. Components still adapt normally at usable sizes; only
/// impossible free-form sizes fall back to scrolling.
class AdaptiveAppViewport extends StatelessWidget {
  static const double minimumContentWidth = 320;
  static const double minimumDesktopContentWidth = 360;
  static const double minimumContentHeight = 360;
  static const double minimumDesktopContentHeight = 480;

  final Widget child;

  const AdaptiveAppViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final desktop = _isDesktopPlatform(Theme.of(context).platform);
        final minimumWidth = desktop
            ? minimumDesktopContentWidth
            : minimumContentWidth;
        final minimumHeight = desktop
            ? minimumDesktopContentHeight
            : minimumContentHeight;

        final currentWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaSize.width;
        final currentHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaSize.height;
        final targetWidth = currentWidth < minimumWidth
            ? minimumWidth
            : currentWidth;
        final targetHeight = currentHeight < minimumHeight
            ? minimumHeight
            : currentHeight;
        final needsHorizontalScroll = targetWidth > currentWidth;
        final needsVerticalScroll = targetHeight > currentHeight;

        if (!needsHorizontalScroll && !needsVerticalScroll) {
          return child;
        }

        Widget guarded = SizedBox(
          width: targetWidth,
          height: targetHeight,
          child: child,
        );

        if (needsVerticalScroll) {
          guarded = SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            child: guarded,
          );
        }

        if (needsHorizontalScroll) {
          guarded = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: guarded,
          );
        }

        return guarded;
      },
    );
  }

  static bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }
}
