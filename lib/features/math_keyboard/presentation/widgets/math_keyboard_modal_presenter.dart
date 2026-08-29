import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Presents secondary math-keyboard panels inside the keyboard's own Navigator.
///
/// The math keyboard is hosted by a nested Navigator in [MathKeyboardWrapper].
/// Using the app/root Navigator for category/search/action sheets creates a
/// second, unrelated modal layer above the formula editor and can also steal
/// focus from the active math field. Keeping these panels local makes the
/// keyboard one coordinated editing surface on Windows and Android.
Future<T?> showMathKeyboardPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  Color? backgroundColor,
  double maximumSheetWidth = 640,
}) {
  return showAdaptiveModalBottomSheet<T>(
    context: context,
    useRootNavigator: false,
    useSafeArea: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    requestFocus: false,
    maximumSheetWidth: maximumSheetWidth,
    builder: builder,
  );
}
