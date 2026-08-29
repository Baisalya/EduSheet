import 'package:flutter/widgets.dart';

/// Marks the subtree owned by the custom math keyboard, including routes pushed
/// onto its nested Navigator.
///
/// Desktop pointer interaction can legitimately move primary focus from a math
/// field to a keyboard control. Math fields use this marker to distinguish that
/// internal hand-off from a real focus change to some other editor in the app.
class MathKeyboardInteractionRegion extends InheritedWidget {
  const MathKeyboardInteractionRegion({super.key, required super.child});

  static bool contains(BuildContext? context) {
    return context
            ?.getElementForInheritedWidgetOfExactType<
              MathKeyboardInteractionRegion
            >() !=
        null;
  }

  @override
  bool updateShouldNotify(MathKeyboardInteractionRegion oldWidget) => false;
}
