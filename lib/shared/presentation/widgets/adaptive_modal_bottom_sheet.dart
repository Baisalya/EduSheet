import 'package:edusheet/shared/presentation/widgets/adaptive_app_viewport.dart';
import 'package:flutter/material.dart';

/// App-wide bottom-sheet presenter that keeps modal content width predictable
/// across Android and free-form desktop windows.
///
/// Material bottom sheets can receive loose horizontal constraints on desktop.
/// A child that only declares a height (for example a [FractionallySizedBox]
/// with only `heightFactor`) may then shrink to its intrinsic width. That makes
/// otherwise-valid Rows, dropdowns and filter bars much easier to overflow when
/// a Windows window is resized narrowly.
///
/// This wrapper preserves Flutter's normal modal behaviour while giving every
/// sheet a finite, full-width canvas up to [maximumSheetWidth]. Callers remain
/// responsible for their own vertical scrolling; horizontal layout no longer
/// depends on child intrinsic width.
Future<T?> showAdaptiveModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool isScrollControlled = false,
  bool? showDragHandle,
  Color? backgroundColor,
  bool? requestFocus,
  double maximumSheetWidth = 640,
}) {
  final viewportWidth = MediaQuery.sizeOf(context).width;

  // The app-level viewport guard supplies at least a compact-phone canvas for
  // ultra-narrow free-form windows. Request the same logical minimum here so a
  // modal cannot become narrower than the rest of the route hierarchy.
  final platform = Theme.of(context).platform;
  final desktop =
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
  final minimumLogicalWidth = desktop
      ? AdaptiveAppViewport.minimumDesktopContentWidth
      : AdaptiveAppViewport.minimumContentWidth;
  final availableWidth = viewportWidth < minimumLogicalWidth
      ? minimumLogicalWidth
      : viewportWidth;
  final sheetWidth = availableWidth > maximumSheetWidth
      ? maximumSheetWidth
      : availableWidth;

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    requestFocus: requestFocus,
    constraints: BoxConstraints(maxWidth: sheetWidth),
    builder: (sheetContext) =>
        SizedBox(width: sheetWidth, child: builder(sheetContext)),
  );
}
