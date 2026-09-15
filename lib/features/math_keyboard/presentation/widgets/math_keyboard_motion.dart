import 'package:flutter/widgets.dart';

Duration mathKeyboardMotionDuration(
  BuildContext context,
  Duration normalDuration,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return mediaQuery?.disableAnimations == true ? Duration.zero : normalDuration;
}
