import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Presents the few math-keyboard flows that genuinely need a separate sheet.
///
/// Phase 3 keeps categories, structures, key actions and shape picking inside
/// [MathKeyboardView]. Search remains a sheet because its TextField needs the
/// system text keyboard. It still uses the keyboard's nested Navigator rather
/// than the app/root Navigator so formula ownership and focus stay coordinated.
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
